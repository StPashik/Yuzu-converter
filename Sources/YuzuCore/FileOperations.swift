import Foundation
import Darwin

/// A completed move maps the original path and, for real directories, its descendants.
public struct FileMove: Sendable, Equatable {
    public let source: URL
    public let destination: URL
    public let includesDescendants: Bool

    public init(source: URL, destination: URL, includesDescendants: Bool) {
        self.source = source.standardizedFileURL
        self.destination = destination.standardizedFileURL
        self.includesDescendants = includesDescendants
    }

    public func relocating(_ url: URL) -> URL? {
        guard source.isFileURL, destination.isFileURL, url.isFileURL else { return nil }
        let root = source.pathComponents, path = url.standardizedFileURL.pathComponents
        // The old path may no longer exist; lexical components also avoid following a moved symlink.
        guard path.count >= root.count, Array(path.prefix(root.count)) == root,
              path.count == root.count || includesDescendants else { return nil }
        return path.dropFirst(root.count).reduce(destination) { $0.appendingPathComponent($1) }
    }
}

/// File actions preserve existing destination names and stage copied/generated content before publication.
/// Callers supply readable sources, a writable destination, and any required security-scoped grants.
public enum FileOperations {
    /// Copies or moves a normalized selection and returns its destination URLs.
    /// Duplicate URLs and children of selected folders are processed only once. Each destination item
    /// is published atomically; a later failure or cancellation does not roll back completed batch items.
    /// Folder moves across volumes are rejected; cross-volume file moves copy before removing the original.
    /// This blocks during filesystem work. Run off the main thread; cancellation is checked between stages.
    /// onPublish includes preserved copies; onMove reports only completed moves (including same-parent no-ops).
    public static func copy(_ sources: [URL], to directory: URL, move: Bool,
                            onMove: (FileMove) -> Void = { _ in },
                            onPublish: (URL, URL) -> Void = { _, _ in }) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard !sources.isEmpty, FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ConversionError.invalid("Choose an existing destination folder.")
        }
        let selected = try normalized(sources)
        var outputs: [URL] = []
        for source in selected {
            try Task.checkCancellation()
            let source = source.standardizedFileURL
            let destination = directory.standardizedFileURL
            // A directory cannot be copied into itself, even through a symlink.
            let resolvedSource = source.resolvingSymlinksInPath().path
            let resolvedDestination = destination.resolvingSymlinksInPath().path
            let values = try source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let includesDescendants = values.isDirectory == true && values.isSymbolicLink != true
            if values.isDirectory == true,
               resolvedDestination == resolvedSource || resolvedDestination.hasPrefix(resolvedSource + "/") {
                throw ConversionError.invalid("A folder cannot be placed inside itself.")
            }
            if move {
                if source.deletingLastPathComponent().resolvingSymlinksInPath() == destination.resolvingSymlinksInPath() {
                    outputs.append(source); onPublish(source, source)
                    onMove(FileMove(source: source, destination: source, includesDescendants: includesDescendants))
                    continue
                }
                do {
                    let output = try publish(source, named: source.lastPathComponent, in: destination)
                    outputs.append(output)
                    onPublish(source, output)
                    onMove(FileMove(source: source, destination: output, includesDescendants: includesDescendants))
                    continue
                } catch let error as POSIXError where error.code == .EXDEV {
                    // shortcut: cross-volume folder moves need coordinated recursive verification before deletion.
                    if try source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                        throw ConversionError.unsupported("Moving folders between volumes is not available yet; the originals are unchanged. Use Copy or Finder.")
                    }
                }
            }
            let before = try source.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let scratch = destination.appendingPathComponent(".yuzu-copy-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: scratch) }
            try FileManager.default.copyItem(at: source, to: scratch)
            try Task.checkCancellation()
            let output = try publish(scratch, named: source.lastPathComponent, in: destination)
            outputs.append(output)
            // Report publication before removal: a later failure must still expose the preserved copy.
            onPublish(source, output)
            if move {
                // Publish the complete copy before removing anything from the original location.
                let after = try source.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                guard before.fileSize == after.fileSize, before.contentModificationDate == after.contentModificationDate else {
                    throw ConversionError.failed("The source changed while copying; both copies have been preserved.")
                }
                try FileManager.default.removeItem(at: source)
                // A preserved copy is not a completed move until the original was safely removed.
                onMove(FileMove(source: source, destination: output, includesDescendants: includesDescendants))
            }
        }
        return outputs
    }

    /// Builds one ZIP from staged copies, validates its entries, then returns its atomically published URL.
    /// Originals remain untouched. The destination must be outside selected folders; links, special files,
    /// and conflicting root names are rejected. Existing names receive a short _yuzu suffix without replacing earlier results.
    /// Call off the main thread. Cancellation cleans private staging and stops the compression process.
    public static func compress(_ sources: [URL], in directory: URL,
                                compression: ArchiveCompression = .balanced) throws -> URL {
        try Task.checkCancellation()
        let selected = try normalized(sources)
        var isDirectory: ObjCBool = false
        guard !selected.isEmpty, FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ConversionError.invalid("Choose files and an existing folder for the ZIP archive.")
        }
        // Reject portable-name collisions rather than silently merge trees from different source folders.
        let names = selected.map { $0.lastPathComponent.precomposedStringWithCanonicalMapping.lowercased() }
        guard Set(names).count == names.count else {
            throw ConversionError.invalid("The selected files have matching names. Rename them before creating a single ZIP archive.")
        }
        let destination = directory.resolvingSymlinksInPath()
        for source in selected {
            let values = try source.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                let path = source.resolvingSymlinksInPath().path
                guard destination.path != path, !destination.path.hasPrefix(path + "/") else {
                    throw ConversionError.invalid("A ZIP archive cannot be created inside the folder being compressed.")
                }
            }
            try rejectLinks(source)
        }
        let scratch = try self.scratch(in: directory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let contents = scratch.appendingPathComponent("contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: false)
        _ = try copy(selected, to: contents, move: false)
        // Sources can change while being copied; validate the staged tree as well as the original selection.
        try rejectLinks(contents)
        let output = scratch.appendingPathComponent("result.zip")
        // -y prevents a link introduced during staging from making zip follow another tree.
        _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/zip"), ["-q", "-r", "-y", "-\(compression.level)", output.path, "."], directory: contents)
        _ = try ArchiveReader(output).entries()
        try Task.checkCancellation()
        let name = selected.count == 1 ? selected[0].lastPathComponent + ".zip" : "Archive.zip"
        return try publish(output, named: name, in: directory)
    }

    private static func normalized(_ sources: [URL]) throws -> [URL] {
        var seen = Set<URL>()
        let unique = sources.map(\.standardizedFileURL).filter { seen.insert($0).inserted }
        let parents = try unique.filter { url in
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            return values.isDirectory == true && values.isSymbolicLink != true
        }
        // A selected folder already includes its descendants; moving those URLs again would fail.
        return unique.filter { candidate in !parents.contains { parent in candidate != parent && candidate.path.hasPrefix(parent.path + "/") } }
    }

    private static func rejectLinks(_ source: URL) throws {
        func check(_ url: URL) throws {
            try Task.checkCancellation()
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true, values.isDirectory == true || values.isRegularFile == true else {
                throw ConversionError.invalid("ZIP supports regular files and folders, without links or special files: \(url.lastPathComponent)")
            }
        }
        try check(source)
        guard try source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { return }
        var enumerationError: Error?
        guard let items = FileManager.default.enumerator(at: source, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey], errorHandler: { _, error in enumerationError = error; return false }) else {
            throw ConversionError.failed("Could not read the folder \(source.lastPathComponent).")
        }
        for case let item as URL in items { try check(item) }
        if let enumerationError { throw enumerationError }
    }

    /// Renames a complete staged item to a free name. Staging must be on the destination volume;
    /// EXDEV propagates deliberately so move callers can apply their separate cross-volume policy.
    static func publish(_ staged: URL, named name: String, in directory: URL) throws -> URL {
        let safeName = URL(fileURLWithPath: name).lastPathComponent
        let ext = (safeName as NSString).pathExtension
        let stem = (safeName as NSString).deletingPathExtension
        for index in 1...10_000 {
            try Task.checkCancellation()
            let suffix = index == 2 ? "_yuzu" : "_yuzu_\(index - 1)"
            let candidate = index == 1 ? safeName : stem + suffix + (ext.isEmpty ? "" : "." + ext)
            let destination = directory.appendingPathComponent(candidate)
            // RENAME_EXCL makes the last step atomic and closes the check-then-overwrite race.
            let result = staged.path.withCString { from in
                destination.path.withCString { to in renamex_np(from, to, UInt32(RENAME_EXCL)) }
            }
            if result == 0 { return destination }
            if errno == EEXIST || errno == ENOTEMPTY { continue }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        throw ConversionError.failed("Could not find an available name for \(name).")
    }

    /// Same-volume staging enables atomic publication; owner-only permissions protect unfinished contents.
    static func scratch(in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(".yuzu-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        return url
    }
}
