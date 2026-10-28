import AppKit
import XCTest
import YuzuCore
@testable import YuzuApp

final class ShelfCommandsTests: XCTestCase {
    @MainActor private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }

    @MainActor
    func testSelectedBatchCommandsRetainGrantsAndRejectStaleConversionMenus() async throws {
        _ = NSApplication.shared
        let previousLanguage = L10n.language
        L10n.language = .english
        defer { L10n.language = previousLanguage }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let directory = temporary.appendingPathComponent("Project files")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let a = directory.appendingPathComponent("first.txt"), b = directory.appendingPathComponent("second.txt")
        try Data("First content".utf8).write(to: a)
        try Data("Second content".utf8).write(to: b)
        let shelf = ShelfController()
        defer { shelf.close() }
        var first: ScopedFiles? = ScopedFiles([a]), second: ScopedFiles? = ScopedFiles([b])
        weak var firstLease = first
        weak var secondLease = second
        shelf.add(try XCTUnwrap(first)); shelf.add(try XCTUnwrap(second))
        first = nil; second = nil
        let root = try XCTUnwrap(shelf.window?.contentView)
        let table = try XCTUnwrap(descendants(root).compactMap { $0 as? NSTableView }.first)
        table.selectRowIndexes(IndexSet([0, 1]), byExtendingSelection: false)
        let deadline = Date().addingTimeInterval(5)
        while shelf.availableFormats.isEmpty && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        let expected = ConversionEngine().targets(for: try [a, b].map { try SourceFile(url: $0) })
        XCTAssertFalse(expected.isEmpty)
        XCTAssertEqual(shelf.availableFormats, expected)
        let buttons = descendants(root).compactMap { $0 as? NSPopUpButton }
        let convert = try XCTUnwrap(buttons.first { $0.menu?.items.first?.title == L10n.text("Convert") })
        let actions = try XCTUnwrap(buttons.first { $0.menu?.items.first?.title == L10n.text("Actions") })
        XCTAssertTrue(convert.isEnabled)
        shelf.refreshLanguage()
        XCTAssertEqual(table.selectedRowIndexes, IndexSet([0, 1]))
        XCTAssertTrue(actions.isEnabled)
        shelf.setMaterial(reduceTransparency: true)
        shelf.window?.appearance = NSAppearance(named: .aqua)
        root.window?.contentView?.layoutSubtreeIfNeeded()
        let surface = try XCTUnwrap(shelf.window?.contentView)
        surface.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(surface.bitmapImageRepForCachingDisplay(in: surface.bounds))
        surface.cacheDisplay(in: surface.bounds, to: bitmap)
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: project.appendingPathComponent(".build/shelf-workflow-preview.png"))

        XCTAssertEqual(actions.menu?.items.dropFirst().count, 7)
        XCTAssertEqual(actions.menu?.items.dropFirst().compactMap { $0.representedObject as? WheelOption },
                       FileAction.allCases.map(WheelOption.action))
        let conversion = try XCTUnwrap(convert.menu?.items.dropFirst().first)
        var selected: ScopedFiles?
        var requested: WheelOption?
        shelf.onRequest = { files, option in selected = files; requested = option }
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(conversion.action), to: conversion.target, from: conversion))
        XCTAssertEqual(selected?.urls, [a, b])
        XCTAssertEqual(requested, .conversion(expected[0]))
        selected = nil; requested = nil
        table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        _ = NSApp.sendAction(try XCTUnwrap(conversion.action), to: conversion.target, from: conversion)
        XCTAssertNil(selected, "A previously opened menu cannot convert a different selection")
        let copy = try XCTUnwrap(actions.menu?.items.first { ($0.representedObject as? WheelOption) == .action(.copy) })
        _ = NSApp.sendAction(try XCTUnwrap(copy.action), to: copy.target, from: copy)
        XCTAssertEqual(selected?.urls, [b])
        XCTAssertEqual(requested, .action(.copy))
        table.selectRowIndexes(IndexSet([0, 1]), byExtendingSelection: false)
        let float = try XCTUnwrap(actions.menu?.items.first { ($0.representedObject as? WheelOption) == .action(.float) })
        _ = NSApp.sendAction(try XCTUnwrap(float.action), to: float.target, from: float)
        shelf.removeFiles(at: IndexSet([0, 1]))
        shelf.close()
        XCTAssertEqual(selected?.urls, [a, b])
        XCTAssertNotNil(firstLease)
        XCTAssertNotNil(secondLease, "Queued or system Actions must outlive shelf removal")
        XCTAssertEqual(try String(contentsOf: b), "Second content")
        selected = nil
        XCTAssertFalse(actions.isEnabled)
        XCTAssertFalse(convert.isEnabled)
    }

    @MainActor
    func testContextMenuSelectsTheClickedRowAndEmptySpaceClearsSelection() throws {
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
        let menu = table.menu(for: event)
        XCTAssertEqual(table.selectedRowIndexes, IndexSet(integer: 1))
        XCTAssertEqual(menu?.items[1].submenu?.items.count, 7)
        XCTAssertEqual(menu?.items[1].submenu?.items.first { ($0.representedObject as? WheelOption) == .action(.float) }?.title,
                       L10n.text("New Shelf with Selection"))
        let outside = table.convert(NSPoint(x: -20, y: -20), to: nil)
        let emptyEvent = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: outside, modifierFlags: [],
            timestamp: 0, windowNumber: shelf.window?.windowNumber ?? 0, context: nil, eventNumber: 2, clickCount: 1, pressure: 1))
        _ = table.menu(for: emptyEvent)
        XCTAssertTrue(table.selectedRowIndexes.isEmpty)
        XCTAssertTrue(try XCTUnwrap(table.menu).items.filter { !$0.isSeparatorItem }.allSatisfy { !$0.isEnabled })
    }
}
