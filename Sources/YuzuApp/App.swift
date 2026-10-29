import AppKit
import Combine
import Sparkle
import YuzuCore
import UniformTypeIdentifiers

@main
enum YuzuMain {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--version") {
            print(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")
            return
        }
        if CommandLine.arguments.contains("--self-check") {
            Task.detached {
                do { try await AppSelfCheck.run(); print("Sandbox self-check passed"); exit(0) }
                catch { fputs("Self-check: \(error as NSError)\n", stderr); exit(1) }
            }
            dispatchMain()
        }
        // Seed this app's language before AppKit caches text for standard dialogs.
        UserDefaults.standard.set([L10n.language.rawValue], forKey: "AppleLanguages")
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
/// Coordinates UI, grants, and a serial job queue; Core work always runs on a background task.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private let updater = AppUpdater()
    private let access = AccessStore()
    private lazy var monitor = WheelMonitor(settings: settings)
    private lazy var actions = ActionController(access: access, settings: settings)
    private let engine = ConversionEngine()
    private var statusItem: NSStatusItem?
    private var settingsSubscription: AnyCancellable?
    private var shortcutActivationObserver: NSObjectProtocol?
    private var shelfSelection: Task<Void, Never>?
    private var detection: Task<Void, Never>?
    private var detectionID = UUID()
    private var detectedImages: [URL] = []
    private let queue = JobQueue()
    private var queueWindow: QueueWindowController?
    private var preparingRequests = 0
    private var terminating = false
    private var installingUpdate = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let iconURL = Bundle.main.url(forResource: "YuzuMenuBar", withExtension: "pdf")
            ?? Bundle.module.url(forResource: "YuzuMenuBar", withExtension: "pdf")
        item.button?.image = iconURL.flatMap { NSImage(contentsOf: $0) }
        item.button?.image?.size = NSSize(width: 18, height: 18)
        item.button?.setAccessibilityLabel("Yuzu Converter")
        item.button?.image?.isTemplate = true
        let menu = NSMenu()
        menu.addItem(withTitle: L10n.text("Show Shelf"), action: #selector(showShelf), keyEquivalent: "").target = self
        menu.addItem(withTitle: L10n.text("Show Operations"), action: #selector(showQueue), keyEquivalent: "").target = self
        menu.addItem(withTitle: L10n.text("Settings…"), action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: L10n.text("Check for Updates…"),
                     action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "").target = updater.controller
        menu.addItem(withTitle: L10n.text("Quit"), action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
        statusItem = item
        actions.shelfAnchor = { [weak self] in self?.statusItem?.button }
        settingsSubscription = settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refreshLanguage() }
        }
        updateTooltip()
        monitor.onSources = { [weak self] urls, view in self?.updateSources(urls, view: view) }
        monitor.onDrop = { [weak self] urls, option in
            guard let self else { return }
            let files = self.actions.scopedFiles(urls)
            // Finish AppKit's drop before opening Powerbox or a system sharing window.
            DispatchQueue.main.async { [weak self] in self?.handleRequest(files, option: option) }
        }
        monitor.onImageDrop = { [weak self] image, option in
            DispatchQueue.main.async { self?.saveImageDrop(image, option: option) }
        }
        actions.onMove = { [weak self] files, folder in
            guard let self else { folder.stopAccessingSecurityScopedResource(); return }
            self.enqueue(JobRequest(files: files, kind: .move, destinations: [folder]))
        }
        actions.onCompress = { [weak self] files, folder in
            guard let self else { folder.stopAccessingSecurityScopedResource(); return }
            self.enqueue(JobRequest(files: files, kind: .compress, destinations: [folder],
                                    options: self.settings.options(for: .zip)))
        }
        queue.onIdle = { [weak self] in self?.updater.resumeInstallationIfReady() }
        queue.onFilesMoved = { [weak self] moves, access in self?.actions.filesMoved(moves, access: access) }
        updater.canRestart = { [weak self] in
            self?.queue.isIdle != false && self?.preparingRequests == 0 && self?.shelfSelection == nil
        }
        updater.onWillRestart = { [weak self] in
            self?.installingUpdate = true
            self?.queue.allowsRetry = false
            self?.monitor.stop()
            self?.refreshShelfShortcut()
        }
        updater.onUpdateCycleFinished = { [weak self] in
            guard let self, installingUpdate, !terminating else { return }
            installingUpdate = false
            queue.allowsRetry = true
            monitor.start()
            refreshShelfShortcut()
        }
        updater.start()
        monitor.start()
        settings.shelfShortcut.onInvoke = { [weak self] in self?.addFinderSelectionToShelf() }
        shortcutActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.refreshShelfShortcut() } }
        refreshShelfShortcut()
    }

    private func refreshShelfShortcut() {
        // Release the chord outside Finder so the same keys keep working normally in other apps.
        settings.shelfShortcut.setEnabled(!terminating && !installingUpdate &&
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder")
    }

    private func addFinderSelectionToShelf() {
        guard !terminating, !installingUpdate, shelfSelection == nil,
              NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else { return }
        shelfSelection = Task { [weak self] in
            guard let self else { return }
            defer { shelfSelection = nil; updater.resumeInstallationIfReady() }
            do {
                let urls = try await Task.detached(priority: .userInitiated) { try FinderSelection.read() }.value
                guard !terminating, !installingUpdate else { return }
                NSApp.activate(ignoringOtherApps: true)
                if let files = try access.shelfFiles(urls) { actions.perform(.float, files: files) }
            } catch {
                if !terminating && !installingUpdate { ActionController.show(error) }
            }
        }
    }

    private func updateTooltip() {
        statusItem?.button?.toolTip = "Yuzu Converter\n\(settings.shortcutDescription)\n\(L10n.text("Drag a file · Escape to cancel"))"
    }

    private func refreshLanguage() {
        statusItem?.menu?.item(at: 0)?.title = L10n.text("Show Shelf")
        statusItem?.menu?.item(at: 1)?.title = L10n.text("Show Operations")
        statusItem?.menu?.item(at: 2)?.title = L10n.text("Settings…")
        statusItem?.menu?.item(at: 3)?.title = L10n.text("Check for Updates…")
        statusItem?.menu?.item(at: 4)?.title = L10n.text("Quit")
        updateTooltip()
        settings.refreshLanguage()
        monitor.refreshLanguage()
        actions.refreshLanguage()
        queueWindow?.refreshLanguage()
    }
    @objc private func showShelf() { actions.showShelf() }
    @objc private func showQueue() {
        NSApp.activate(ignoringOtherApps: true)
        presentQueue()
    }
    private func presentQueue() {
        if queueWindow == nil { queueWindow = QueueWindowController(queue: queue) }
        queueWindow?.present()
    }
    @objc private func showSettings() { settings.show(updater: updater, access: access) }
    @objc private func quit() { NSApp.terminate(nil) }

    private func updateSources(_ urls: [URL], view: WheelDragView) {
        // Cancellation is cooperative, so the generation ID also rejects late results from an old wheel.
        detection?.cancel()
        let identifier = UUID()
        detectionID = identifier
        detectedImages = []
        view.sourceCaption = urls.count == 1 ? urls[0].lastPathComponent : L10n.text("%ld files", urls.count)
        if view.mode == .actions {
            view.options = FileAction.allCases.map(WheelOption.action)
            view.idleCaption = L10n.text("Actions")
            view.isReadingSources = false
            return
        }
        view.isReadingSources = true
        view.options = []
        view.idleCaption = L10n.text("Reading file…")
        let engine = engine
        let files = actions.scopedFiles(urls)
        detection = Task { [weak self, weak view] in
            let worker = Task.detached(priority: .userInitiated) { () throws -> (targets: [FileFormat], source: FileFormat?, images: Bool) in
                defer { withExtendedLifetime(files) {} }
                let sources = try files.urls.map { try SourceFile(url: $0) }
                try Task.checkCancellation()
                let format = sources.first?.format
                return (engine.targets(for: sources), sources.allSatisfy { $0.format == format } ? format : nil, sources.allSatisfy { $0.format.category == "Images" })
            }
            do {
                let result = try await withTaskCancellationHandler(operation: { try await worker.value },
                                                                    onCancel: { worker.cancel() })
                guard !Task.isCancelled, self?.detectionID == identifier, let view,
                      view.confirmed, view.mode == .conversion, view.imageDrop == nil, view.sources == urls else { return }
                self?.detectedImages = result.images ? urls : []
                view.options = result.targets.map(WheelOption.conversion)
                if let format = result.source { view.sourceCaption = format.label }
                view.idleCaption = L10n.text(result.targets.isEmpty ? "No available formats" : "Convert")
                view.isReadingSources = false
            } catch {
                guard !Task.isCancelled, self?.detectionID == identifier, let view,
                      view.confirmed, view.mode == .conversion, view.imageDrop == nil, view.sources == urls else { return }
                view.options = []
                view.idleCaption = L10n.text("Unsupported format")
                view.isReadingSources = false
            }
        }
    }

    private func saveImageDrop(_ image: ImageDrop, option: WheelOption) {
        guard !terminating, !installingUpdate, case .conversion(let target) = option else { return }
        preparingRequests += 1
        defer { preparingRequests -= 1; updater.resumeInstallationIfReady() }
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSSavePanel()
        let validation = ImageSaveDelegate()
        panel.delegate = validation
        panel.title = L10n.text("Save Converted Image")
        panel.message = L10n.text("Choose where to save the converted image.")
        let stem = (image.name as NSString).deletingPathExtension
        panel.nameFieldStringValue = String(stem.prefix(120)) + "." + target.fileExtension
        if let type = UTType(filenameExtension: target.fileExtension) { panel.allowedContentTypes = [type] }
        guard panel.runModal() == .OK, let destination = panel.url else { image.cancelPreparation(); return }
        _ = destination.startAccessingSecurityScopedResource()
        enqueue(JobRequest(files: ScopedFiles([]), kind: .importedImage(image, target), destinations: [destination],
                           options: settings.options(for: target)))
        withExtendedLifetime(validation) {}
    }

    /// Every entry point snapshots source grants before opening Powerbox or sharing UI.
    private func handleRequest(_ files: ScopedFiles, option: WheelOption) {
        guard !terminating, !installingUpdate else { return }
        preparingRequests += 1
        // Modal panels can reenter the run loop; an updater restart must wait for preparation too.
        defer { preparingRequests -= 1; updater.resumeInstallationIfReady() }
        detection?.cancel()
        let urls = files.urls
        switch option {
        case .action(let action):
            actions.perform(action, files: files)
        case .conversion(let target):
            NSApp.activate(ignoringOtherApps: true)
            var folders: [URL] = []
            var enqueued = false
            defer { if !enqueued { folders.forEach { $0.stopAccessingSecurityScopedResource() } } }
            do {
                // A combined image PDF needs one output grant beside the first input.
                let combinesImages = target == .pdf && urls.count > 1 && urls == detectedImages
                for url in combinesImages ? [urls[0]] : urls {
                    guard let folder = try access.outputFolder(beside: url) else { return }
                    folders.append(folder)
                }
                // Snapshot output defaults before queueing; later edits belong to future jobs.
                enqueue(JobRequest(files: files, kind: .conversion(target), destinations: folders,
                                   options: settings.options(for: target)))
                enqueued = true
            } catch { ActionController.show(error) }
        }
    }

    private func enqueue(_ job: JobRequest) {
        guard !terminating, !installingUpdate else { return }
        queue.enqueue(job)
        presentQueue()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        terminating = true
        queue.allowsRetry = false
        monitor.stop()
        refreshShelfShortcut()
        let detecting = detection
        detecting?.cancel()
        queue.cancelAll()
        guard !queue.isIdle || detecting != nil else { return .terminateNow }
        // Let the worker stop its subprocess and remove staged files before AppKit exits.
        Task {
            await queue.waitForCurrentJob()
            await detecting?.value
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
