import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A content classification used to choose a converter, not a guarantee that every payload decodes.
/// Signatures and package contents take precedence; ambiguous text and legacy TAR use limited name hints.
public struct SourceFile: Sendable {
    /// The standardized source URL. The caller owns any required security-scoped access.
    public let url: URL
    /// The identified format; conversion rechecks it in case the file changes after selection.
    public let format: FileFormat

    /// Inspects an accessible, nonempty file or a supported RTFD/Pages package.
    /// This performs synchronous I/O and may invoke FFprobe, so call it away from the main thread.
    /// Unrecognized content, unsupported folders, and read failures throw instead of guessing a binary type.
    public init(url: URL) throws {
        self.url = url.standardizedFileURL
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])
        if values.isDirectory == true {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("TXT.rtf").path) { format = .rtfd; return }
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Index/Document.iwa").path) { format = .pages; return }
            throw ConversionError.unsupported("Folders are supported in Actions. Choose a file to convert.")
        }
        guard values.isRegularFile == true, (values.fileSize ?? 0) > 0 else { throw ConversionError.invalid("The file is empty or is not a regular file.") }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let head = try handle.read(upToCount: 65_536) ?? Data()
        let bytes = [UInt8](head)
        func starts(_ signature: [UInt8]) -> Bool { bytes.starts(with: signature) }
        let ascii = String(decoding: bytes, as: UTF8.self)
        // Container fields use byte offsets: binary size fields can resemble multibyte UTF-8 characters.
        let containerKind = bytes.count >= 12 ? String(decoding: bytes[8..<12], as: UTF8.self) : ""
        // Legacy RTF can contain non-UTF-8 bytes; recognize its ASCII signature before validating plain text.
        if ascii.hasPrefix("{\\rtf") { format = .rtf; return }
        if starts([0x25, 0x50, 0x44, 0x46, 0x2D]) { format = .pdf; return }
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0,
           let identifier = CGImageSourceGetType(source) as String? {
            let type = UTType(identifier)
            if identifier.contains("avif") { format = .avif; return }
            let mapping: [(FileFormat, UTType)] = [(.jpg, .jpeg), (.png, .png), (.gif, .gif), (.tiff, .tiff), (.bmp, .bmp), (.heic, .heic), (.webp, .webP)]
            if let match = mapping.first(where: { type?.conforms(to: $0.1) == true }) { format = match.0; return }
        }
        if starts([0x50, 0x4B, 0x03, 0x04]) || starts([0x50, 0x4B, 0x05, 0x06]) {
            // Office, EPUB, and ODS are ZIP packages; filenames alone cannot distinguish them safely.
            let names = Set(try ArchiveReader(url).entries().map(\.path))
            if names.contains("word/document.xml") { format = .docx }
            else if names.contains("ppt/presentation.xml") { format = .pptx }
            else if names.contains("xl/workbook.xml") { format = .xlsx }
            else if names.contains("META-INF/container.xml"),
                    let data = try ArchiveReader(url).file(named: "mimetype"), String(decoding: data, as: UTF8.self) == "application/epub+zip" { format = .epub }
            else if names.contains("Index/Document.iwa") { format = .pages }
            else if names.contains("content.xml") && names.contains("META-INF/manifest.xml"),
                    let data = try ArchiveReader(url).file(named: "mimetype"), String(decoding: data, as: UTF8.self) == "application/vnd.oasis.opendocument.spreadsheet" { format = .ods }
            else { format = .zip }
            return
        }
        if starts([0x1F, 0x8B]) {
            guard let reader = try? ArchiveReader(url), let contents = try? reader.entries(), !contents.isEmpty, reader.isTar else {
                throw ConversionError.unsupported("Only TAR.GZ is supported. A single-file GZIP stream or an empty archive cannot be converted.")
            }
            format = .gzip; return
        }
        if bytes.count >= 262 && String(decoding: bytes[257..<262], as: UTF8.self) == "ustar" { format = .tar; return }
        if starts([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07]) { format = .rar; return }
        if starts([0x66, 0x4C, 0x61, 0x43]) { format = .flac; return }
        if ascii.hasPrefix("RIFF") {
            if containerKind == "WAVE" { format = .wav; return }
            if containerKind == "AVI " { format = .avi; return }
            if containerKind == "WEBP" { format = .webp; return }
        }
        if ascii.hasPrefix("FORM") && (containerKind == "AIFF" || containerKind == "AIFC") { format = .aiff; return }
        if ascii.hasPrefix("OggS") { format = head.range(of: Data("OpusHead".utf8)) == nil ? .ogg : .opus; return }
        // Check the MPEG frame fields as well as sync bits, which would also match a UTF-16 BOM.
        let mp3Frame = bytes.count >= 4 && bytes[0] == 0xFF && bytes[1] & 0xE0 == 0xE0
            && (bytes[1] >> 3) & 0x03 != 1 && (bytes[1] >> 1) & 0x03 == 1
            && bytes[2] >> 4 != 0 && bytes[2] >> 4 != 15 && (bytes[2] >> 2) & 0x03 != 3
        if ascii.hasPrefix("ID3") || mp3Frame { format = .mp3; return }
        if bytes.count > 12 && String(decoding: bytes[4..<8], as: UTF8.self) == "ftyp" {
            let brand = String(decoding: bytes[8..<12], as: UTF8.self)
            if ["heic", "heix", "hevc", "mif1"].contains(brand) { format = .heic }
            else if ["avif", "avis"].contains(brand) { format = .avif }
            else if brand.hasPrefix("M4A") || brand.hasPrefix("M4B") { format = .m4a }
            else if brand == "qt  " { format = .mov }
            else { format = .mp4 }
            return
        }
        if starts([0x1A, 0x45, 0xDF, 0xA3]) { format = head.range(of: Data("webm".utf8)) != nil ? .webm : .mkv; return }
        if starts([0x30, 0x26, 0xB2, 0x75, 0x8E, 0x66, 0xCF, 0x11]) {
            guard let probe = Tools().ffprobe else { throw ConversionError.unsupported("FFprobe is required to identify ASF files.") }
            let output = try ProcessRunner.checked(probe, ["-v", "error", "-protocol_whitelist", "fd",
                "-show_entries", "stream=codec_type", "-of", "csv=p=0", "fd:"], input: url, timeout: 15)
            format = output.contains("video") ? .wmv : .wma; return
        }
        if starts([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]) {
            let utf16 = String(data: head, encoding: .utf16LittleEndian) ?? ""
            if utf16.contains("PowerPoint Document") { format = .ppt; return }
            if utf16.contains("Workbook") || utf16.contains("Book\0") { format = .xls; return }
        }
        if url.pathExtension.lowercased() == "tar", let reader = try? ArchiveReader(url), let entries = try? reader.entries(), !entries.isEmpty, reader.isTar { format = .tar; return }
        // A bounded prefix can end in the middle of a UTF-8 character.
        let utf8 = (0...min(3, head.count)).lazy.compactMap { String(data: head.dropLast($0), encoding: .utf8) }.first
        let utf16 = (starts([0xFF, 0xFE]) || starts([0xFE, 0xFF])) ? String(data: head, encoding: .utf16) : nil
        guard let text = utf8 ?? utf16,
              text.unicodeScalars.allSatisfy({ $0.value >= 32 || [9, 10, 13].contains($0.value) }) else {
            throw ConversionError.unsupported("Could not identify the format from the file contents: \(url.lastPathComponent)")
        }
        let trimmed = text.replacingOccurrences(of: "\u{FEFF}", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hasNewline = text.rangeOfCharacter(from: .newlines) != nil
        if trimmed.contains("<svg") { format = .svg }
        else if trimmed.hasPrefix("{\\rtf") { format = .rtf }
        else if trimmed.hasPrefix("webvtt") { format = .vtt }
        else if text.range(of: #"\d{2}:\d{2}:\d{2},\d{3}\s+-->"#, options: .regularExpression) != nil { format = .srt }
        else if trimmed.hasPrefix("<!doctype html") || trimmed.contains("<html") { format = .html }
        else if text.contains("\t") && hasNewline { format = .tsv }
        else if text.contains(",") && hasNewline {
            // A prefix can end inside a quoted CSV field; parse the bounded full text before classifying it.
            let fullText = try TextFile.read(url)
            let rows = try? DelimitedText.parse(fullText, separator: ",")
            format = (rows?.first?.count ?? 0) > 1 ? .csv : .txt
        }
        else if text.range(of: #"(?m)^(#{1,6} |[-*] |```|\|.+\|)"#, options: .regularExpression) != nil || url.pathExtension.lowercased() == "md" { format = .md }
        else { format = .txt }
    }
}
