import AppKit
import QuickLookThumbnailing

@MainActor
final class ShelfController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    private let content = ShelfView()
    private(set) var files: [URL] = []
    // Keep each batch's grants until its last reference or pending thumbnail request is released.
    private var leases: [URL: ScopedFiles] = [:]
    private var thumbnails: [URL: NSImage] = [:]
    private var requests: [URL: (id: UUID, request: QLThumbnailGenerator.Request)] = [:]
    private weak var anchor: NSView?
    private var offset: CGFloat = 0
    private var reloadingTable = false

    init() {
        let panel = ShelfPanel(contentRect: NSRect(origin: .zero, size: Self.contentSize(fileCount: 0)),
                               styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // Keep references available while Finder or the eventual drop destination is active.
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: panel)
        panel.delegate = self
        content.table.dataSource = self
        content.table.delegate = self
        content.onDrop = { [weak self] in self?.add($0) }
        content.table.onRemove = { [weak self] in self?.removeSelected() }
        content.table.onContextSelection = { [weak self] in self?.rebuildMenu() }
        content.closeButton.target = self
        content.closeButton.action = #selector(close)
        content.clearButton.target = self
        content.clearButton.action = #selector(clearShelf)
        NotificationCenter.default.addObserver(self, selector: #selector(reposition),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refreshMaterial),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        refreshMaterial()
        refreshLanguage()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    static func contentSize(fileCount: Int) -> NSSize {
        NSSize(width: 368, height: fileCount == 0 ? 238 : 76 + CGFloat(min(fileCount, 5)) * 68)
    }

    static func frame(for size: NSSize, anchor: NSRect?, screen: NSRect, offset: CGFloat = 0) -> NSRect {
        let area = screen.insetBy(dx: 12, dy: 12)
        let width = min(size.width, area.width), height = min(size.height, area.height)
        let x = anchor.map { $0.midX - width / 2 + offset } ?? (area.maxX - width)
        let y = anchor.map { $0.minY - 10 - height - offset } ?? (area.maxY - height)
        return NSRect(x: max(area.minX, min(x, area.maxX - width)),
                      y: max(area.minY, min(y, area.maxY - height)), width: width, height: height)
    }

    func present(relativeTo view: NSView?, offset: CGFloat = 0) {
        anchor = view
        self.offset = offset
        NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: nil)
        if let anchorWindow = view?.window {
            NotificationCenter.default.addObserver(self, selector: #selector(reposition),
                                                   name: NSWindow.didMoveNotification, object: anchorWindow)
        }
        reposition()
        reloadTable()
        rebuildMenu()
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func reposition() {
        guard let screen = anchor?.window?.screen ?? window?.screen ?? NSScreen.main else { return }
        let rect = anchor.flatMap { view in view.window?.convertToScreen(view.convert(view.bounds, to: nil)) }
        window?.setFrame(Self.frame(for: Self.contentSize(fileCount: files.count), anchor: rect,
                                    screen: screen.visibleFrame, offset: offset), display: true)
    }

    @objc private func refreshMaterial() {
        setMaterial(reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
    }

    func setMaterial(reduceTransparency: Bool) {
        let surface = AppSurface.make(content: content, opaque: reduceTransparency)
        surface.frame = NSRect(origin: .zero, size: window?.contentView?.bounds.size ?? Self.contentSize(fileCount: files.count))
        content.frame = surface.bounds
        content.autoresizingMask = [.width, .height]
        window?.contentView = surface
        window?.invalidateShadow()
    }

    func refreshLanguage() {
        window?.title = L10n.text("Yuzu Shelf")
        content.refreshLanguage(fileCount: files.count)
        reloadTable()
        rebuildMenu()
    }

    func add(_ incoming: ScopedFiles) {
        var added = IndexSet()
        for url in incoming.urls where url.isFileURL && !files.contains(url) {
            added.insert(files.count)
            files.append(url)
            leases[url] = incoming
        }
        reload()
        if !added.isEmpty { content.table.selectRowIndexes(added, byExtendingSelection: false) }
        rebuildMenu()
    }

    func removeFiles(at rows: IndexSet) {
        let selection = selectedFiles().filter { url in !rows.contains(where: { files.indices.contains($0) && files[$0] == url }) }
        for index in rows.reversed() where files.indices.contains(index) {
            let url = files.remove(at: index)
            if let pending = requests.removeValue(forKey: url) { QLThumbnailGenerator.shared.cancel(pending.request) }
            thumbnails[url] = nil
            leases[url] = nil
        }
        reload()
        content.table.selectRowIndexes(IndexSet(files.indices.filter { selection.contains(files[$0]) }), byExtendingSelection: false)
        rebuildMenu()
    }

    private func selectedFiles() -> [URL] {
        content.table.selectedRowIndexes.compactMap { files.indices.contains($0) ? files[$0] : nil }
    }

    func retainedBatches(for urls: [URL]) -> [ScopedFiles] {
        urls.compactMap { leases[$0] }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if !reloadingTable { rebuildMenu() }
    }

    private func reloadTable() {
        let selection = selectedFiles()
        // AppKit clears selection on reload; language/preview refresh must not invalidate a user's command.
        reloadingTable = true
        content.table.reloadData()
        content.table.selectRowIndexes(IndexSet(files.indices.filter { selection.contains(files[$0]) }), byExtendingSelection: false)
        reloadingTable = false
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let remove = menu.addItem(withTitle: L10n.text("Remove from Shelf"), action: #selector(removeSelected), keyEquivalent: "")
        remove.target = self
        remove.isEnabled = !selectedFiles().isEmpty
        content.table.menu = menu
    }

    private func reload() {
        content.refreshLanguage(fileCount: files.count)
        reloadTable()
        reposition()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { files.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ShelfFile")
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? ShelfCell ?? ShelfCell()
        cell.identifier = identifier
        let url = files[row]
        cell.configure(url: url, image: thumbnails[url] ?? NSWorkspace.shared.icon(forFile: url.path))
        cell.revealButton.tag = row
        cell.revealButton.target = self
        cell.revealButton.action = #selector(revealFile(_:))
        cell.removeButton.tag = row
        cell.removeButton.target = self
        cell.removeButton.action = #selector(removeFile(_:))
        loadThumbnail(for: url)
        return cell
    }

    private func loadThumbnail(for url: URL) {
        guard thumbnails[url] == nil, requests[url] == nil, let lease = leases[url] else { return }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: NSSize(width: 40, height: 40),
            scale: window?.backingScaleFactor ?? 2, representationTypes: [.thumbnail, .icon])
        let id = UUID()
        requests[url] = (id, request)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self, lease] representation, _ in
            Task { @MainActor [weak self, lease] in
                defer { withExtendedLifetime(lease) {} }
                // A removed/re-added path must not receive a late preview from its previous request.
                guard let self, requests[url]?.id == id, let row = files.firstIndex(of: url) else { return }
                requests[url] = nil
                thumbnails[url] = representation?.nsImage ?? NSWorkspace.shared.icon(forFile: url.path)
                content.table.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
            }
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { ShelfRow() }
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        files[row] as NSURL
    }
    @objc private func revealFile(_ sender: NSButton) {
        guard files.indices.contains(sender.tag) else { return }
        let url = files[sender.tag]
        let batch = ScopedFiles([url], retaining: retainedBatches(for: [url]))
        Task {
            do {
                try await Task.detached {
                    defer { withExtendedLifetime(batch) {} }
                    guard try url.checkResourceIsReachable() else { throw CocoaError(.fileNoSuchFile) }
                }.value
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                let alert = NSAlert()
                alert.messageText = L10n.text("Could not show the file")
                alert.informativeText = L10n.text("The file is no longer available at its original location.") + "\n" + url.path
                alert.runModal()
            }
        }
    }
    @objc private func removeFile(_ sender: NSButton) { removeFiles(at: IndexSet(integer: sender.tag)) }
    @objc private func removeSelected() { removeFiles(at: content.table.selectedRowIndexes) }
    @objc private func clearShelf() { removeFiles(at: IndexSet(files.indices)) }

    func windowWillClose(_ notification: Notification) {
        // Show Shelf needs this session's references and grants; closing only cancels pending previews.
        requests.values.forEach { QLThumbnailGenerator.shared.cancel($0.request) }
        requests.removeAll()
        rebuildMenu()
    }
}

private final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { close() }
}

@MainActor
private final class ShelfView: NSView {
    let table = ShelfTable()
    let clearButton = ShelfView.button(symbol: "trash")
    let closeButton = ShelfView.button(symbol: "xmark")
    var onDrop: ((ScopedFiles) -> Void)?
    private let scroll = NSScrollView()
    private let title = NSTextField(labelWithString: "")
    private let count = NSTextField(labelWithString: "")
    private let symbol = NSImageView(image: NSImage(systemSymbolName: "tray.full.fill", accessibilityDescription: nil)!)
    private let emptySymbol = NSImageView(image: NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: nil)!)
    private let emptyTitle = NSTextField(labelWithString: "")
    private let emptyHint = NSTextField(wrappingLabelWithString: "")
    private var receivingDrop = false { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        count.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        count.textColor = .secondaryLabelColor
        count.alignment = .right
        symbol.contentTintColor = .systemOrange
        emptySymbol.contentTintColor = .systemOrange
        emptySymbol.symbolConfiguration = .init(pointSize: 30, weight: .light)
        emptyTitle.font = .systemFont(ofSize: 14, weight: .medium)
        emptyTitle.alignment = .center
        emptyHint.font = .systemFont(ofSize: 11)
        emptyHint.textColor = .secondaryLabelColor
        emptyHint.alignment = .center
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 64
        table.intercellSpacing = NSSize(width: 0, height: 4)
        table.backgroundColor = .clear
        table.style = .plain
        table.allowsMultipleSelection = true
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.setDraggingSourceOperationMask(.copy, forLocal: false)
        // The wheel is another destination inside Yuzu, unlike Finder and other apps.
        table.setDraggingSourceOperationMask(.copy, forLocal: true)
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.borderType = .noBorder
        scroll.documentView = table
        [symbol, title, count, clearButton, closeButton, scroll, emptySymbol, emptyTitle, emptyHint].forEach(addSubview)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    static func button(symbol: String) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!, target: nil, action: nil)
        button.isBordered = false
        button.bezelStyle = .circular
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .secondaryLabelColor
        return button
    }

    func refreshLanguage(fileCount: Int) {
        title.stringValue = L10n.text("Yuzu Shelf")
        count.stringValue = fileCount == 0 ? "" : String(fileCount)
        count.setAccessibilityLabel(fileCount == 1 ? L10n.text("1 file") : L10n.text("%ld files", fileCount))
        clearButton.toolTip = L10n.text("Clear Shelf")
        clearButton.setAccessibilityLabel(L10n.text("Clear Shelf"))
        clearButton.isEnabled = fileCount > 0
        closeButton.toolTip = L10n.text("Close Shelf")
        closeButton.setAccessibilityLabel(L10n.text("Close Shelf"))
        table.setAccessibilityLabel(L10n.text("Files on the floating shelf. Drag files out or reveal them in Finder."))
        emptyTitle.stringValue = L10n.text("Drop files here")
        emptyHint.stringValue = L10n.text("Files stay in their original locations.")
        [emptySymbol, emptyTitle, emptyHint].forEach { $0.isHidden = fileCount != 0 }
        scroll.isHidden = fileCount == 0
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let width = bounds.width, height = bounds.height
        symbol.frame = NSRect(x: 20, y: 19, width: 20, height: 20)
        title.frame = NSRect(x: 49, y: 18, width: max(0, width - 167), height: 22)
        count.frame = NSRect(x: width - 119, y: 22, width: 30, height: 16)
        clearButton.frame = NSRect(x: width - 81, y: 14, width: 30, height: 30)
        closeButton.frame = NSRect(x: width - 47, y: 14, width: 30, height: 30)
        scroll.frame = NSRect(x: 16, y: 60, width: width - 32, height: max(0, height - 72))
        table.frame.size = NSSize(width: scroll.contentSize.width,
                                 height: max(scroll.contentSize.height, CGFloat(table.numberOfRows) * 68))
        table.tableColumns.first?.width = scroll.contentSize.width
        emptySymbol.frame = NSRect(x: (width - 44) / 2, y: 76, width: 44, height: 44)
        emptyTitle.frame = NSRect(x: 20, y: 132, width: width - 40, height: 22)
        emptyHint.frame = NSRect(x: 28, y: 159, width: width - 56, height: 32)
    }

    override func draw(_ dirtyRect: NSRect) {
        if receivingDrop {
            NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
            let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 5), xRadius: 20, yRadius: 20)
            outline.fill()
            NSColor.controlAccentColor.setStroke()
            outline.lineWidth = 2
            outline.stroke()
        }
    }

    private func urls(from sender: NSDraggingInfo) -> [URL] {
        (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
            as? [URL] ?? []).filter(\.isFileURL)
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        receivingDrop = sender.draggingSourceOperationMask.contains(.copy) && !urls(from: sender).isEmpty
        return receivingDrop ? .copy : []
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { receivingDrop = false }
    override func draggingEnded(_ sender: NSDraggingInfo) { receivingDrop = false }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { receivingDrop = false }
        let files = urls(from: sender)
        guard sender.draggingSourceOperationMask.contains(.copy), !files.isEmpty else { return false }
        onDrop?(ScopedFiles(files))
        return true
    }
}

private final class ShelfTable: NSTableView {
    var onRemove: (() -> Void)?
    var onContextSelection: (() -> Void)?
    override func menu(for event: NSEvent) -> NSMenu? {
        let row = row(at: convert(event.locationInWindow, from: nil))
        if row >= 0 && !selectedRowIndexes.contains(row) {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        } else if row < 0 { deselectAll(nil) }
        onContextSelection?()
        return super.menu(for: event)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 || event.keyCode == 117 { onRemove?() }
        else { super.keyDown(with: event) }
    }
}

private final class ShelfRow: NSTableRowView {
    // Translucent selection needs normal label contrast instead of white text for an opaque accent fill.
    override var interiorBackgroundStyle: NSView.BackgroundStyle { .normal }
    override func drawBackground(in dirtyRect: NSRect) {
        NSColor.labelColor.withAlphaComponent(0.045).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 2), xRadius: 12, yRadius: 12).fill()
    }
    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 2), xRadius: 12, yRadius: 12).fill()
    }
}

private final class ShelfCell: NSTableCellView {
    let removeButton = ShelfView.button(symbol: "xmark.circle.fill")
    let revealButton = ShelfView.button(symbol: "folder")
    private let name = NSTextField(labelWithString: "")
    private let folder = NSTextField(labelWithString: "")
    private let preview = NSImageView()
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        name.font = .systemFont(ofSize: 13, weight: .medium)
        name.lineBreakMode = .byTruncatingMiddle
        folder.font = .systemFont(ofSize: 11)
        folder.textColor = .secondaryLabelColor
        folder.lineBreakMode = .byTruncatingMiddle
        preview.imageScaling = .scaleProportionallyUpOrDown
        preview.setAccessibilityElement(false)
        textField = name
        imageView = preview
        [preview, name, folder, revealButton, removeButton].forEach(addSubview)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(url: URL, image: NSImage) {
        name.stringValue = url.lastPathComponent
        name.setAccessibilityLabel(url.path)
        folder.stringValue = url.deletingLastPathComponent().lastPathComponent
        preview.image = image
        toolTip = url.path
        revealButton.toolTip = L10n.text("Show in Finder") + ": " + url.lastPathComponent
        revealButton.setAccessibilityLabel(revealButton.toolTip)
        removeButton.toolTip = L10n.text("Remove from Shelf") + ": " + url.lastPathComponent
        removeButton.setAccessibilityLabel(removeButton.toolTip)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        preview.frame = NSRect(x: 12, y: 12, width: 40, height: 40)
        name.frame = NSRect(x: 64, y: 13, width: max(0, bounds.width - 130), height: 20)
        folder.frame = NSRect(x: 64, y: 35, width: max(0, bounds.width - 130), height: 16)
        revealButton.frame = NSRect(x: bounds.width - 62, y: 20, width: 24, height: 24)
        removeButton.frame = NSRect(x: bounds.width - 34, y: 20, width: 24, height: 24)
    }
}
