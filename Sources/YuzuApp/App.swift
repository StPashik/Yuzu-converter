import AppKit
import Combine
import YuzuCore

@main
enum YuzuMain {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--version") { print("0.1.0"); return }
        if CommandLine.arguments.contains("--self-check") {
            Task.detached {
                do { try await AppSelfCheck.run(); print("Sandbox self-check passed"); exit(0) }
                catch { fputs("Self-check: \(error.localizedDescription)\n", stderr); exit(1) }
            }
            dispatchMain()
        }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
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
        menu.addItem(withTitle: "Настройки…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Выйти", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
        statusItem = item
        settingsSubscription = settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateTooltip() }
        }
        updateTooltip()
        monitor.onSources = { [weak self] urls, view in self?.updateSources(urls, view: view) }
        monitor.onDrop = { [weak self] urls, option in
            let files = ScopedFiles(urls)
            // Finish AppKit's drop before opening Powerbox or a system sharing window.
            DispatchQueue.main.async { self?.handleDrop(files, option: option) }
        }
        actions.onMove = { [weak self] files, folder in
            self?.enqueue(PendingJob(files: files, kind: .move, destinations: [folder]))
        }
        actions.onCompress = { [weak self] files, folder in
            self?.enqueue(PendingJob(files: files, kind: .compress, destinations: [folder]))
        }
        progress.onCancel = { [weak self] in self?.currentJob?.cancel() }
        monitor.start()
    }

    private func updateTooltip() {
        statusItem?.button?.toolTip = "Yuzu Converter\n\(settings.shortcutDescription)\nПеретаскивайте файл · Escape — отмена"
    }
    @objc private func showSettings() { settings.show() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func updateSources(_ urls: [URL], view: WheelDragView) {
        detection?.cancel()
        let identifier = UUID()
        detectionID = identifier
        if view.mode == .actions {
            view.options = FileAction.allCases.map(WheelOption.action)
            view.idleCaption = urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) файлов"
            return
        }
        view.options = []
        view.idleCaption = "Определяю формат…"
        let engine = engine
        detection = Task { [weak self, weak view] in
            let worker = Task.detached(priority: .userInitiated) { () throws -> [FileFormat] in
                let sources = try urls.map { try SourceFile(url: $0) }
                try Task.checkCancellation()
                return engine.targets(for: sources)
            }
            do {
                let targets = try await withTaskCancellationHandler(operation: { try await worker.value },
                                                                    onCancel: { worker.cancel() })
                guard !Task.isCancelled, self?.detectionID == identifier, let view else { return }
                view.options = targets.map(WheelOption.conversion)
                view.idleCaption = targets.isEmpty ? "Нет доступных целей" : "Конвертация"
            } catch {
                guard !Task.isCancelled, self?.detectionID == identifier else { return }
                view?.options = []
                view?.idleCaption = "Формат недоступен"
            }
        }
    }

    private func handleDrop(_ files: ScopedFiles, option: WheelOption) {
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
                enqueue(PendingJob(files: files, kind: .conversion(target), destinations: folders))
                enqueued = true
            } catch { ActionController.show(error) }
        }
    }

    private func enqueue(_ job: PendingJob) { jobs.append(job); startNextJob() }

    private func startNextJob() {
        guard !terminating, currentJob == nil, !jobs.isEmpty else { return }
        let job = jobs.removeFirst()
        progress.show(title: job.kind.title)
        let engine = engine
        currentJob = Task {
            let worker = Task.detached(priority: .userInitiated) { () throws -> Int in
                switch job.kind {
                case .conversion(let target):
                    var count = 0
                    for (i, url) in job.files.urls.enumerated() {
                        try Task.checkCancellation()
                        let source = try SourceFile(url: url)
                        count += try await engine.convert(source, to: target, in: job.destinations[i]).count
                    }
                    return count
                case .move:
                    return try FileOperations.copy(job.files.urls, to: job.destinations[0], move: true).count
                case .compress:
                    _ = try FileOperations.compress(job.files.urls, in: job.destinations[0])
                    return 1
                }
            }
            do {
                let count = try await withTaskCancellationHandler(operation: { try await worker.value },
                                                                  onCancel: { worker.cancel() })
                progress.finish("Готово: \(count)")
            } catch is CancellationError {
                progress.finish("Отменено")
            } catch {
                progress.finish("Не удалось завершить")
                if !terminating { ActionController.show(error) }
            }
            job.destinations.forEach { $0.stopAccessingSecurityScopedResource() }
            currentJob = nil
            if !terminating { startNextJob() }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        terminating = true
        monitor.dismiss()
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
}

private enum JobKind: Sendable {
    case conversion(FileFormat), move, compress
    var title: String {
        switch self {
        case .conversion(let format): return "Конвертация в \(format.label)"
        case .move: return "Перемещение файлов"
        case .compress: return "Сжатие в ZIP"
        }
    }
}

@MainActor
private final class JobProgress {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private let cancel = NSButton(title: "Отменить", target: nil, action: nil)
    private var closeTimer: Timer?
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
    func show(title: String) {
        closeTimer?.invalidate()
        label.stringValue = title
        cancel.isHidden = false
        panel.orderFrontRegardless()
    }
    func finish(_ text: String) {
        label.stringValue = text
        cancel.isHidden = true
        closeTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.panel.orderOut(nil) }
        }
    }
    @objc private func cancelJob() { onCancel?() }
}
