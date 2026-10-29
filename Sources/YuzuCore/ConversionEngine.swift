import AppKit
import ImageIO
import Darwin

/// Chooses available backends and turns one classified source into a complete, validated output set.
/// Converters write only into private staging; this type owns cleanup and final publication.
public struct ConversionEngine: Sendable {
    private let tools: Tools
    /// Captures executable locations. Format and encoder availability is checked when routes are requested.
    public init() { tools = Tools() }

    /// Returns ordered output formats supported by every source in the same routing category.
    /// Current input formats are excluded. This can probe files or encoders synchronously; call off the main thread.
    /// An available route describes a supported export, not a guarantee of lossless format preservation.
    public func targets(for sources: [SourceFile]) -> [FileFormat] {
        // Mixed drops only offer formats supported by every input, avoiding misleading targets.
        guard let first = sources.first else { return [] }
        return candidates(first.format).filter { target in sources.allSatisfy { $0.format != target && candidates($0.format).contains(target) && supported($0, target) } }
    }

    /// A PDF drop is one document: validate every image before publishing the complete page set.
    public func combineImages(_ sources: [SourceFile], in directory: URL,
                              options: ConversionOptions = .init()) throws -> URL {
        guard !sources.isEmpty, sources.allSatisfy({ $0.format.category == "Images" && supported($0, .pdf) }) else {
            throw ConversionError.unsupported("Choose supported images to combine into PDF.")
        }
        try options.validate(for: .pdf)
        let scratch = try FileOperations.scratch(in: directory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let output = scratch.appendingPathComponent("combined.pdf")
        try NativeDocuments.imagesPDF(sources.map(\.url), output: output)
        try Task.checkCancellation()
        try validate(output, format: .pdf)
        return try FileOperations.publish(output, named: sources[0].url.deletingPathExtension().lastPathComponent + ".pdf", in: directory)
    }

    /// Virtual drops can also save their original format; all offered writers are native and checked at runtime.
    public static var imageDropTargets: [FileFormat] {
        [.png, .jpg, .tiff, .heic, .bmp, .webp, .avif, .pdf, .txt].filter { $0 == .txt || $0 == .pdf || $0.imageType.map { imageWriters.contains($0) } == true }
    }

    /// Save Panel grants an exact file, not its parent: stage through Foundation's same-volume replacement directory.
    public func saveDroppedImage(_ source: URL, to target: FileFormat, destination: URL,
                                 options: ConversionOptions = .init()) async throws -> URL {
        guard destination.isFileURL, Self.imageDropTargets.contains(target) else { throw ConversionError.unsupported("Unsupported image destination.") }
        try options.validate(for: target)
        try Task.checkCancellation()
        let scratch = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                  appropriateFor: destination, create: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let staged = scratch.appendingPathComponent("result." + target.fileExtension)
        if target == .txt { try await TextRecognition.image(source).write(to: staged, atomically: false, encoding: .utf8) }
        else { try NativeDocuments.image(source, to: target, output: staged, options: options) }
        try validate(staged, format: target)
        try Task.checkCancellation()
        // Exact-path publication cannot try sibling suffixes outside the Save Panel grant.
        let result = staged.path.withCString { from in
            destination.path.withCString { to in renamex_np(from, to, UInt32(RENAME_EXCL)) }
        }
        guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        return destination
    }

    /// Read-only format catalogue for Settings; actual files are still probed by targets(for:).
    /// Native media support is conditional on the asset rather than a filename or enum case.
    public func availability(from source: FileFormat, to target: FileFormat) -> ConversionAvailability {
        guard source != target, candidates(source).contains(target) else { return .unavailable }
        if source.category == "Video", target == .mp3, supported(source, target) { return .dependsOnFile }
        if supported(source, target) { return .available }
        if source.category == "Audio", [.wav, .aiff, .m4a].contains(target) { return .dependsOnFile }
        if source.category == "Video", source != .gif, [.mov, .mp4].contains(target) { return .dependsOnFile }
        return .unavailable
    }

    /// Converts into an existing writable directory while leaving the original and existing results intact.
    /// Returns every output file; page/sheet sets are published together in a new folder under a free name.
    /// The caller must retain source/destination grants and use a background task: most I/O remains blocking.
    /// Cancellation is cooperative between chunks/pages/stages and terminates active child-process exports.
    /// Failure or cancellation before publication discards private staging rather than publishing partial results.
    public func convert(_ source: SourceFile, to target: FileFormat, in directory: URL,
                        options: ConversionOptions = .init(),
                        onWarning: @Sendable ([String]) async -> Void = { _ in }) async throws -> [URL] {
        try Task.checkCancellation()
        try options.validate(for: target)
        let current = try SourceFile(url: source.url)
        guard current.format == source.format else { throw ConversionError.invalid("The source format changed after selection.") }
        guard supported(source, target) else { throw ConversionError.unsupported("Conversion from \(source.format.label) to \(target.label) is unavailable.") }
        let scratch = try FileOperations.scratch(in: directory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let output = scratch.appendingPathComponent("result." + target.fileExtension)
        var multiple: [URL] = []
        var warnings: [String] = []
        let stem = source.url.deletingPathExtension().lastPathComponent

        if source.format == .pdf, target == .jpg || target == .png {
            multiple = try NativeDocuments.pdfPages(source.url, to: target, directory: scratch.appendingPathComponent("pages", isDirectory: true), options: options)
        } else if source.format.category == "Images" {
            if target == .txt { try await TextRecognition.image(source.url).write(to: output, atomically: false, encoding: .utf8) }
            else if target == .pdf || (target.imageType.map { Self.imageWriters.contains($0) } ?? false) {
                try NativeDocuments.image(source.url, to: target, output: output, options: options)
            } else { try media(source, to: target, output: output, options: options) }
        } else if source.format.category == "Audio" || source.format.category == "Video" {
            if source.format.category == "Video", source.format != .gif, [.mp4, .mov, .mkv, .webm, .avi, .wmv].contains(target),
               let probe = tools.ffprobe, tools.ffmpeg != nil, NativeMedia.supportsFFmpegPlayback(source) {
                let tracks = try MediaTracks(url: source.url, probe: probe)
                let plan = tracks.plan(target: target, preserveMetadata: options.preserveMetadata)
                try media(source, to: target, output: output, options: options, trackArguments: plan.arguments)
                warnings += try tracks.validate(output, probe: probe, plan: plan)
                warnings += plan.warnings
            }
            // Keep native playback semantics for disabled/muted tracks that FFmpeg cannot represent safely.
            else if NativeMedia.supports(source, to: target) {
                do { try await NativeMedia.convert(source, to: target, output: output, options: options) }
                catch {
                    try Task.checkCancellation()
                    // Native preflight can succeed before VideoToolbox rejects the requested video profile.
                    guard source.format.category == "Video", [.mp4, .mov].contains(target),
                          NativeMedia.hasVideoToolboxParameterFailure(error), supported(source.format, target),
                          NativeMedia.supportsFFmpegPlayback(source) else { throw error }
                    if FileManager.default.fileExists(atPath: output.path) { try FileManager.default.removeItem(at: output) }
                    try media(source, to: target, output: output, options: options)
                }
            }
            else { try media(source, to: target, output: output, options: options) }
            if source.format.category == "Video", source.format != .gif, [.mp4, .mov].contains(target),
               !NativeMedia.supportsFFmpegPlayback(source), let probe = tools.ffprobe {
                let original = try MediaTracks(url: source.url, probe: probe)
                let result = try MediaTracks(url: output, probe: probe)
                if result.streams.filter({ $0.codec_type == "audio" }).count < original.streams.filter({ $0.codec_type == "audio" }).count {
                    warnings.append("The system exporter combined audio tracks to preserve the source playback gain and disabled-track settings. Separate tracks remain in the original file.")
                }
                if result.streams.filter({ $0.codec_type == "subtitle" }).count < original.streams.filter({ $0.codec_type == "subtitle" }).count {
                    warnings.append("The system exporter could not retain every subtitle track. They remain in the original file.")
                }
                if options.preserveMetadata, result.chapterCount < original.chapterCount {
                    warnings.append("The system exporter could not retain every chapter. They remain in the original file.")
                }
            }
        } else if source.format.category == "Subtitles" {
            let cues = try Subtitles.parse(TextFile.read(source.url), format: source.format)
            try Subtitles.write(cues, format: target).write(to: output, atomically: false, encoding: .utf8)
        } else if source.format.category == "Archives" {
            let contents = scratch.appendingPathComponent("contents", isDirectory: true)
            try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: false)
            guard !(try ArchiveReader(source.url).entries(extractingTo: contents)).isEmpty else { throw ConversionError.invalid("The archive is empty.") }
            var arguments = target == .zip ? ["-q", "-r", "-\(options.compression.level)", output.path, "."]
                : [target == .gzip ? "-czf" : "-cf", output.path]
            if target == .gzip { arguments += ["--options", "gzip:compression-level=\(options.compression.level)"] }
            if target != .zip { arguments += ["-C", contents.path, "."] }
            _ = try ProcessRunner.checked(URL(fileURLWithPath: target == .zip ? "/usr/bin/zip" : "/usr/bin/tar"), arguments, directory: contents)
        } else if source.format.category == "Spreadsheets" && source.format != .xls {
            let sheets = try Spreadsheet.read(source, scratch: scratch)
            guard !sheets.isEmpty else { throw ConversionError.invalid("The workbook has no available sheets.") }
            if target == .csv || target == .tsv {
                let folder = scratch.appendingPathComponent("sheets", isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
                for (index, sheet) in sheets.enumerated() {
                    let file = folder.appendingPathComponent("Sheet \(index + 1)." + target.fileExtension)
                    try DelimitedText.write(sheet.rows, separator: target == .csv ? "," : "\t").write(to: file, atomically: false, encoding: .utf8)
                    multiple.append(file)
                }
            } else if target == .pdf {
                try Spreadsheet.writePDF(sheets, output: output)
            } else { try Spreadsheet.write(sheets, to: target, output: output, scratch: scratch) }
        } else if [.ppt, .pptx, .pages, .xls].contains(source.format) {
            guard let office = tools.office else { throw ConversionError.unsupported("LibreOffice is required for this format.") }
            // A per-job profile avoids attaching to another LibreOffice instance or sharing its mutable state.
            let profile = scratch.appendingPathComponent("office-profile").absoluteString
            let officeOutput = scratch.appendingPathComponent("office-output", isDirectory: true)
            try FileManager.default.createDirectory(at: officeOutput, withIntermediateDirectories: false)
            let officeTarget: FileFormat = target == .jpg || target == .png ? .pdf : target
            _ = try ProcessRunner.checked(office, ["-env:UserInstallation=" + profile, "--headless", "--convert-to", officeTarget.rawValue, "--outdir", officeOutput.path, source.url.path])
            let converted = officeOutput.appendingPathComponent(stem + "." + officeTarget.rawValue)
            guard FileManager.default.fileExists(atPath: converted.path) else { throw ConversionError.failed("LibreOffice did not create an output file.") }
            if target == .jpg || target == .png { multiple = try NativeDocuments.pdfPages(converted, to: target, directory: scratch.appendingPathComponent("pages", isDirectory: true), options: options) }
            else { try FileManager.default.moveItem(at: converted, to: output) }
        } else {
            let text = source.format == .epub ? try EPUB.read(source.url, scratch: scratch) : try await NativeDocuments.readText(source, scratch: scratch)
            if target == .epub { try EPUB.write(text, title: stem, output: output, scratch: scratch, version: options.epubReflowVersion) }
            else if target == .jpg || target == .png {
                let pdf = scratch.appendingPathComponent("document.pdf")
                try NativeDocuments.writePDF(text, output: pdf)
                multiple = try NativeDocuments.pdfPages(pdf, to: target, directory: scratch.appendingPathComponent("pages", isDirectory: true), options: options)
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
        let published = try FileOperations.publish(output, named: stem + "." + target.fileExtension, in: directory)
        if !warnings.isEmpty { await onWarning(warnings) }
        return [published]
    }

    // Exit status alone is insufficient: reopen the result to catch empty files or a wrong container.
    private func validate(_ output: URL, format: FileFormat) throws {
        guard let size = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 else { throw ConversionError.failed("The engine created an empty output file.") }
        let detected = try SourceFile(url: output).format
        // Markdown and delimited text have no unique signature; their writers are checked structurally.
        if [.txt, .md, .csv, .tsv].contains(format) { return }
        guard detected == format else { throw ConversionError.failed("The engine created \(detected.label) instead of \(format.label).") }
    }

    private static let imageWriters = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
    private static let encoderCache = EncoderCache()
    private func supported(_ source: SourceFile, _ target: FileFormat) -> Bool {
        if source.format.category == "Video", target == .mp3 {
            guard let probe = tools.ffprobe,
                  let streams = try? ProcessRunner.checked(probe, ["-v", "error", "-protocol_whitelist", "fd",
                    "-select_streams", "a:0", "-show_entries", "stream=codec_type", "-of", "csv=p=0", "fd:"], input: source.url, timeout: 15),
                  streams.split(whereSeparator: \.isWhitespace).contains("audio") else { return false }
        }
        if supported(source.format, target) {
            return NativeMedia.supports(source, to: target) || NativeMedia.supportsFFmpegPlayback(source)
        }
        // Native support varies with the actual asset, so the fallback cannot rely on its extension alone.
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
            return target == .txt || target == .pdf || target.imageType.map { Self.imageWriters.contains($0) } == true || (target == .webp && encoder("libwebp")) || (target == .avif && encoder("libaom-av1"))
        case "Audio", "Video":
            guard tools.ffmpeg != nil else { return false }
            if let audio = Self.audioEncoders[target] { return encoder(audio) }
            if target == .webm { return encoder("libvpx-vp9") && (encoder("libopus") || encoder("libvorbis")) }
            if target == .gif { return encoder("gif") }
            // A video route also needs the audio encoder used by its command; a muxer alone is insufficient.
            return encoder(target == .wmv ? "wmv2" : "mpeg4")
                && encoder(target == .wmv ? "wmav2" : target == .avi ? "libmp3lame" : "aac")
        case "Subtitles", "Archives": return true
        case "Spreadsheets": return source != .xls || tools.office != nil
        default:
            if [.ppt, .pptx, .pages].contains(source) { return tools.office != nil && target != .pages }
            return target != .pages
        }
    }

    // Keep route ordering separate from runtime checks; listing a candidate must not bypass availability gates.
    private func candidates(_ source: FileFormat) -> [FileFormat] {
        switch source {
        case .jpg, .png, .webp, .heic, .tiff, .avif, .bmp: return [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .pdf, .txt]
        case .svg: return [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .pdf]
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
    private static let mediaMuxers: [FileFormat: String] = [.mp4: "mp4", .mov: "mov", .mkv: "matroska",
        .webm: "webm", .avi: "avi", .wmv: "asf", .gif: "gif", .mp3: "mp3", .m4a: "ipod",
        .wav: "wav", .flac: "flac", .ogg: "ogg", .opus: "opus", .aiff: "aiff", .wma: "asf",
        .webp: "webp", .avif: "avif"]
    private func media(_ source: SourceFile, to target: FileFormat, output: URL, options: ConversionOptions, trackArguments: [String]? = nil) throws {
        guard let ffmpeg = tools.ffmpeg else { throw ConversionError.unsupported("FFmpeg was not found.") }
        guard let muxer = Self.mediaMuxers[target] else { throw ConversionError.unsupported("No media muxer for \(target.label).") }
        // fd: preserves seeking for MOV/MP4 without giving the helper arbitrary path or network access.
        var arguments = ["-hide_banner", "-nostdin", "-loglevel", "error", "-y",
                         "-protocol_whitelist", "fd", "-i", "fd:"]
        if options.preserveMetadata { arguments += ["-map_metadata", "0"] }
        else {
            // Global metadata, stream tags, and chapters have independent automatic-copy rules in FFmpeg.
            arguments += ["-map_metadata", "-1", "-map_metadata:s", "-1", "-map_chapters", "-1"]
        }
        if let audio = Self.audioEncoders[target] {
            // Audio exports intentionally select the first audio stream and discard video/cover-art streams.
            var codec = audio
            if target == .wav || target == .aiff {
                let depth = try NativeMedia.resolvedDepth(options.audioSampleDepth, source: source.url)
                let encoding = depth == .float32 ? "f32" : depth == .bit24 ? "s24" : depth == .bit32 ? "s32" : "s16"
                codec = "pcm_" + encoding + (target == .aiff ? "be" : "le")
            }
            arguments += ["-map", "0:a:0", "-vn", "-c:a", codec]
            if [.mp3, .m4a, .ogg, .opus, .wma].contains(target) {
                // A manual bitrate overrides the quality preset's automatic bitrate.
                arguments += ["-b:a", "\(options.audioBitrate ?? options.quality.audioBitrate)k"]
            }
        } else if target == .webp || target == .avif {
            arguments += ["-frames:v", "1", "-c:v", target == .webp ? "libwebp" : "libaom-av1"]
            if target == .webp { arguments += ["-quality", String(Int(options.quality.imageQuality * 100))] }
            else { arguments += ["-crf", options.quality == .compact ? "40" : options.quality == .balanced ? "26" : "16", "-b:v", "0"] }
        } else if target == .gif {
            arguments += ["-map", "0:v:0", "-an", "-vf", "fps=\(options.gifFrameRate ?? 15),scale=min(iw\\,\(options.gifMaxWidth ?? 960)):-2", "-loop", "0"]
        } else if target == .webm {
            // WebM requires compatible video and audio encoders; container support alone is not enough.
            // Palette/RGB GIF inputs otherwise select VP9's experimental alpha/RGB pixel formats.
            arguments += ["-c:v", "libvpx-vp9", "-pix_fmt", "yuv420p", "-crf", options.quality == .compact ? "40" : options.quality == .balanced ? "30" : "20", "-b:v", "0", "-c:a", encoder("libopus") ? "libopus" : "libvorbis"]
            if let height = options.videoMaxHeight { arguments += ["-vf", "scale=-2:trunc(min(ih\\,\(height))/2)*2"] }
        } else {
            // Even dimensions and 4:2:0 pixels avoid encoder failures on odd-sized source frames.
            let scale = options.videoMaxHeight.map { "scale=-2:trunc(min(ih\\,\($0))/2)*2" }
                ?? "scale=trunc(iw/2)*2:trunc(ih/2)*2"
            arguments += ["-c:v", target == .wmv ? "wmv2" : "mpeg4", "-q:v", options.quality == .compact ? "8" : options.quality == .balanced ? "3" : "1", "-pix_fmt", "yuv420p", "-vf", scale, "-c:a", target == .wmv ? "wmav2" : target == .avi ? "libmp3lame" : "aac"]
        }
        if source.format.category == "Video", target != .gif, Self.audioEncoders[target] == nil {
            arguments += trackArguments ?? ["-map", "0:v:0", "-map", "0:a:0?", "-sn", "-dn"]
        }
        arguments += ["-f", muxer, "fd:"]
        // Real videos can take longer than a probe's five-minute limit; user cancellation still stops the child.
        _ = try ProcessRunner.checked(ffmpeg, arguments, input: source.url, output: output, timeout: .infinity)
    }
}

/// Serializes encoder discovery and caches it by executable path so target updates do not spawn repeated probes.
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
