import AppKit
import ImageIO

public struct ConversionEngine: Sendable {
    private let tools: Tools
    public init() { tools = Tools() }

    public func targets(for sources: [SourceFile]) -> [FileFormat] {
        guard let first = sources.first, sources.allSatisfy({ $0.format.category == first.format.category }) else { return [] }
        return candidates(first.format).filter { target in sources.allSatisfy { supported($0, target) } }
    }

    public func convert(_ source: SourceFile, to target: FileFormat, in directory: URL) async throws -> [URL] {
        try Task.checkCancellation()
        let current = try SourceFile(url: source.url)
        guard current.format == source.format else { throw ConversionError.invalid("Формат исходника изменился после выбора.") }
        guard supported(source, target) else { throw ConversionError.unsupported("Конвертация \(source.format.label) → \(target.label) недоступна.") }
        let scratch = try FileOperations.scratch(in: directory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let output = scratch.appendingPathComponent("result." + target.fileExtension)
        var multiple: [URL] = []
        let stem = source.url.deletingPathExtension().lastPathComponent

        if source.format == .pdf, target == .jpg || target == .png {
            multiple = try NativeDocuments.pdfPages(source.url, to: target, directory: scratch.appendingPathComponent("pages", isDirectory: true))
        } else if source.format.category == "Images" {
            if target == .pdf || (target.imageType.map { Self.imageWriters.contains($0) } ?? false) {
                try NativeDocuments.image(source.url, to: target, output: output)
            } else { try media(source, to: target, output: output) }
        } else if source.format.category == "Audio" || source.format.category == "Video" {
            if supported(source.format, target) { try media(source, to: target, output: output) }
            else { try await NativeMedia.convert(source, to: target, output: output) }
        } else if source.format.category == "Subtitles" {
            let cues = try Subtitles.parse(TextFile.read(source.url), format: source.format)
            try Subtitles.write(cues, format: target).write(to: output, atomically: false, encoding: .utf8)
        } else if source.format.category == "Archives" {
            let contents = scratch.appendingPathComponent("contents", isDirectory: true)
            try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: false)
            guard !(try ArchiveReader(source.url).entries(extractingTo: contents)).isEmpty else { throw ConversionError.invalid("Архив пуст.") }
            let arguments = target == .zip ? ["-q", "-r", output.path, "."] : [target == .gzip ? "-czf" : "-cf", output.path, "-C", contents.path, "."]
            _ = try ProcessRunner.checked(URL(fileURLWithPath: target == .zip ? "/usr/bin/zip" : "/usr/bin/tar"), arguments, directory: contents)
        } else if source.format.category == "Spreadsheets" && source.format != .xls {
            let sheets = try Spreadsheet.read(source, scratch: scratch)
            guard !sheets.isEmpty else { throw ConversionError.invalid("В книге нет доступных листов.") }
            if target == .csv || target == .tsv {
                let folder = scratch.appendingPathComponent("sheets", isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
                for (index, sheet) in sheets.enumerated() {
                    let file = folder.appendingPathComponent("Sheet \(index + 1)." + target.fileExtension)
                    try DelimitedText.write(sheet.rows, separator: target == .csv ? "," : "\t").write(to: file, atomically: false, encoding: .utf8)
                    multiple.append(file)
                }
            } else if target == .pdf {
                let text = sheets.map { $0.name + "\n" + DelimitedText.write($0.rows, separator: "\t") }.joined(separator: "\n\n")
                try NativeDocuments.writePDF(NSAttributedString(string: text, attributes: [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)]), output: output)
            } else { try Spreadsheet.write(sheets, to: target, output: output, scratch: scratch) }
        } else if [.ppt, .pptx, .pages, .xls].contains(source.format) {
            guard let office = tools.office else { throw ConversionError.unsupported("Для этого формата нужен LibreOffice.") }
            let profile = scratch.appendingPathComponent("office-profile").absoluteString
            let officeOutput = scratch.appendingPathComponent("office-output", isDirectory: true)
            try FileManager.default.createDirectory(at: officeOutput, withIntermediateDirectories: false)
            let officeTarget: FileFormat = target == .jpg || target == .png ? .pdf : target
            _ = try ProcessRunner.checked(office, ["-env:UserInstallation=" + profile, "--headless", "--convert-to", officeTarget.rawValue, "--outdir", officeOutput.path, source.url.path])
            let converted = officeOutput.appendingPathComponent(stem + "." + officeTarget.rawValue)
            guard FileManager.default.fileExists(atPath: converted.path) else { throw ConversionError.failed("LibreOffice не создал результат.") }
            if target == .jpg || target == .png { multiple = try NativeDocuments.pdfPages(converted, to: target, directory: scratch.appendingPathComponent("pages", isDirectory: true)) }
            else { try FileManager.default.moveItem(at: converted, to: output) }
        } else {
            let text = source.format == .epub ? try EPUB.read(source.url, scratch: scratch) : try NativeDocuments.readText(source, scratch: scratch)
            if target == .epub { try EPUB.write(text, title: stem, output: output, scratch: scratch) }
            else if target == .jpg || target == .png {
                let pdf = scratch.appendingPathComponent("document.pdf")
                try NativeDocuments.writePDF(text, output: pdf)
                multiple = try NativeDocuments.pdfPages(pdf, to: target, directory: scratch.appendingPathComponent("pages", isDirectory: true))
            } else { try NativeDocuments.writeText(text, to: target, output: output) }
        }

        try Task.checkCancellation()
        if !multiple.isEmpty {
            // Publish the entire set at once so a failed page never leaves a half-converted document.
            for file in multiple { try validate(file, format: target) }
            let folder = multiple[0].deletingLastPathComponent()
            let published = try FileOperations.publish(folder, named: stem + " " + target.label + " Results", in: directory)
            return multiple.map { published.appendingPathComponent($0.lastPathComponent) }
        }
        try validate(output, format: target)
        return [try FileOperations.publish(output, named: stem + "." + target.fileExtension, in: directory)]
    }

    private func validate(_ output: URL, format: FileFormat) throws {
        guard let size = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 else { throw ConversionError.failed("Движок создал пустой результат.") }
        let detected = try SourceFile(url: output).format
        // Markdown and delimited text have no unique signature; their writers are checked structurally.
        if [.txt, .md, .csv, .tsv].contains(format) { return }
        guard detected == format else { throw ConversionError.failed("Движок создал \(detected.label) вместо \(format.label).") }
    }

    private static let imageWriters = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
    private static let encoderCache = EncoderCache()
    private func supported(_ source: SourceFile, _ target: FileFormat) -> Bool {
        if supported(source.format, target) { return true }
        guard source.format != target, candidates(source.format).contains(target), ["Audio", "Video"].contains(source.format.category) else { return false }
        return NativeMedia.supports(source, to: target)
    }
    private func encoder(_ name: String) -> Bool {
        guard let ffmpeg = tools.ffmpeg else { return false }
        return Self.encoderCache.encoders(for: ffmpeg).contains(name)
    }
    private func supported(_ source: FileFormat, _ target: FileFormat) -> Bool {
        guard source != target, candidates(source).contains(target) else { return false }
        switch source.category {
        case "Images":
            return target == .pdf || target.imageType.map { Self.imageWriters.contains($0) } == true || (target == .webp && encoder("libwebp")) || (target == .avif && encoder("libaom-av1"))
        case "Audio", "Video":
            guard tools.ffmpeg != nil else { return false }
            if let audio = Self.audioEncoders[target] { return encoder(audio) }
            if target == .webm { return encoder("libvpx-vp9") && (encoder("libopus") || encoder("libvorbis")) }
            return encoder(target == .gif ? "gif" : target == .wmv ? "wmv2" : "mpeg4")
        case "Subtitles", "Archives": return true
        case "Spreadsheets": return source != .xls || tools.office != nil
        default:
            if [.ppt, .pptx, .pages].contains(source) { return tools.office != nil && target != .pages }
            return target != .pages
        }
    }

    private func candidates(_ source: FileFormat) -> [FileFormat] {
        switch source {
        case .jpg, .png, .webp, .heic, .tiff, .svg, .avif, .bmp: return [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .pdf]
        case .mp3, .m4a, .wav, .flac, .ogg, .opus, .aiff, .wma: return [.mp3, .m4a, .wav, .flac, .ogg, .opus, .aiff, .wma]
        case .mp4, .mov, .mkv, .webm, .avi, .wmv: return [.mp4, .mov, .mkv, .webm, .avi, .wmv, .gif, .mp3]
        case .gif: return [.mp4, .mov, .mkv, .webm, .avi, .wmv]
        case .pdf: return [.jpg, .png, .txt, .md]
        case .ppt, .pptx: return [.pdf, .jpg, .png]
        case .xlsx, .xls, .ods, .csv, .tsv: return [.xlsx, .ods, .csv, .tsv, .pdf]
        case .srt: return [.vtt, .txt]
        case .vtt: return [.srt, .txt]
        case .zip: return [.tar, .gzip]
        case .tar: return [.zip, .gzip]
        case .gzip: return [.zip, .tar]
        case .rar: return [.zip, .tar, .gzip]
        case .epub: return [.pdf, .docx, .txt, .md, .html]
        case .html: return []
        default: return [.docx, .pages, .pdf, .txt, .md, .html, .epub, .png, .jpg]
        }
    }

    private static let audioEncoders: [FileFormat: String] = [.mp3: "libmp3lame", .m4a: "aac", .wav: "pcm_s16le", .flac: "flac", .ogg: "libvorbis", .opus: "libopus", .aiff: "pcm_s16be", .wma: "wmav2"]
    private func media(_ source: SourceFile, to target: FileFormat, output: URL) throws {
        guard let ffmpeg = tools.ffmpeg else { throw ConversionError.unsupported("FFmpeg не найден.") }
        var arguments = ["-hide_banner", "-nostdin", "-loglevel", "error", "-n", "-i", source.url.path]
        if let audio = Self.audioEncoders[target] {
            arguments += ["-map", "0:a:0", "-vn", "-c:a", audio]
            if [.mp3, .m4a, .ogg, .opus, .wma].contains(target) { arguments += ["-b:a", "192k"] }
        } else if target == .webp || target == .avif {
            arguments += ["-frames:v", "1", "-c:v", target == .webp ? "libwebp" : "libaom-av1"]
        } else if target == .gif {
            arguments += ["-an", "-vf", "fps=15,scale=960:-2:force_original_aspect_ratio=decrease", "-loop", "0"]
        } else if target == .webm {
            arguments += ["-c:v", "libvpx-vp9", "-crf", "30", "-b:v", "0", "-c:a", encoder("libopus") ? "libopus" : "libvorbis"]
        } else {
            arguments += ["-c:v", target == .wmv ? "wmv2" : "mpeg4", "-q:v", "3", "-pix_fmt", "yuv420p", "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-c:a", target == .wmv ? "wmav2" : target == .avi ? "mp3" : "aac"]
        }
        arguments.append(output.path)
        _ = try ProcessRunner.checked(ffmpeg, arguments)
    }
}

private final class EncoderCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [URL: Set<String>] = [:]
    func encoders(for tool: URL) -> Set<String> {
        lock.lock(); defer { lock.unlock() }
        if let value = cache[tool] { return value }
        let output = (try? ProcessRunner.checked(tool, ["-hide_banner", "-encoders"])) ?? ""
        let value = Set(output.split(separator: "\n").compactMap { line -> String? in
            let fields = line.split(whereSeparator: \.isWhitespace)
            return fields.count >= 2 && fields[0].count == 6 && !fields[0].contains("=") ? String(fields[1]) : nil
        })
        cache[tool] = value
        return value
    }
}
