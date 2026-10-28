import AppKit
import Combine
import Sparkle
import YuzuCore

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
    private var detection: Task<Void, Never>?
    private var detectionID = UUID()
    private var jobs: [PendingJob] = []
    private var currentJob: Task<Void, Never>?
    private var terminating = false
    private var installingUpdate = false
    private let progress = JobProgress()

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
            let files = ScopedFiles(urls)
            // Finish AppKit's drop before opening Powerbox or a system sharing window.
            DispatchQueue.main.async { self?.handleDrop(files, option: option) }
        }
        actions.onMove = { [weak self] files, folder in
            guard let self else { folder.stopAccessingSecurityScopedResource(); return }
            self.enqueue(PendingJob(files: files, kind: .move, destinations: [folder]))
        }
        actions.onCompress = { [weak self] files, folder in
            guard let self else { folder.stopAccessingSecurityScopedResource(); return }
            self.enqueue(PendingJob(files: files, kind: .compress, destinations: [folder],
                                    options: self.settings.options(for: .zip)))
        }
        progress.onCancel = { [weak self] in self?.currentJob?.cancel() }
        updater.canRestart = { [weak self] in self?.currentJob == nil && self?.jobs.isEmpty != false }
        updater.onWillRestart = { [weak self] in
            self?.installingUpdate = true
            self?.monitor.stop()
        }
        updater.onUpdateCycleFinished = { [weak self] in
            guard let self, installingUpdate, !terminating else { return }
            installingUpdate = false
            monitor.start()
        }
        updater.start()
        monitor.start()
    }

    private func updateTooltip() {
        statusItem?.button?.toolTip = "Yuzu Converter\n\(settings.shortcutDescription)\n\(L10n.text("Drag a file · Escape to cancel"))"
    }

    private func refreshLanguage() {
        statusItem?.menu?.item(at: 0)?.title = L10n.text("Show Shelf")
        statusItem?.menu?.item(at: 1)?.title = L10n.text("Settings…")
        statusItem?.menu?.item(at: 2)?.title = L10n.text("Check for Updates…")
        statusItem?.menu?.item(at: 3)?.title = L10n.text("Quit")
        updateTooltip()
        settings.refreshLanguage()
        monitor.refreshLanguage()
        actions.refreshLanguage()
        progress.refreshLanguage()
    }
    @objc private func showShelf() { actions.showShelf() }
    @objc private func showSettings() { settings.show(updater: updater, access: access) }
    @objc private func quit() { NSApp.terminate(nil) }

    private func updateSources(_ urls: [URL], view: WheelDragView) {
        // Cancellation is cooperative, so the generation ID also rejects late results from an old wheel.
        detection?.cancel()
        let identifier = UUID()
        detectionID = identifier
        view.sourceCaption = urls.count == 1 ? urls[0].lastPathComponent : L10n.text("%ld files", urls.count)
        if view.mode == .actions {
            view.options = FileAction.allCases.map(WheelOption.action)
            view.idleCaption = L10n.text("Actions")
            return
        }
        view.options = []
        view.idleCaption = L10n.text("Reading file…")
        let engine = engine
        detection = Task { [weak self, weak view] in
            let worker = Task.detached(priority: .userInitiated) { () throws -> (targets: [FileFormat], source: FileFormat?) in
                let sources = try urls.map { try SourceFile(url: $0) }
                try Task.checkCancellation()
                let format = sources.first?.format
                return (engine.targets(for: sources), sources.allSatisfy { $0.format == format } ? format : nil)
            }
            do {
                let result = try await withTaskCancellationHandler(operation: { try await worker.value },
                                                                    onCancel: { worker.cancel() })
                guard !Task.isCancelled, self?.detectionID == identifier, let view else { return }
                view.options = result.targets.map(WheelOption.conversion)
                if let format = result.source { view.sourceCaption = format.label }
                view.idleCaption = L10n.text(result.targets.isEmpty ? "No available formats" : "Convert")
            } catch {
                guard !Task.isCancelled, self?.detectionID == identifier else { return }
                view?.options = []
                view?.idleCaption = L10n.text("Unsupported format")
            }
        }
    }

    /// The drop has finished and its source grants are retained before any modal dialog is opened.
    private func handleDrop(_ files: ScopedFiles, option: WheelOption) {
        guard !terminating, !installingUpdate else { return }
        detection?.cancel()
        let urls = files.urls
        switch option {
        case .action(let action): actions.perform(action, files: files)
        case .conversion(let target):
            NSApp.activate(ignoringOtherApps: true)
            var folders: [URL] = []
            var enqueued = false
            defer { if !enqueued { folders.forEach { $0.stopAccessingSecurityScopedResource() } } }
            do {
                for url in urls {
                    guard let folder = try access.outputFolder(beside: url) else { return }
                    folders.append(folder)
                }
                // Snapshot output defaults before queueing; later edits belong to future jobs.
                enqueue(PendingJob(files: files, kind: .conversion(target), destinations: folders,
                                   options: settings.options(for: target)))
                enqueued = true
            } catch { ActionController.show(error) }
        }
    }

    private func enqueue(_ job: PendingJob) {
        guard !terminating, !installingUpdate else {
            job.destinations.forEach { $0.stopAccessingSecurityScopedResource() }
            return
        }
        jobs.append(job)
        startNextJob()
    }

    private func startNextJob() {
        // Keep each batch ordered. Earlier published results survive a later item's error or cancellation.
        guard !terminating, currentJob == nil, !jobs.isEmpty else { return }
        let job = jobs.removeFirst()
        let kind = job.kind
        progress.show(title: { kind.title })
        let engine = engine
        currentJob = Task {
            let worker = Task.detached(priority: .userInitiated) { () throws -> Int in
                switch job.kind {
                case .conversion(let target):
                    var count = 0
                    for (i, url) in job.files.urls.enumerated() {
                        try Task.checkCancellation()
                        let source = try SourceFile(url: url)
                        count += try await engine.convert(source, to: target, in: job.destinations[i], options: job.options).count
                    }
                    return count
                case .move:
                    return try FileOperations.copy(job.files.urls, to: job.destinations[0], move: true).count
                case .compress:
                    _ = try FileOperations.compress(job.files.urls, in: job.destinations[0], compression: job.options.compression)
                    return 1
                }
            }
            do {
                let count = try await withTaskCancellationHandler(operation: { try await worker.value },
                                                                  onCancel: { worker.cancel() })
                progress.finish("Completed: %ld", count)
            } catch is CancellationError {
                progress.finish("Cancelled")
            } catch {
                progress.finish("Could not complete")
                if !terminating { ActionController.show(error) }
            }
            job.destinations.forEach { $0.stopAccessingSecurityScopedResource() }
            currentJob = nil
            if !terminating { startNextJob() }
            updater.resumeInstallationIfReady()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        terminating = true
        monitor.stop()
        let detecting = detection
        detecting?.cancel()
        jobs.forEach { $0.destinations.forEach { $0.stopAccessingSecurityScopedResource() } }
        jobs.removeAll()
        let processing = currentJob
        guard processing != nil || detecting != nil else { return .terminateNow }
        // Let the worker stop its subprocess and remove staged files before AppKit exits.
        processing?.cancel()
        Task {
            await processing?.value
            await detecting?.value
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

private struct PendingJob: Sendable {
    let files: ScopedFiles
    let kind: JobKind
    let destinations: [URL]
    var options = ConversionOptions()
}

private enum JobKind: Sendable {
    case conversion(FileFormat), move, compress
    var title: String {
        switch self {
        case .conversion(let format): return L10n.text("Converting to %@", format.label)
        case .move: return L10n.text("Moving files")
        case .compress: return L10n.text("Compressing to ZIP")
        }
    }
}

@MainActor
private final class JobProgress {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private let cancel = NSButton(title: L10n.text("Cancel"), target: nil, action: nil)
    private var closeTimer: Timer?
    // Store how to render the message so changing language does not restart or lose the active job.
    private var titleSource: () -> String = { "" }
    var onCancel: (() -> Void)?

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 330, height: 86),
                        styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Yuzu Converter"
        panel.level = .floating
        label.frame = NSRect(x: 16, y: 48, width: 298, height: 22)
        cancel.frame = NSRect(x: 210, y: 10, width: 104, height: 28)
        cancel.target = self
        cancel.action = #selector(cancelJob)
        panel.contentView?.addSubview(label)
        panel.contentView?.addSubview(cancel)
        panel.center()
    }
    func show(title: @escaping () -> String) {
        closeTimer?.invalidate()
        titleSource = title
        refreshLanguage()
        cancel.isHidden = false
        panel.orderFrontRegardless()
    }
    func finish(_ key: String, _ arguments: CVarArg...) {
        titleSource = { L10n.string(key, language: L10n.language, arguments: arguments) }
        refreshLanguage()
        cancel.isHidden = true
        closeTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.panel.orderOut(nil) }
        }
    }
    func refreshLanguage() {
        label.stringValue = titleSource()
        cancel.title = L10n.text("Cancel")
    }
    @objc private func cancelJob() { onCancel?() }
}
