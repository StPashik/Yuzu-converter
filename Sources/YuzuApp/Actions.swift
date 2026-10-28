import AppKit
import YuzuCore

// URLs and their grants are immutable; Foundation permits balancing scopes on another thread.
final class ScopedFiles: @unchecked Sendable {
    let urls: [URL]
    private let granted: [URL]

    init(_ urls: [URL]) {
        self.urls = urls
        granted = urls.filter { $0.startAccessingSecurityScopedResource() }
    }
    deinit { granted.forEach { $0.stopAccessingSecurityScopedResource() } }
}

@MainActor
/// System services stay on the main actor; only long-running file operations are sent to the job queue.
final class ActionController: NSObject, NSSharingServiceDelegate {
    private let access: AccessStore
    private let settings: Settings
    private var sharing: NSSharingService?
    private var sharedFiles: ScopedFiles?
    private var clipboardFiles: ScopedFiles?
    private var clipboardTimer: Timer?
    private var shelves: [ShelfController] = []
    var onMove: ((ScopedFiles, URL) -> Void)?
    var onCompress: ((ScopedFiles, URL) -> Void)?
    var shelfAnchor: (() -> NSView?)?

    init(access: AccessStore, settings: Settings) {
        self.access = access
        self.settings = settings
    }

    func refreshLanguage() { shelves.forEach { $0.refreshLanguage() } }

    func showShelf() {
        shelves.removeAll { $0.window?.isVisible != true }
        present(shelves.last ?? makeShelf())
    }

    private func makeShelf() -> ShelfController {
        let shelf = ShelfController()
        shelves.append(shelf)
        return shelf
    }

    private func present(_ shelf: ShelfController) {
        let index = shelves.firstIndex { $0 === shelf } ?? 0
        shelf.present(relativeTo: shelfAnchor?(), offset: CGFloat(min(index, 4)) * 18)
    }

    func perform(_ action: FileAction, files: ScopedFiles) {
        do {
            switch action {
            case .copy:
                NSPasteboard.general.clearContents()
                guard NSPasteboard.general.writeObjects(files.urls as [NSURL]) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                retainClipboardFiles(files)
            case .copyPath:
                NSPasteboard.general.clearContents()
                guard NSPasteboard.general.setString(files.urls.map(\.path).joined(separator: "\n"),
                                                      forType: .string) else { throw CocoaError(.fileWriteUnknown) }
            case .move:
                NSApp.activate(ignoringOtherApps: true)
                if let folder = try access.chooseDestination() { onMove?(files, folder) }
            case .compress:
                NSApp.activate(ignoringOtherApps: true)
                if let first = files.urls.first, let folder = try access.outputFolder(beside: first) {
                    onCompress?(files, folder)
                }
            case .airDrop:
                guard sharing == nil else { throw ActionError.sharingInProgress }
                guard let service = NSSharingService(named: .sendViaAirDrop),
                      service.canPerform(withItems: files.urls) else { throw ActionError.airDropUnavailable }
                // Keep the file grants alive until AppKit completes or fails the share.
                sharing = service
                sharedFiles = files
                service.delegate = self
                service.perform(withItems: files.urls)
            case .openTerminal:
                let application = settings.terminalApplication
                guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: application.bundleIdentifier)
                else { throw ActionError.terminalUnavailable(application.name) }
                Task {
                    do {
                        let folders = try await Task.detached { try Self.terminalFolders(files.urls) }.value
                        let config = NSWorkspace.OpenConfiguration()
                        NSWorkspace.shared.open(folders, withApplicationAt: terminal,
                                                configuration: config) { _, error in
                            if let error { Task { @MainActor in Self.show(error) } }
                            _ = files
                        }
                    } catch { Self.show(error) }
                }
            case .float:
                shelves.removeAll { $0.window?.isVisible != true }
                let shelf: ShelfController
                if settings.addToShelf, let existing = shelves.last { shelf = existing }
                else { shelf = makeShelf() }
                shelf.add(files)
                present(shelf)
            }
        } catch { Self.show(error) }
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) { finishSharing() }
    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        finishSharing()
        Self.show(error)
    }
    private func finishSharing() { sharing?.delegate = nil; sharing = nil; sharedFiles = nil }

    private func retainClipboardFiles(_ files: ScopedFiles) {
        clipboardFiles = files
        clipboardTimer?.invalidate()
        let changeCount = NSPasteboard.general.changeCount
        // A later paste may still need the original Sandbox file grants.
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                if NSPasteboard.general.changeCount != changeCount {
                    self?.clipboardFiles = nil
                    self?.clipboardTimer = nil
                    timer.invalidate()
                }
            }
        }
    }

    nonisolated static func terminalFolders(_ urls: [URL]) throws -> [URL] {
        var folders: [URL] = []
        for url in urls {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            let folder = (values.isDirectory == true && values.isPackage != true
                          ? url : url.deletingLastPathComponent()).standardizedFileURL
            if !folders.contains(where: { $0.path == folder.path }) { folders.append(folder) }
        }
        return folders
    }

    static func show(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(error: error)
        alert.messageText = L10n.text("Could not complete the operation")
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}

private enum ActionError: LocalizedError {
    case airDropUnavailable, sharingInProgress, terminalUnavailable(String)
    var errorDescription: String? {
        switch self {
        case .airDropUnavailable: return L10n.text("AirDrop is not available for these files on this Mac.")
        case .sharingInProgress: return L10n.text("Wait for the current AirDrop transfer to finish.")
        case .terminalUnavailable(let name):
            return L10n.text("%@ could not be found. Choose another terminal app in Settings.", name)
        }
    }
}
