import AppKit
import QuartzCore
import YuzuCore
import UniformTypeIdentifiers

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
        case .float: return "pin"
        case .copy: return "doc.on.doc"
        case .move: return "folder"
        case .copyPath: return "doc.text"
        case .openTerminal: return "terminal"
        case .compress: return "archivebox"
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
    var symbol: String? {
        switch self {
        case .conversion: return nil
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
                         enabled: Bool, conversion: DragModifier = .shift, actions: DragModifier = .control) -> WheelMode? {
        let modifiers = flags.intersection([.shift, .control, .option, .command])
        defer { previous = modifiers }
        guard mouseDown, enabled else {
            mode = nil
            cancelled = false
            return nil
        }
        if escape { cancelled = true; mode = nil }
        guard !cancelled else { return nil }
        if modifiers != previous || mode == nil {
            // Match complete chords so a single-key shortcut cannot steal a multi-key choice.
            if modifiers == conversion.flags { mode = .conversion }
            else if modifiers == actions.flags { mode = .actions }
        }
        return mode
    }
}

enum WheelGeometry {
    static let inner: CGFloat = 64
    static let outer: CGFloat = 144
    static let centerRadius: CGFloat = 58
    static let labelRadius: CGFloat = 104
    static let gap: CGFloat = 6
    static let corner: CGFloat = 8

    static func angle(_ index: Int, count: Int) -> CGFloat {
        .pi / 2 - CGFloat(index) * 2 * .pi / CGFloat(count)
    }

    static func path(_ index: Int, count: Int, center: CGPoint) -> CGPath {
        let path = CGMutablePath()
        guard count > 0 else { return path }
        let half = .pi / CGFloat(count)
        let mid = angle(index, count: count)
        let start = mid - half, end = mid + half
        let outerTurn = asin((gap / 2 + corner) / (outer - corner))
        let innerTurn = asin((gap / 2 + corner) / (inner + corner))
        func point(_ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
            CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        // Tangent corner circles keep the six-point gap constant along each radial edge.
        path.addArc(center: center, radius: outer, startAngle: start + outerTurn, endAngle: end - outerTurn, clockwise: false)
        path.addArc(center: point(outer - corner, end - outerTurn), radius: corner,
                    startAngle: end - outerTurn, endAngle: end + .pi / 2, clockwise: false)
        path.addArc(center: point(inner + corner, end - innerTurn), radius: corner,
                    startAngle: end + .pi / 2, endAngle: end - innerTurn + .pi, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: end - innerTurn, endAngle: start + innerTurn, clockwise: true)
        path.addArc(center: point(inner + corner, start + innerTurn), radius: corner,
                    startAngle: start + innerTurn + .pi, endAngle: start + 3 * .pi / 2, clockwise: false)
        path.addArc(center: point(outer - corner, start + outerTurn), radius: corner,
                    startAngle: start - .pi / 2, endAngle: start + outerTurn, clockwise: false)
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
    var onHighlight: (() -> Void)?
    var onImageSources: ((ImageDrop, WheelDragView) -> Void)?
    var onImageDrop: ((ImageDrop, WheelOption) -> Void)?
    private(set) var imageDrop: ImageDrop?
    private var boardName: NSPasteboard.Name?
    private var boardChangeCount = 0
    private let materialMask = CAShapeLayer()
    private var paths: [CGPath] = []
    var isWheelVisible: Bool { confirmed && !options.isEmpty }
    var isReadingSources = true { didSet { onContentChanged?() } }
    var onContentChanged: (() -> Void)?
    var mode: WheelMode = .conversion
    var style: WheelStyle = .glass { didSet { updateMaterial(); needsDisplay = true } }
    var shortcutHint = "⇧ / ⌃ · Esc" { didSet { cancelHint.stringValue = shortcutHint } }
    private(set) var sources: [URL] = []
    private var centerPoint: CGPoint = .zero { didSet { rebuildPaths() } }
    private var selected: Int? {
        didSet {
            guard oldValue != selected else { return }
            needsDisplay = true
            updateCaption()
            updateLabels()
            updateMaterial()
            if selected != nil { onHighlight?() }
        }
    }
    private var labels: [NSButton] = []
    private let summary = NSTextField(labelWithString: "")
    private let caption = NSTextField(labelWithString: "")
    private let cancelHint = NSTextField(labelWithString: "⇧ / ⌃ · Esc")
    private let material = WheelMaterialView()
    var sourceCaption = "" { didSet { updateCaption() } }
    var idleCaption = "" { didSet { updateCaption() } }
    var options: [WheelOption] = [] { didSet { selected = nil; rebuildPaths(); rebuildLabels(); updateVisibility() } }
    var confirmed = false { didSet { updateVisibility() } }

    private func updateVisibility() {
        needsDisplay = true
        [summary, caption, cancelHint].forEach { $0.isHidden = !isWheelVisible }
        labels.forEach { $0.isHidden = !isWheelVisible }
        updateMaterial()
        onContentChanged?()
    }

    func refreshSources() {
        if let imageDrop { onImageSources?(imageDrop, self) }
        else if !sources.isEmpty { onSources?(sources, self) }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        registerForDraggedTypes([.fileURL] + ImageDrop.pasteboardTypes)
        material.wantsLayer = true
        material.layer?.mask = materialMask
        material.isHidden = true
        addSubview(material, positioned: .below, relativeTo: nil)
        summary.alignment = .center
        summary.font = .systemFont(ofSize: 12, weight: .semibold)
        summary.lineBreakMode = .byTruncatingMiddle
        caption.alignment = .center
        caption.font = .systemFont(ofSize: 10)
        caption.lineBreakMode = .byTruncatingTail
        caption.textColor = .secondaryLabelColor
        cancelHint.alignment = .center
        cancelHint.font = .systemFont(ofSize: 9)
        cancelHint.textColor = .secondaryLabelColor
        for field in [summary, caption, cancelHint] { field.isHidden = true; addSubview(field) }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(accessibilityChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    deinit { NSWorkspace.shared.notificationCenter.removeObserver(self) }

    @objc private func accessibilityChanged() { updateMaterial(); needsDisplay = true }

    private func rebuildPaths() {
        let radius = WheelGeometry.centerRadius
        let circle = CGPath(ellipseIn: CGRect(x: centerPoint.x - radius, y: centerPoint.y - radius,
                                             width: radius * 2, height: radius * 2), transform: nil)
        paths = [circle] + options.indices.map { WheelGeometry.path($0, count: options.count, center: centerPoint) }
    }

    override func layout() { super.layout(); updateMaterial() }

    private var usesGlass: Bool { style == .glass && !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency }

    private func updateMaterial() {
        material.frame = bounds
        material.isHidden = !isWheelVisible || !usesGlass
        let path = CGMutablePath()
        // Keep the selected petal outside the backdrop so its orange fill stays unfiltered.
        let highlightedPath = selected.map { $0 + 1 }
        for (index, region) in paths.enumerated() where highlightedPath != index {
            path.addPath(region)
        }
        // Updating one mask without implicit animation avoids a new glass composition/transition per hover.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        materialMask.frame = bounds
        materialMask.path = path
        CATransaction.commit()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard isWheelVisible, let context = NSGraphicsContext.current?.cgContext else { return }
        let paths = paths
        let petals = Array(paths.dropFirst())
        for path in paths {
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: NSColor.black.withAlphaComponent(0.13).cgColor)
            context.addPath(path)
            context.setFillColor(NSColor.windowBackgroundColor.withAlphaComponent(usesGlass ? 0.18 : 1).cgColor)
            context.fillPath()
            context.restoreGState()
            context.addPath(path)
            context.setStrokeColor(NSColor.separatorColor.withAlphaComponent(0.32).cgColor)
            context.setLineWidth(0.75)
            context.strokePath()
        }
        if let selected, petals.indices.contains(selected) {
            let orange = NSColor(srgbRed: 1, green: 0.32, blue: 0.02, alpha: 0.96).cgColor
            context.addPath(petals[selected])
            context.setFillColor(orange)
            context.setStrokeColor(orange)
            context.setLineWidth(1)
            context.drawPath(using: .fillStroke)
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        var urls = Self.fileURLs(sender) ?? []
        let promisedImage = sender.draggingPasteboard.string(forType: ImageDrop.promiseContentType).flatMap { UTType($0) }?.conforms(to: .image) == true
        imageDrop = urls.isEmpty || promisedImage ? ImageDrop.read(sender.draggingPasteboard) : nil
        if imageDrop != nil { urls = [] }
        guard !urls.isEmpty || imageDrop != nil else { return [] }
        boardName = sender.draggingPasteboard.name
        boardChangeCount = sender.draggingPasteboard.changeCount
        isReadingSources = true
        options = []
        centerPoint = WheelGeometry.center(near: sender.draggingLocation, in: bounds)
        summary.frame = NSRect(x: centerPoint.x - 51, y: centerPoint.y + 9, width: 102, height: 17)
        caption.frame = NSRect(x: centerPoint.x - 55, y: centerPoint.y - 10, width: 110, height: 14)
        cancelHint.frame = NSRect(x: centerPoint.x - 51, y: centerPoint.y - 27, width: 102, height: 12)
        sources = urls
        sourceCaption = imageDrop?.name ?? (urls.count == 1 ? urls[0].lastPathComponent : L10n.text("%ld files", urls.count))
        confirmed = true
        idleCaption = L10n.text("Reading file…")
        refreshSources()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        selected = paths.dropFirst().enumerated().first { $0.element.contains(sender.draggingLocation) }?.offset
        return selected == nil ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { selected = nil }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        validDrag(sender) && selected != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard validDrag(sender),
              let index = paths.dropFirst().enumerated().first(where: { $0.element.contains(sender.draggingLocation) })?.offset else { return false }
        let urls = sources
        let option = options[index]
        confirmed = false
        if let imageDrop {
            do { try imageDrop.accept() } catch {
                DispatchQueue.main.async { ActionController.show(error) }
                return false
            }
            onImageDrop?(imageDrop, option)
        } else { onDrop?(urls, option) }
        return true
    }

    private func validDrag(_ sender: NSDraggingInfo) -> Bool {
        if imageDrop != nil { return sender.draggingPasteboard.name == boardName && sender.draggingPasteboard.changeCount == boardChangeCount }
        return Self.fileURLs(sender) == sources
    }

    private static func fileURLs(_ sender: NSDraggingInfo) -> [URL]? {
        guard let values = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL], !values.isEmpty,
              values.allSatisfy({ $0.isFileURL }) else { return nil }
        return values.map(\.standardizedFileURL)
    }

    private func updateCaption() {
        summary.stringValue = sourceCaption
        summary.toolTip = sourceCaption
        if let selected {
            switch options[selected] {
            case .conversion(let format): caption.stringValue = L10n.text("To %@", format.label)
            case .action: caption.stringValue = L10n.text("Release file")
            }
        } else { caption.stringValue = idleCaption }
        caption.toolTip = caption.stringValue
    }

    private func rebuildLabels() {
        labels.forEach { $0.removeFromSuperview() }
        labels = options.enumerated().map { i, option in
            let angle = WheelGeometry.angle(i, count: options.count)
            let button = NSButton(title: option.title, target: self, action: #selector(activateOption(_:)))
            button.image = option.symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
            button.imagePosition = option.symbol == nil ? .noImage : .imageAbove
            button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 21, weight: .medium)
            button.imageScaling = .scaleProportionallyDown
            button.isBordered = false
            button.tag = i
            button.setAccessibilityLabel(option.title)
            button.toolTip = option.help
            button.setAccessibilityHelp(option.help)
            let size = option.symbol == nil ? NSSize(width: 60, height: 28) : NSSize(width: 82, height: 52)
            button.frame = NSRect(x: centerPoint.x + cos(angle) * WheelGeometry.labelRadius - size.width / 2,
                                  y: centerPoint.y + sin(angle) * WheelGeometry.labelRadius - size.height / 2,
                                  width: size.width, height: size.height)
            button.isHidden = !isWheelVisible
            addSubview(button)
            return button
        }
        updateLabels()
        updateMaterial()
        needsDisplay = true
    }

    private func updateLabels() {
        for button in labels {
            guard options.indices.contains(button.tag) else { continue }
            let color: NSColor = selected == button.tag ? .white : .labelColor
            button.contentTintColor = color
            button.attributedTitle = NSAttributedString(string: button.title, attributes: [
                .font: NSFont.systemFont(ofSize: options[button.tag].symbol == nil ? 16 : 10,
                                        weight: selected == button.tag ? .semibold : .medium),
                .foregroundColor: color
            ])
        }
    }

    @objc private func activateOption(_ sender: NSButton) {
        guard isWheelVisible, options.indices.contains(sender.tag) else { return }
        if let imageDrop {
            do { try imageDrop.accept(); onImageDrop?(imageDrop, options[sender.tag]) }
            catch { ActionController.show(error) }
        }
        else if !sources.isEmpty { onDrop?(sources, options[sender.tag]) }
    }
}

/// The backdrop follows the wheel without intercepting its drag destination or accessible buttons.
@MainActor
final class WheelMaterialView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        let surface = AppSurface.make(content: NSView(), opaque: false, cornerRadius: 0)
        surface.frame = bounds
        surface.autoresizingMask = [.width, .height]
        addSubview(surface)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class WheelMonitor {
    private let settings: Settings
    private var timer: Timer?
    private var trigger = DragTrigger()
    private var panel: NSPanel?
    private var view: WheelDragView?
    private var mode: WheelMode?
    private let feedback: WheelFeedback
    private let haptic = NSHapticFeedbackManager.defaultPerformer
    var onSources: (([URL], WheelDragView) -> Void)?
    var onDrop: (([URL], WheelOption) -> Void)?
    var onImageDrop: ((ImageDrop, WheelOption) -> Void)?

    init(settings: Settings, feedbackSound: NSSound? = NSSound(named: NSSound.Name("Tink"))) {
        self.settings = settings
        self.feedback = WheelFeedback(sound: feedbackSound)
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .eventTracking) }
    }

    func stop() { timer?.invalidate(); timer = nil; dismiss() }

    func dismiss() { panel?.orderOut(nil); panel = nil; view = nil; mode = nil }

    func refreshLanguage() {
        view?.style = settings.wheelStyle
        view?.shortcutHint = settings.shortcutHint
        if let view, view.confirmed { view.refreshSources() }
    }

    private func poll() {
        let next = trigger.update(mouseDown: CGEventSource.buttonState(.combinedSessionState, button: .left),
                                  flags: NSEvent.modifierFlags,
                                  escape: CGEventSource.keyState(.combinedSessionState, key: 53),
                                  enabled: settings.wheelsEnabled, conversion: settings.conversionModifier,
                                  actions: settings.actionsModifier)
        guard let next else { if panel != nil { dismiss() }; return }
        if panel == nil { arm(next) }
        if mode != next {
            mode = next
            view?.mode = next
            if let view, view.confirmed { view.refreshSources() }
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
        view.style = settings.wheelStyle
        view.shortcutHint = settings.shortcutHint
        view.onHighlight = { [weak self] in
            guard let self, self.settings.soundsAndHapticsEnabled else { return }
            self.feedback.play()
            self.haptic.perform(.alignment, performanceTime: .drawCompleted)
        }
        view.onContentChanged = { [weak view, weak panel] in
            guard let view, view.confirmed else { return }
            // Keep an empty conversion from intercepting the original Finder drop; retain state for a mode switch.
            if !view.isReadingSources && view.options.isEmpty { panel?.orderOut(nil) }
            else { panel?.orderFrontRegardless() }
        }
        view.onSources = { [weak self] urls, view in self?.onSources?(urls, view) }
        view.onImageSources = { image, view in
            view.sourceCaption = L10n.text("Image")
            view.idleCaption = L10n.text("Convert")
            view.options = view.mode == .conversion ? ConversionEngine.imageDropTargets.map(WheelOption.conversion) : []
            view.isReadingSources = false
        }
        view.onImageDrop = { [weak self] image, option in self?.dismiss(); self?.onImageDrop?(image, option) }
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

/// NSSound may initialize the audio service on first play; a serial queue keeps that work out of draggingUpdated.
private final class WheelFeedback: @unchecked Sendable {
    private static let queue = DispatchQueue(label: "com.stpashik.yuzu-converter.wheel-feedback")
    private let sound: NSSound?
    init(sound: NSSound?) { self.sound = sound }
    func play() {
        Self.queue.async { [self] in
            sound?.stop()
            sound?.currentTime = 0
            sound?.volume = 0.2
            sound?.play()
        }
    }
}
