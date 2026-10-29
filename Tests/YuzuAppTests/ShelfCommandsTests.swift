import AppKit
import XCTest
import YuzuCore
@testable import YuzuApp

final class ShelfCommandsTests: XCTestCase {
    @MainActor private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }

    @MainActor
    func testShelfDragRunsWheelConversionAndRetainsOriginalBatchAfterRemoval() async throws {
        _ = NSApplication.shared
        let domain = "ShelfWheelTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let actions = ActionController(access: AccessStore(defaults: defaults), settings: Settings(defaults: defaults))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("Shelf note.txt")
        try Data("Original shelf content".utf8).write(to: source)
        var original: ScopedFiles? = ScopedFiles([source])
        weak var batch = original
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))
        actions.perform(.float, files: try XCTUnwrap(original))
        original = nil
        let shelf = try XCTUnwrap(NSApp.windows.first { !before.contains(ObjectIdentifier($0)) }?.delegate as? ShelfController)
        defer { shelf.close() }
        let root = try XCTUnwrap(shelf.window?.contentView)
        root.layoutSubtreeIfNeeded()
        XCTAssertTrue(descendants(root).compactMap { $0 as? NSPopUpButton }.isEmpty)
        let table = try XCTUnwrap(descendants(root).compactMap { $0 as? NSTableView }.first)
        let cell = try XCTUnwrap(table.view(atColumn: 0, row: 0, makeIfNecessary: true))
        cell.layoutSubtreeIfNeeded()
        let buttons = descendants(cell).compactMap { $0 as? NSButton }
        let reveal = try XCTUnwrap(buttons.first { $0.toolTip?.hasPrefix(L10n.text("Show in Finder") + ":") == true })
        let remove = try XCTUnwrap(buttons.first { $0.toolTip?.hasPrefix(L10n.text("Remove from Shelf") + ":") == true })
        XCTAssertLessThan(reveal.frame.maxX, remove.frame.minX)
        XCTAssertNotNil(reveal.action)
        let writer = try XCTUnwrap(shelf.tableView(table, pasteboardWriterForRow: 0) as? NSURL)
        let drag = DragFixture(urls: [writer as URL])
        drag.draggingSource = table
        defer { drag.draggingPasteboard.releaseGlobally() }
        let wheel = WheelDragView(frame: NSRect(x: 0, y: 0, width: 320, height: 320))
        wheel.onSources = { _, view in view.options = [.conversion(.md)] }
        var requestFiles: ScopedFiles?
        wheel.onDrop = { urls, option in
            XCTAssertEqual(option, .conversion(.md))
            requestFiles = actions.scopedFiles(urls)
        }
        XCTAssertEqual(wheel.draggingEntered(drag), .copy)
        drag.draggingLocation = NSPoint(x: 160, y: 264)
        XCTAssertEqual(wheel.draggingUpdated(drag), .copy)
        XCTAssertTrue(wheel.prepareForDragOperation(drag))
        XCTAssertTrue(wheel.performDragOperation(drag))
        shelf.removeFiles(at: IndexSet(integer: 0))
        shelf.close()
        XCTAssertNotNil(batch, "The wheel job must keep the original shelf's parent scope alive")
        let queue = JobQueue()
        queue.enqueue(JobRequest(files: try XCTUnwrap(requestFiles), kind: .conversion(.md), destinations: [directory]))
        requestFiles = nil
        await queue.waitForCurrentJob()
        XCTAssertEqual(queue.entries.first?.state, .completed)
        XCTAssertEqual(queue.entries.first?.outputs.map(\.lastPathComponent), ["Shelf note.md"])
        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("Shelf note.md")), "Original shelf content")
        XCTAssertEqual(try String(contentsOf: source), "Original shelf content")
        for action in FileAction.allCases {
            wheel.mode = .actions
            wheel.onSources = { _, view in view.options = [.action(action)] }
            wheel.onDrop = { _, option in XCTAssertEqual(option, .action(action)) }
            drag.draggingLocation = NSPoint(x: 160, y: 160)
            XCTAssertEqual(wheel.draggingEntered(drag), .copy)
            drag.draggingLocation = NSPoint(x: 160, y: 264)
            XCTAssertEqual(wheel.draggingUpdated(drag), .copy)
            XCTAssertTrue(wheel.performDragOperation(drag))
        }
    }

    @MainActor
    func testContextMenuOnlyRemovesReferencesAndSelectsTheClickedRow() throws {
        _ = NSApplication.shared
        let shelf = ShelfController()
        defer { shelf.close() }
        shelf.add(ScopedFiles([URL(fileURLWithPath: "/tmp/first.txt"), URL(fileURLWithPath: "/tmp/second.txt")]))
        let root = try XCTUnwrap(shelf.window?.contentView)
        root.layoutSubtreeIfNeeded()
        let table = try XCTUnwrap(descendants(root).compactMap { $0 as? NSTableView }.first)
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        let row = table.convert(NSPoint(x: 30, y: table.rect(ofRow: 1).midY), to: nil)
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: row, modifierFlags: [],
            timestamp: 0, windowNumber: shelf.window?.windowNumber ?? 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        let menu = try XCTUnwrap(table.menu(for: event))
        XCTAssertEqual(table.selectedRowIndexes, IndexSet(integer: 1))
        XCTAssertEqual(menu.items.map(\.title), [L10n.text("Remove from Shelf")])
        XCTAssertTrue(menu.items.allSatisfy { $0.submenu == nil })
        let outside = table.convert(NSPoint(x: -20, y: -20), to: nil)
        let emptyEvent = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: outside, modifierFlags: [],
            timestamp: 0, windowNumber: shelf.window?.windowNumber ?? 0, context: nil, eventNumber: 2, clickCount: 1, pressure: 1))
        _ = table.menu(for: emptyEvent)
        XCTAssertTrue(table.selectedRowIndexes.isEmpty)
        XCTAssertTrue(try XCTUnwrap(table.menu).items.allSatisfy { !$0.isEnabled })
    }
}
