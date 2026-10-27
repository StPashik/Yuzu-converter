import AppKit

/// Powerbox grants belong to the UI; the converter only receives usable URLs.
@MainActor
final class AccessStore {
    private var bookmarks: [String: Data] {
        get { UserDefaults.standard.dictionary(forKey: "outputBookmarks") as? [String: Data] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "outputBookmarks") }
    }

    /// Returns an active folder grant, or nil when the user cancels. The caller must stop the scope.
    func outputFolder(beside source: URL) throws -> URL? {
        let parent = source.deletingLastPathComponent().standardizedFileURL
        if let data = bookmarks[parent.path] {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope],
                                  relativeTo: nil, bookmarkDataIsStale: &stale),
               url.startAccessingSecurityScopedResource() {
                if Self.isParent(url, of: source) {
                    do { if stale { try remember(url, for: parent.path) } }
                    catch { url.stopAccessingSecurityScopedResource(); throw error }
                    return url
                }
                url.stopAccessingSecurityScopedResource()
            }
        }

        // A file drop does not grant Sandbox write access to its parent folder.
        let panel = NSOpenPanel()
        panel.title = L10n.text("Output Folder")
        panel.message = L10n.text("Allow saving beside “%@”. Yuzu will remember this folder.", source.lastPathComponent)
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
        do { try remember(url, for: parent.path) }
        catch { url.stopAccessingSecurityScopedResource(); throw error }
        return url
    }

    nonisolated static func isParent(_ directory: URL, of source: URL) -> Bool {
        directory.standardizedFileURL.resolvingSymlinksInPath() ==
        source.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath()
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

    private func remember(_ url: URL, for path: String) throws {
        let data = try url.bookmarkData(options: [.withSecurityScope],
                                        includingResourceValuesForKeys: nil, relativeTo: nil)
        var updated = bookmarks
        updated[path] = data
        bookmarks = updated
    }
}

private enum AccessError: LocalizedError {
    case wrongFolder(String)
    var errorDescription: String? {
        if case .wrongFolder(let name) = self {
            return L10n.text("Choose “%@”. Converted files are saved beside the original.", name)
        }
        return nil
    }
}
