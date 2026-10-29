import AppKit
import Combine
import SwiftUI

@MainActor
final class QueueWindowController: NSWindowController {
    private let queue: JobQueue
    private let hosting: NSHostingView<QueueView>
    private var subscription: AnyCancellable?
    private var hadEntries = false

    static func contentSize(entryCount: Int) -> NSSize {
        NSSize(width: 480, height: entryCount == 0 ? 200 : 104 + CGFloat(min(entryCount, 3)) * 116)
    }

    init(queue: JobQueue) {
        self.queue = queue
        hosting = NSHostingView(rootView: QueueView(queue: queue, language: L10n.language, onClose: {}))
        // Let the panel constrain the scrollable history instead of adopting the host’s intrinsic height.
        hosting.sizingOptions = []
        let panel = QueuePanel(contentRect: NSRect(origin: .zero, size: Self.contentSize(entryCount: queue.entries.count)),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .normal
        panel.isFloatingPanel = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        super.init(window: panel)
        refreshLanguage()
        setMaterial(reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refreshMaterial),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        panel.center()
        subscription = queue.$entries.receive(on: RunLoop.main).sink { [weak self] entries in
            guard let self, let window = self.window else { return }
            let size = Self.contentSize(entryCount: entries.count)
            var frame = NSRect(x: window.frame.minX, y: window.frame.maxY - size.height,
                               width: size.width, height: size.height)
            if let screen = window.screen { frame.origin.y = max(screen.visibleFrame.minY, frame.origin.y) }
            window.setFrame(frame, display: true)
            if entries.isEmpty && self.hadEntries { self.close() }
            self.hadEntries = !entries.isEmpty
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    deinit { NSWorkspace.shared.notificationCenter.removeObserver(self) }

    func present() { window?.makeKeyAndOrderFront(nil) }
    func refreshLanguage() {
        window?.title = L10n.text("Operations")
        hosting.rootView = QueueView(queue: queue, language: L10n.language, onClose: { [weak self] in self?.close() })
    }
    @objc private func refreshMaterial() {
        setMaterial(reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
    }
    func setMaterial(reduceTransparency: Bool) {
        let surface = AppSurface.make(content: hosting, opaque: reduceTransparency)
        surface.frame = NSRect(origin: .zero, size: window?.contentView?.bounds.size ?? Self.contentSize(entryCount: queue.entries.count))
        hosting.frame = surface.bounds
        window?.contentView = surface
        window?.invalidateShadow()
    }
}

private final class QueuePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { close() }
}

@MainActor
struct QueueView: View {
    @ObservedObject var queue: JobQueue
    let language: AppLanguage
    var onClose: () -> Void

    private func text(_ key: String, _ arguments: CVarArg...) -> String {
        L10n.string(key, language: language, arguments: arguments)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle").foregroundStyle(.orange)
                Text(text("Operations")).font(.headline)
                Spacer()
                Text(text("%ld active", queue.activeCount)).font(.caption).foregroundStyle(.secondary)
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.borderless).accessibilityLabel(text("Close Operations"))
            }
            if queue.entries.isEmpty {
                Spacer()
                Image(systemName: "checkmark.circle").font(.system(size: 32, weight: .light)).foregroundStyle(.orange)
                Text(text("No operations yet")).font(.headline)
                Text(text("Convert files or choose Move or ZIP to see their progress here."))
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(queue.entries) { entry in row(entry) }
                    }
                }
            }
            HStack {
                Button(text("Cancel All")) { queue.cancelAll() }.disabled(queue.isIdle)
                Spacer()
                Button(text("Clear Finished")) { queue.clearFinished() }
                    .disabled(!queue.entries.contains { $0.state.isFinished })
            }
            .controlSize(.small)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.locale, Locale(identifier: language.rawValue))
        .background(Color.clear)
    }

    private func row(_ entry: QueueEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.kind.title(in: language)).font(.subheadline.bold())
                    Text(entry.currentFile ?? entry.filenames.joined(separator: ", "))
                        .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(text(entry.state.rawValue)).font(.caption)
                    .foregroundStyle(entry.state == .failed ? Color.red : Color.secondary)
            }
            if !entry.state.isFinished {
                HStack {
                    // A batch fraction is measurable; an individual export has no invented percentage.
                    ProgressView(value: Double(entry.completedInputs), total: Double(max(1, entry.filenames.count)))
                    if entry.state == .running || entry.state == .cancelling {
                        ProgressView().controlSize(.small).frame(width: 16, height: 16)
                    }
                }
                .accessibilityLabel(text("%ld of %ld files completed", entry.completedInputs, entry.filenames.count))
            }
            if let error = entry.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                Text(text("%ld of %ld files completed", entry.completedInputs, entry.filenames.count))
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if entry.state.canCancel {
                    Button(text("Cancel")) { queue.cancel(entry.id) }
                }
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06)))
    }
}
