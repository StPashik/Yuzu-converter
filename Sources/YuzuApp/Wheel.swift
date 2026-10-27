import AppKit
import YuzuCore

enum WheelMode: Equatable { case conversion, actions }

enum FileAction: String, CaseIterable {
    case airDrop, float, copy, move, copyPath, openTerminal, compress

    var title: String {
        switch self {
        case .airDrop: return L10n.text("AirDrop")
        case .float: return L10n.text("Float")
        case .copy: return L10n.text("Copy")
        case .move: return L10n.text("Move")
        case .copyPath: return L10n.text("Copy Path")
        case .openTerminal: return L10n.text("Terminal")
        case .compress: return L10n.text("ZIP")
        }
    }
    var symbol: String {
        switch self {
        case .airDrop: return "airplayaudio"
        case .float: return "square.stack.3d.up"
        case .copy: return "doc.on.doc"
        case .move: return "folder"
        case .copyPath: return "link"
        case .openTerminal: return "terminal"
        case .compress: return "doc.zipper"
        }
    }

    var help: String {
        switch self {
        case .airDrop: return L10n.text("Share the selected files with AirDrop.")
        case .float: return L10n.text("Keep file references on a floating shelf. Originals stay in place.")
        case .copy: return L10n.text("Copy files for pasting into another app.")
        case .move: return L10n.text("Move files to a folder you choose.")
        case .copyPath: return L10n.text("Copy full file paths, one per line.")
        case .openTerminal: return L10n.text("Open Terminal in the selected folder or the file’s parent folder.")
        case .compress: return L10n.text("Create one ZIP beside the first selected item. Originals stay in place.")
        }
    }

}

enum WheelOption: Equatable {
    case conversion(FileFormat)
    case action(FileAction)

    var title: String {
        switch self {
        case .conversion(let format): return format.label
        case .action(let action): return action.title
        }
    }
    var symbol: String {
        switch self {
        case .conversion: return "arrow.triangle.2.circlepath"
        case .action(let action): return action.symbol
        }
    }
    var help: String {
        switch self {
        case .conversion(let format) where [.xlsx, .ods, .csv, .tsv].contains(format):
            return L10n.text("Values only. Formulas, formatting, and embedded objects are not preserved.")
        case .action(let action): return action.help
        default: return title
        }
    }
}

/// Only the trigger is global. File URLs are read from an actual AppKit drag event.
struct DragTrigger {
    private(set) var mode: WheelMode?
    private var previous: NSEvent.ModifierFlags = []
    private var cancelled = false

    mutating func update(mouseDown: Bool, flags: NSEvent.ModifierFlags, escape: Bool,
                         enabled: Bool, swapped: Bool) -> WheelMode? {
        defer { previous = flags }
        guard mouseDown, enabled else {
            mode = nil
            cancelled = false
            return nil
        }
        if escape { cancelled = true; mode = nil }
        guard !cancelled else { return nil }
        let added = flags.subtracting(previous)
        if added.contains(.shift) || (mode == nil && flags.contains(.shift)) {
            mode = swapped ? .actions : .conversion
        }
        if added.contains(.control) || (mode == nil && flags.contains(.control)) {
            mode = swapped ? .conversion : .actions
        }
        return mode
    }
}

enum WheelGeometry {
    static let inner: CGFloat = 48.64
    static let outer: CGFloat = 119.52

    static func angle(_ index: Int, count: Int) -> CGFloat {
        (count == 3 ? .pi : .pi / 2) - CGFloat(index) * 2 * .pi / CGFloat(count)
    }

    static func path(_ index: Int, count: Int, center: CGPoint) -> CGPath {
        let path = CGMutablePath()
        guard count > 0 else { return path }
        let half = .pi / CGFloat(count) - 0.025
        let mid = angle(index, count: count)
        path.addArc(center: center, radius: outer, startAngle: mid - half,
                    endAngle: mid + half, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: mid + half,
                    endAngle: mid - half, clockwise: true)
        path.closeSubpath()
        return path
    }

    static func selection(at point: CGPoint, count: Int, center: CGPoint) -> Int? {
        (0..<max(0, count)).first { path($0, count: count, center: center).contains(point) }
    }

    static func center(near point: CGPoint, in bounds: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, bounds.minX + outer + 12), bounds.maxX - outer - 12),
                y: min(max(point.y, bounds.minY + outer + 12), bounds.maxY - outer - 12))
    }
}

@MainActor
final class WheelDragView: NSView {
    var onSources: (([URL], WheelDragView) -> Void)?
    var onDrop: (([URL], WheelOption) -> Void)?
    var mode: WheelMode = .conversion
    private(set) var sources: [URL] = []
    private var centerPoint: CGPoint = .zero
    private var selected: Int? { didSet { needsDisplay = true; updateCaption() } }
    private var labels: [NSButton] = []
    private let caption = NSTextField(wrappingLabelWithString: "")
    var idleCaption = "" { didSet { updateCaption() } }
    var options: [WheelOption] = [] { didSet { selected = nil; rebuildLabels() } }
    var confirmed = false {
        didSet { needsDisplay = true; caption.isHidden = !confirmed; labels.forEach { $0.isHidden = !confirmed } }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
        caption.alignment = .center
        caption.font = .systemFont(ofSize: 11, weight: .medium)
        caption.maximumNumberOfLines = 3
        caption.textColor = .labelColor
        caption.isHidden = true
        addSubview(caption)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func draw(_ dirtyRect: NSRect) {
        guard confirmed, let context = NSGraphicsContext.current?.cgContext else { return }
        for i in options.indices {
            context.addPath(WheelGeometry.path(i, count: options.count, center: centerPoint))
            context.setFillColor((selected == i ? NSColor.systemOrange :
                                  NSColor.windowBackgroundColor.withAlphaComponent(0.97)).cgColor)
            context.setStrokeColor(NSColor.separatorColor.cgColor)
            context.setLineWidth(0.75)
            context.drawPath(using: .fillStroke)
        }
        context.setFillColor(NSColor.windowBackgroundColor.withAlphaComponent(0.97).cgColor)
        context.fillEllipse(in: CGRect(x: centerPoint.x - 45, y: centerPoint.y - 45,
                                       width: 90, height: 90))
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let urls = Self.fileURLs(sender) else { return [] }
        centerPoint = WheelGeometry.center(near: sender.draggingLocation, in: bounds)
        caption.frame = NSRect(x: centerPoint.x - 40, y: centerPoint.y - 25, width: 80, height: 50)
        sources = urls
        confirmed = true
        idleCaption = L10n.text("Reading file…")
        onSources?(urls, self)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        selected = WheelGeometry.selection(at: sender.draggingLocation, count: options.count,
                                            center: centerPoint)
        return selected == nil ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { selected = nil }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        Self.fileURLs(sender) == sources && selected != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard Self.fileURLs(sender) == sources,
              let index = WheelGeometry.selection(at: sender.draggingLocation,
                                                   count: options.count, center: centerPoint) else { return false }
        let urls = sources
        let option = options[index]
        confirmed = false
        onDrop?(urls, option)
        return true
    }

    private static func fileURLs(_ sender: NSDraggingInfo) -> [URL]? {
        guard let values = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL], !values.isEmpty,
              values.allSatisfy({ $0.isFileURL }) else { return nil }
        return values.map(\.standardizedFileURL)
    }

    private func updateCaption() {
        caption.stringValue = selected.map { options[$0].title } ?? idleCaption
    }

    private func rebuildLabels() {
        labels.forEach { $0.removeFromSuperview() }
        labels = options.enumerated().map { i, option in
            let angle = WheelGeometry.angle(i, count: options.count)
            let button = NSButton(title: option.title, target: self, action: #selector(activateOption(_:)))
            button.image = NSImage(systemSymbolName: option.symbol, accessibilityDescription: nil)
            button.imagePosition = .imageAbove
            button.isBordered = false
            button.font = .systemFont(ofSize: 11, weight: .semibold)
            button.tag = i
            button.setAccessibilityLabel(option.title)
            button.toolTip = option.help
            button.setAccessibilityHelp(option.help)
            button.frame = NSRect(x: centerPoint.x + cos(angle) * 83 - 36,
                                  y: centerPoint.y + sin(angle) * 83 - 23, width: 72, height: 46)
            addSubview(button)
            return button
        }
        needsDisplay = true
    }

    @objc private func activateOption(_ sender: NSButton) {
        guard confirmed, options.indices.contains(sender.tag), !sources.isEmpty else { return }
        onDrop?(sources, options[sender.tag])
    }
}

@MainActor
final class WheelMonitor {
    private let settings: Settings
    private var timer: Timer?
    private var trigger = DragTrigger()
    private var panel: NSPanel?
    private var view: WheelDragView?
    private var mode: WheelMode?
    var onSources: (([URL], WheelDragView) -> Void)?
    var onDrop: (([URL], WheelOption) -> Void)?

    init(settings: Settings) { self.settings = settings }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .eventTracking) }
    }

    func stop() { timer?.invalidate(); timer = nil; dismiss() }

    func dismiss() { panel?.orderOut(nil); panel = nil; view = nil; mode = nil }

    func refreshLanguage() {
        if let view, view.confirmed { onSources?(view.sources, view) }
    }

    private func poll() {
        let next = trigger.update(mouseDown: CGEventSource.buttonState(.combinedSessionState, button: .left),
                                  flags: NSEvent.modifierFlags,
                                  escape: CGEventSource.keyState(.combinedSessionState, key: 53),
                                  enabled: settings.wheelsEnabled, swapped: settings.swapModifiers)
        guard let next else { if panel != nil { dismiss() }; return }
        if panel == nil { arm(next) }
        if mode != next {
            mode = next
            view?.mode = next
            if let view, !view.sources.isEmpty { onSources?(view.sources, view) }
        }
    }

    func arm(_ mode: WheelMode) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) else { return }
        let panel = NSPanel(contentRect: screen.visibleFrame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        // WindowServer skips fully transparent pixels during hit-testing, before draggingEntered can draw the wheel.
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.01)
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = WheelDragView(frame: NSRect(origin: .zero, size: screen.visibleFrame.size))
        view.mode = mode
        view.onSources = { [weak self] urls, view in self?.onSources?(urls, view) }
        view.onDrop = { [weak self] urls, option in
            self?.dismiss()
            self?.onDrop?(urls, option)
        }
        panel.contentView = view
        self.panel = panel
        self.view = view
        self.mode = mode
        // The wheel stays hidden until draggingEntered confirms file URLs.
        panel.orderFrontRegardless()
    }
}
