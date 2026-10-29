import Foundation
import YuzuCore

/// Error codes survive language changes; the original diagnostic stays available in Details.
enum JobRecovery: Equatable {
    case missing, access, space, exists, damaged, network, unsupported, other, newDrag, resultsPreserved

    init(_ error: Error) {
        if case .unsupported = error as? ConversionError { self = .unsupported; return }
        var current = error as NSError
        for _ in 0..<8 {
            if current.domain == NSCocoaErrorDomain {
                switch CocoaError.Code(rawValue: current.code) {
                case .fileNoSuchFile, .fileReadNoSuchFile: self = .missing; return
                case .fileReadNoPermission, .fileWriteNoPermission, .fileWriteVolumeReadOnly: self = .access; return
                case .fileWriteOutOfSpace: self = .space; return
                case .fileWriteFileExists: self = .exists; return
                case .fileReadCorruptFile: self = .damaged; return
                default: break
                }
            }
            if current.domain == NSPOSIXErrorDomain, let code = POSIXErrorCode(rawValue: Int32(clamping: current.code)) {
                switch code {
                case .ENOENT, .ENOTDIR: self = .missing; return
                case .EACCES, .EPERM, .EROFS: self = .access; return
                case .ENOSPC, .EDQUOT: self = .space; return
                case .EEXIST, .ENOTEMPTY: self = .exists; return
                default: break
                }
            }
            if current.domain == NSURLErrorDomain { self = .network; return }
            guard let underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError else { break }
            current = underlying
        }
        self = .other
    }

    var text: (title: String, suggestion: String) {
        switch self {
        case .missing:
            return ("A file or folder is unavailable", "Reconnect the drive or restore the original location. You can also submit the file from its new location.")
        case .access:
            return ("Access is required", "Check file permissions and folder access in Settings. Submit the files again if a new access grant is needed.")
        case .space:
            return ("Not enough free space", "Free space on the destination drive, then retry unfinished files.")
        case .exists:
            return ("The destination already exists", "Rename or move the existing result before retrying, or choose a new filename. Existing files are never replaced.")
        case .damaged:
            return ("The source could not be read", "Open the file in its original app and repair or replace it, then retry.")
        case .network:
            return ("The image could not be downloaded", "Check your connection or use another image link. A link that requires browser sign-in may need a fresh image drag.")
        case .unsupported:
            return ("This operation is unavailable", "Choose another format or destination. Details explain the current limitation.")
        case .other:
            return ("The operation could not finish", "Check the source and destination, then retry unfinished files. Details include the original error.")
        case .newDrag:
            return ("The image needs to be dragged again", "The source app cannot replay this image promise. Drag the image again to make a new request.")
        case .resultsPreserved:
            return ("Created results have been preserved", "No inputs remain to retry. Check the source and created copies before removing anything.")
        }
    }
}
