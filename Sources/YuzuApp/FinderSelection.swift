import AppKit
import Carbon

enum FinderSelection {
    /// Call serially off the main thread; Finder and its Automation prompt may take time to respond.
    static func read() throws -> [URL] {
        // Fixed source only: filenames never become executable AppleScript or shell input.
        let script = NSAppleScript(source: """
            with timeout of 10 seconds
                tell application id "com.apple.finder" to return selection as alias list
            end timeout
            """)
        var error: NSDictionary?
        guard let result = script?.executeAndReturnError(&error) else {
            let code = (error?[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
            throw FinderSelectionError.script(code)
        }
        return try urls(from: result)
    }

    static func urls(from result: NSAppleEventDescriptor) throws -> [URL] {
        guard result.descriptorType == typeAEList else { throw FinderSelectionError.invalidSelection }
        var files: [URL] = []
        var seen = Set<URL>()
        for index in 0..<result.numberOfItems {
            // fileURLValue also coerces arbitrary text, so accept only actual file descriptors.
            guard let item = result.atIndex(index + 1), [typeAlias, typeFileURL].contains(item.descriptorType),
                  let url = item.fileURLValue, url.isFileURL, !url.path.contains("\0") else {
                throw FinderSelectionError.invalidSelection
            }
            if seen.insert(url.standardizedFileURL).inserted { files.append(url) }
        }
        guard !files.isEmpty else { throw FinderSelectionError.emptySelection }
        return files
    }
}

enum FinderSelectionError: LocalizedError {
    case script(Int), invalidSelection, emptySelection
    var errorDescription: String? {
        switch self {
        case .script(-1743), .script(-10004):
            return L10n.text("Allow Yuzu Converter to access Finder in System Settings → Privacy & Security → Automation, then try again.")
        case .script(-1712): return L10n.text("Finder did not respond in time. Try again.")
        case .script, .invalidSelection: return L10n.text("Could not read the selected Finder files. Try selecting them again.")
        case .emptySelection: return L10n.text("Select one or more files in Finder first.")
        }
    }
}
