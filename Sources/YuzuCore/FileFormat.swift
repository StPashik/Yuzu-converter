import Foundation
import UniformTypeIdentifiers

public enum FileFormat: String, CaseIterable, Sendable, Hashable {
    case jpg, png, webp, heic, tiff, svg, avif, bmp, gif, pdf
    case mp3, m4a, wav, flac, ogg, opus, aiff, wma
    case mp4, mov, mkv, webm, avi, wmv
    case docx, pages, md, rtf, rtfd, txt, html, epub, ppt, pptx
    case xlsx, xls, ods, csv, tsv, srt, vtt, zip, tar, gzip, rar

    public var label: String { self == .gzip ? "TAR.GZ" : rawValue.uppercased() }
    public var fileExtension: String { self == .gzip ? "tar.gz" : rawValue }
    public var category: String {
        switch self {
        case .jpg, .png, .webp, .heic, .tiff, .svg, .avif, .bmp: return "Images"
        case .mp3, .m4a, .wav, .flac, .ogg, .opus, .aiff, .wma: return "Audio"
        case .mp4, .mov, .mkv, .webm, .avi, .wmv, .gif: return "Video"
        case .xlsx, .xls, .ods, .csv, .tsv: return "Spreadsheets"
        case .srt, .vtt: return "Subtitles"
        case .zip, .tar, .gzip, .rar: return "Archives"
        default: return "Documents"
        }
    }

    var imageType: String? {
        switch self {
        case .jpg: return UTType.jpeg.identifier
        case .png: return UTType.png.identifier
        case .heic: return UTType.heic.identifier
        case .tiff: return UTType.tiff.identifier
        case .bmp: return UTType.bmp.identifier
        case .webp: return UTType.webP.identifier
        case .avif: return "public.avif"
        default: return nil
        }
    }
}

public enum ConversionError: LocalizedError {
    case unsupported(String), invalid(String), failed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupported(let message), .invalid(let message), .failed(let message): return message
        }
    }
}
