import AppKit
import Combine

/// Powerbox grants belong to the UI; the converter only receives usable URLs.
@MainActor
final class AccessStore: ObservableObject {
    @Published private(set) var folders: [URL] = []
    private let defaults: UserDefaults
    private let requiresShelfFolderGrant: Bool
    private var bookmarks: [String: Data] {
        get { (defaults.dictionary(forKey: "outputBookmarks") ?? [:]).compactMapValues { $0 as? Data } }
        set {
            defaults.set(newValue, forKey: "outputBookmarks")
            refresh()
        }
    }

    init(defaults: UserDefaults = .standard,
         requiresShelfFolderGrant: Bool = Bundle.main.object(forInfoDictionaryKey: "YuzuSandboxed") as? Bool == true) {
        self.defaults = defaults
        self.requiresShelfFolderGrant = requiresShelfFolderGrant
        refresh()
    }

    func refresh() {
        folders = bookmarks.keys.filter { $0.hasPrefix("/") && !$0.contains("\0") }.sorted()
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    func forgetFolder(_ folder: URL) {
        let path = folder.standardizedFileURL.path
        bookmarks = bookmarks.filter { URL(fileURLWithPath: $0.key).standardizedFileURL.path != path }
    }

    func addFolder() throws {
        let panel = NSOpenPanel()
        panel.title = L10n.text("Folder Access")
        panel.message = L10n.text("Allow saving in this folder and its subfolders. Originals stay in place.")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.text("Allow Access")
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let active = folder.startAccessingSecurityScopedResource()
        defer { if active { folder.stopAccessingSecurityScopedResource() } }
        try remember(folder)
    }

    /// Returns an active grant for the actual output parent; the caller must stop that exact URL.
    func outputFolder(beside source: URL) throws -> URL? {
        try folder(containing: source, title: "Output Folder",
                   message: L10n.text("Allow saving beside “%@”. Yuzu will remember this folder.", source.lastPathComponent))
    }

    func shelfFiles(_ urls: [URL]) throws -> ScopedFiles? {
        guard !urls.isEmpty, urls.allSatisfy(\.isFileURL) else { throw CocoaError(.fileReadUnsupportedScheme) }
        let files = ScopedFiles(urls)
        defer { withExtendedLifetime(files) {} }
        var grants: [URL] = []
        var transferred = false
        defer { if !transferred { grants.forEach { $0.stopAccessingSecurityScopedResource() } } }
        // Readability may borrow another shelf/job's scope; every Sandbox batch needs its own grant.
        for url in urls where requiresShelfFolderGrant || !FileManager.default.isReadableFile(atPath: url.path) {
            if !grants.contains(where: { Self.contains(url, in: $0) }) {
                guard let grant = try folder(containing: url, title: "Shelf Access", message:
                    L10n.text("Allow access to selected files in “%@”. Yuzu will remember this folder.",
                              url.deletingLastPathComponent().lastPathComponent)) else { return nil }
                grants.append(grant)
            }
            guard FileManager.default.isReadableFile(atPath: url.path) else { throw CocoaError(.fileReadNoPermission) }
        }
        let authorized = ScopedFiles(urls, activeGrants: grants)
        transferred = true
        return authorized
    }

    private func folder(containing source: URL, title: String, message: String) throws -> URL? {
        guard source.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        let parent = source.deletingLastPathComponent().standardizedFileURL
        for key in bookmarks.keys.sorted(by: { $0.count > $1.count }) {
            guard let data = bookmarks[key] else { continue }
            var stale = false
            guard let folder = try? URL(resolvingBookmarkData: data,
                                       options: [.withSecurityScope, .withoutUI, .withoutMounting],
                                       relativeTo: nil, bookmarkDataIsStale: &stale),
                  folder.startAccessingSecurityScopedResource() else { continue }
            var transfersGrant = false
            defer { if !transfersGrant { folder.stopAccessingSecurityScopedResource() } }
            guard Self.contains(source, in: folder),
                  (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            if stale { try remember(folder, replacing: key) }
            if Self.isParent(folder, of: source) {
                transfersGrant = true
                return folder
            }
            // A child bookmark transfers its own scope, rather than leaking the ancestor's grant.
            let childData = try parent.bookmarkData(options: [.withSecurityScope],
                                                   includingResourceValuesForKeys: nil, relativeTo: nil)
            var childStale = false
            let child = try URL(resolvingBookmarkData: childData,
                                options: [.withSecurityScope, .withoutUI, .withoutMounting],
                                relativeTo: nil, bookmarkDataIsStale: &childStale)
            guard Self.isParent(child, of: source), child.startAccessingSecurityScopedResource() else {
                throw CocoaError(.fileWriteNoPermission)
            }
            return child
        }

        // Identifying a source does not grant Sandbox read/write access to its parent folder.
        let panel = NSOpenPanel()
        panel.title = L10n.text(title)
        panel.message = message
        panel.directoryURL = parent
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.text("Allow Access")
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard Self.isParent(url, of: source) else {
            throw AccessError.wrongFolder(parent.lastPathComponent)
        }
        _ = url.startAccessingSecurityScopedResource()
        do { try remember(url) }
        catch { url.stopAccessingSecurityScopedResource(); throw error }
        return url
    }

    nonisolated static func isParent(_ directory: URL, of source: URL) -> Bool {
        directory.isFileURL && source.isFileURL && directory.standardizedFileURL.resolvingSymlinksInPath() ==
        source.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath()
    }

    nonisolated static func contains(_ source: URL, in directory: URL) -> Bool {
        guard directory.isFileURL, source.isFileURL else { return false }
        let root = directory.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let parent = source.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath().pathComponents
        // Components reject sibling prefixes; resolving both sides rejects a symlink escaping the grant.
        return parent.count >= root.count && Array(parent.prefix(root.count)) == root
    }

    /// Move destinations are chosen explicitly; ownership of the returned grant transfers to the job.
    func chooseDestination() throws -> URL? {
        let panel = NSOpenPanel()
        panel.title = L10n.text("Move to Folder")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.text("Move Here")
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    private func remember(_ url: URL, replacing previous: String? = nil) throws {
        let data = try url.bookmarkData(options: [.withSecurityScope],
                                        includingResourceValuesForKeys: nil, relativeTo: nil)
        var updated = bookmarks
        if let previous { updated.removeValue(forKey: previous) }
        updated[url.standardizedFileURL.path] = data
        bookmarks = updated
    }
}

private enum AccessError: LocalizedError {
    case wrongFolder(String)
    var errorDescription: String? {
        if case .wrongFolder(let name) = self {
            return L10n.text("Choose “%@” to allow access to the selected files.", name)
        }
        return nil
    }
}
