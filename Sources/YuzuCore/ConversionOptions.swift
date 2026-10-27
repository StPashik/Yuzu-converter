import Foundation

public enum ConversionQuality: String, CaseIterable, Codable, Sendable, Hashable {
    case compact, balanced, high

    // These are Yuzu's encoding choices, not recovered Tangerine numeric defaults.
    var imageQuality: Double { self == .compact ? 0.65 : self == .balanced ? 0.9 : 1 }
    var audioBitrate: Int { self == .compact ? 96 : self == .balanced ? 192 : 256 }
}

public enum AudioSampleDepth: String, CaseIterable, Codable, Sendable, Hashable {
    case matchSource, bit16, bit24, bit32, float32
}

public enum ArchiveCompression: String, CaseIterable, Codable, Sendable, Hashable {
    case fast, balanced, maximum
    var level: Int { self == .fast ? 1 : self == .balanced ? 6 : 9 }
}

public enum EPUBLayout: String, CaseIterable, Codable, Sendable, Hashable {
    case adjustableText, preservePages
}

public enum PDFOfficeLayout: String, CaseIterable, Codable, Sendable, Hashable {
    case editable, preservePages
}

/// Immutable job snapshots keep a later Settings change from altering a queued conversion.
/// Fields retain the researched vocabulary; unavailable layouts fail rather than pretend to work.
public struct ConversionOptions: Codable, Equatable, Sendable {
    public var quality: ConversionQuality
    public var preserveMetadata: Bool
    public var videoMaxHeight: Int?
    /// Compressed-audio bitrate in kilobits per second; nil follows the selected quality.
    public var audioBitrate: Int?
    public var audioSampleDepth: AudioSampleDepth
    public var gifFrameRate: Int?
    public var gifMaxWidth: Int?
    public var compression: ArchiveCompression
    public var epubLayout: EPUBLayout
    public var epubReflowVersion: Int
    public var pdfOfficeLayout: PDFOfficeLayout

    public init(quality: ConversionQuality = .balanced, preserveMetadata: Bool = true,
                videoMaxHeight: Int? = nil, audioBitrate: Int? = nil,
                audioSampleDepth: AudioSampleDepth = .bit16, gifFrameRate: Int? = nil,
                gifMaxWidth: Int? = nil, compression: ArchiveCompression = .balanced,
                epubLayout: EPUBLayout = .adjustableText, epubReflowVersion: Int = 2,
                pdfOfficeLayout: PDFOfficeLayout = .editable) {
        self.quality = quality
        self.preserveMetadata = preserveMetadata
        self.videoMaxHeight = videoMaxHeight
        self.audioBitrate = audioBitrate
        self.audioSampleDepth = audioSampleDepth
        self.gifFrameRate = gifFrameRate
        self.gifMaxWidth = gifMaxWidth
        self.compression = compression
        self.epubLayout = epubLayout
        self.epubReflowVersion = epubReflowVersion
        self.pdfOfficeLayout = pdfOfficeLayout
    }

    /// Validate saved numeric values as untrusted input before passing them to an encoder or tool.
    public func validate(for target: FileFormat) throws {
        for (name, value, range) in [("Video height", videoMaxHeight, 72...4320),
                                    ("Audio bitrate", audioBitrate, 16...512),
                                    ("GIF frame rate", gifFrameRate, 1...60),
                                    ("GIF width", gifMaxWidth, 16...8192)] {
            if let value, !range.contains(value) { throw ConversionError.invalid("\(name) must be within \(range.lowerBound)…\(range.upperBound).") }
        }
        guard [2, 3].contains(epubReflowVersion) else { throw ConversionError.invalid("The EPUB version must be 2 or 3.") }
        let lossyAudio: Set<FileFormat> = [.mp3, .m4a, .ogg, .opus, .wma]
        let video: Set<FileFormat> = [.mp4, .mov, .mkv, .webm, .avi, .wmv]
        let raster: Set<FileFormat> = [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp]
        func applicable(_ condition: Bool, _ name: String) throws {
            guard condition else { throw ConversionError.unsupported("\(name) is not available for \(target.label) output.") }
        }
        if quality != .balanced { try applicable([.jpg, .heic, .webp, .avif].contains(target) || lossyAudio.contains(target) || video.contains(target), "Quality selection") }
        if !preserveMetadata { try applicable(raster.contains(target) || lossyAudio.contains(target) || target == .flac || video.contains(target), "Metadata removal") }
        if videoMaxHeight != nil { try applicable(video.contains(target), "Video height") }
        if audioBitrate != nil { try applicable(lossyAudio.contains(target), "Audio bitrate") }
        if audioSampleDepth != .bit16 { try applicable([.wav, .aiff].contains(target), "PCM sample depth") }
        if gifFrameRate != nil || gifMaxWidth != nil { try applicable(target == .gif, "GIF encoding options") }
        if compression != .balanced { try applicable([.zip, .gzip].contains(target), "Archive compression") }
        if epubReflowVersion != 2 { try applicable(target == .epub, "EPUB version") }
        guard epubLayout == .adjustableText else { throw ConversionError.unsupported("Preserving original pages in EPUB is not available with the text-based document reader.") }
        guard pdfOfficeLayout == .editable else { throw ConversionError.unsupported("Preserving PDF pages in Office output is not available. Editable PDF-to-Office conversion is also unavailable.") }
    }
}

/// Format-level routing cannot establish whether a particular media asset decodes successfully.
public enum ConversionAvailability: Equatable, Sendable {
    case available, dependsOnFile, unavailable
}
