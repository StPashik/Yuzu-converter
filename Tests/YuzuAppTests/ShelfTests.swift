import AppKit
import XCTest
@testable import YuzuApp

final class ShelfTests: XCTestCase {
    @MainActor
    func testAnchoringHandlesEdgesSecondaryDisplaysAndLongLists() {
        for screen in [NSRect(x: 0, y: 0, width: 1440, height: 877),
                       NSRect(x: -1280, y: 120, width: 1280, height: 900),
                       NSRect(x: 0, y: 0, width: 320, height: 300)] {
            for x in [screen.minX, screen.midX, screen.maxX] {
                for count in [0, 1, 5, 100] {
                    let anchor = NSRect(x: x, y: screen.maxY, width: 24, height: 24)
                    let frame = ShelfController.frame(for: ShelfController.contentSize(fileCount: count),
                                                     anchor: anchor, screen: screen, offset: 36)
                    XCTAssertTrue(screen.insetBy(dx: 11, dy: 11).contains(frame))
                    XCTAssertLessThan(frame.maxY, anchor.minY)
                }
            }
        }
        XCTAssertLessThan(ShelfController.contentSize(fileCount: 1).height, 200)
        XCTAssertEqual(ShelfController.contentSize(fileCount: 5), ShelfController.contentSize(fileCount: 100))
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 877)
        XCTAssertTrue(screen.contains(ShelfController.frame(for: NSSize(width: 368, height: 238),
                                                            anchor: nil, screen: screen)))
    }

    @MainActor
    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }

    @MainActor
    func testFileDropsDeduplicateAndRemovingOrClosingNeverDeletesOriginals() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let a = directory.appendingPathComponent("first.txt"), b = directory.appendingPathComponent("second.txt")
        try Data("First original".utf8).write(to: a)
        try Data("Second original".utf8).write(to: b)
        let shelf = ShelfController()
        defer { shelf.close() }
        shelf.add(ScopedFiles([a, a]))
        XCTAssertEqual(shelf.files, [a])
        let root = try XCTUnwrap(shelf.window?.contentView)
        let destination = try XCTUnwrap(descendants(root).first { $0.registeredDraggedTypes.contains(.fileURL) })
        let drag = DragFixture(urls: [a, b])
        defer { drag.draggingPasteboard.releaseGlobally() }
        XCTAssertEqual(destination.draggingEntered(drag), .copy)
        XCTAssertEqual(destination.draggingUpdated(drag), .copy)
        XCTAssertTrue(destination.performDragOperation(drag))
        XCTAssertEqual(shelf.files, [a, b])
        drag.draggingSourceOperationMask = .move
        XCTAssertEqual(destination.draggingEntered(drag), [])
        XCTAssertEqual(destination.draggingUpdated(drag), [])
        XCTAssertFalse(destination.performDragOperation(drag))
        let remote = DragFixture(urls: [try XCTUnwrap(URL(string: "https://example.com/file.png"))])
        defer { remote.draggingPasteboard.releaseGlobally() }
        XCTAssertEqual(destination.draggingEntered(remote), [])
        XCTAssertFalse(destination.performDragOperation(remote))
        let writer = try XCTUnwrap(shelf.tableView(NSTableView(), pasteboardWriterForRow: 1) as? NSURL)
        XCTAssertEqual(writer as URL, b)
        shelf.removeFiles(at: IndexSet([1, 100]))
        XCTAssertEqual(shelf.files, [a])
        let clear = try XCTUnwrap(descendants(root).compactMap { $0 as? NSButton }
            .first { $0.toolTip == L10n.text("Clear Shelf") })
        clear.performClick(nil)
        XCTAssertTrue(shelf.files.isEmpty)
        shelf.add(ScopedFiles([a, b]))
        shelf.close()
        XCTAssertTrue(shelf.files.isEmpty)
        XCTAssertEqual(try Data(contentsOf: a), Data("First original".utf8))
        XCTAssertEqual(try Data(contentsOf: b), Data("Second original".utf8))
    }

    @MainActor
    func testReduceTransparencyReplacesMaterialWithoutLosingReferencesOrDragView() throws {
        _ = NSApplication.shared
        let shelf = ShelfController()
        defer { shelf.close() }
        let url = URL(fileURLWithPath: "/tmp/Shelf-reference.txt")
        shelf.add(ScopedFiles([url]))
        let table = try XCTUnwrap(descendants(try XCTUnwrap(shelf.window?.contentView)).compactMap { $0 as? NSTableView }.first)
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        shelf.setMaterial(reduceTransparency: true)
        XCTAssertTrue(shelf.window?.contentView is NSBox)
        XCTAssertTrue(descendants(try XCTUnwrap(shelf.window?.contentView)).contains { $0 === table })
        shelf.setMaterial(reduceTransparency: false)
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) { XCTAssertTrue(shelf.window?.contentView is NSGlassEffectView) }
        else { XCTAssertTrue(shelf.window?.contentView is NSVisualEffectView) }
        #else
        XCTAssertTrue(shelf.window?.contentView is NSVisualEffectView)
        #endif
        XCTAssertEqual(shelf.files, [url])
        XCTAssertEqual(table.selectedRowIndexes, IndexSet(integer: 0))
        XCTAssertFalse(try XCTUnwrap(shelf.window).isOpaque)
        XCTAssertTrue(try XCTUnwrap(shelf.window).canBecomeKey)
        XCTAssertFalse(try XCTUnwrap(shelf.window as? NSPanel).hidesOnDeactivate)
    }

    @MainActor
    func testShelfRendersAllFiveLanguagesLightDarkAndEmptyStates() throws {
        _ = NSApplication.shared
        let previous = L10n.language
        defer { L10n.language = previous }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let output = root.appendingPathComponent(".build/shelf-preview", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Design files", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
        let photo = directory.appendingPathComponent("Mountain light.png")
        let image = NSImage(size: NSSize(width: 160, height: 120), flipped: false) { rect in
            NSGradient(starting: .systemTeal, ending: .systemIndigo)?.draw(in: rect, angle: -35)
            NSColor.systemOrange.setFill()
            NSBezierPath(ovalIn: NSRect(x: 95, y: 65, width: 32, height: 32)).fill()
            return true
        }
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: photo)
        let note = directory.appendingPathComponent("Project notes — 100% café.md")
        try Data("# Notes".utf8).write(to: note)

        for (theme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let shelf = ShelfController()
            defer { shelf.close() }
            shelf.window?.appearance = NSAppearance(named: appearance)
            shelf.add(ScopedFiles([photo, note]))
            // WindowServer composites glass/vibrancy; bitmap layout checks use the actual opaque fallback.
            shelf.setMaterial(reduceTransparency: true)
            func render(_ name: String) throws {
                let surface = try XCTUnwrap(shelf.window?.contentView)
                surface.layoutSubtreeIfNeeded()
                RunLoop.current.run(until: Date().addingTimeInterval(0.12))
                surface.layoutSubtreeIfNeeded()
                shelf.window?.displayIfNeeded()
                let view = surface
                let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: rep)
                let pixels = Data(bytes: try XCTUnwrap(rep.bitmapData), count: rep.bytesPerRow * rep.pixelsHigh)
                let colors = Set(stride(from: 0, to: pixels.count - 3, by: 32).map { Array(pixels[$0..<$0 + 3]) })
                XCTAssertGreaterThan(colors.count, 8, "A blank material mask is not a rendered shelf: \(name)")
                let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
                XCTAssertGreaterThan(png.count, 2500, name)
                try png.write(to: output.appendingPathComponent(name + ".png"))
                let table = try XCTUnwrap(descendants(view).compactMap { $0 as? NSTableView }.first)
                XCTAssertEqual(table.backgroundColor, .clear)
                if !shelf.files.isEmpty {
                    let cell = try XCTUnwrap(table.view(atColumn: 0, row: 0, makeIfNecessary: true) as? NSTableCellView)
                    XCTAssertFalse(try XCTUnwrap(cell.textField).stringValue.isEmpty)
                    XCTAssertGreaterThan(try XCTUnwrap(cell.textField).frame.width, 150)
                }
            }
            for language in AppLanguage.allCases {
                L10n.language = language
                shelf.refreshLanguage()
                try render("\(language.rawValue)-files-\(theme)")
            }
            L10n.language = .english
            shelf.refreshLanguage()
            shelf.setMaterial(reduceTransparency: true)
            let selectedTable = try XCTUnwrap(descendants(try XCTUnwrap(shelf.window?.contentView)).compactMap { $0 as? NSTableView }.first)
            selectedTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            let selectedRow = try XCTUnwrap(selectedTable.rowView(atRow: 0, makeIfNecessary: true))
            selectedRow.isEmphasized = true
            XCTAssertEqual(selectedRow.interiorBackgroundStyle, .normal,
                           "Translucent selection must retain readable normal label colors")
            try render("en-solid-\(theme)")
            shelf.removeFiles(at: IndexSet(shelf.files.indices))
            try render("en-empty-\(theme)")
            shelf.add(ScopedFiles([photo]))
            try render("en-single-\(theme)")
            shelf.add(ScopedFiles((1...7).map { directory.appendingPathComponent("Reference \($0).txt") }))
            try render("en-long-\(theme)")
            XCTAssertEqual(shelf.window?.frame.height, ShelfController.contentSize(fileCount: 5).height)
            let scroll = try XCTUnwrap(descendants(try XCTUnwrap(shelf.window?.contentView)).compactMap { $0 as? NSScrollView }.first)
            XCTAssertGreaterThan(try XCTUnwrap(scroll.documentView).frame.height, scroll.contentSize.height)
        }
    }
}
