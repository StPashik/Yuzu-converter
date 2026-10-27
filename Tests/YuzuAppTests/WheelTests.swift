import AppKit
import XCTest
@testable import YuzuApp

final class WheelTests: XCTestCase {
    @MainActor
    func testYuzuPetalsShareRoundedHitRegionsAndSelectionKeepsReadableLabels() throws {
        let view = WheelDragView(frame: NSRect(x: 0, y: 0, width: 320, height: 320))
        let drag = DragFixture()
        defer { drag.draggingPasteboard.releaseGlobally() }
        view.mode = .actions
        view.onSources = { _, view in view.options = FileAction.allCases.map(WheelOption.action) }
        XCTAssertEqual(view.draggingEntered(drag), .copy)
        let buttons = view.subviews.compactMap { $0 as? NSButton }
        XCTAssertEqual(buttons.count, 7)
        XCTAssertEqual(buttons[0].frame.midX, 160, accuracy: 0.001)
        XCTAssertEqual(buttons[0].frame.midY, 264, accuracy: 0.001)
        drag.draggingLocation = NSPoint(x: 160, y: 264)
        XCTAssertEqual(view.draggingUpdated(drag), .copy)
        XCTAssertEqual(buttons[0].contentTintColor, .white)
        XCTAssertTrue(view.prepareForDragOperation(drag))
        // Switching to a smaller list while hovering must not index the old button array.
        view.options = [.conversion(.jpg), .conversion(.pdf), .conversion(.tiff)]
        XCTAssertTrue(view.subviews.compactMap { $0 as? NSButton }.allSatisfy { $0.image == nil })
        let center = CGPoint(x: 160, y: 160)
        let corner = CGPoint(x: center.x + cos(.pi / 3 + 0.035) * 143,
                             y: center.y + sin(.pi / 3 + 0.035) * 143)
        XCTAssertNil(WheelGeometry.selection(at: corner, count: 6, center: center))
    }

    @MainActor
    func testWheelRendersBothModesAndThemes() throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/wheel-preview", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            for mode in [WheelMode.conversion, .actions] {
                let view = WheelDragView(frame: NSRect(x: 0, y: 0, width: 320, height: 320))
                view.appearance = NSAppearance(named: appearance)
                view.mode = mode
                view.onSources = { _, view in
                    view.options = mode == .actions ? FileAction.allCases.map(WheelOption.action)
                        : [.jpg, .webp, .heic, .tiff, .bmp, .pdf].map(WheelOption.conversion)
                    view.sourceCaption = mode == .actions ? "Photo.png" : "PNG"
                    view.idleCaption = mode == .actions ? "Actions" : "Convert"
                }
                let drag = DragFixture()
                defer { drag.draggingPasteboard.releaseGlobally() }
                XCTAssertEqual(view.draggingEntered(drag), .copy)
                drag.draggingLocation = NSPoint(x: 160, y: 264)
                XCTAssertEqual(view.draggingUpdated(drag), .copy)
                let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                XCTAssertGreaterThan(png.count, 1000)
                let modeName = mode == .actions ? "actions" : "conversion"
                try png.write(to: directory.appendingPathComponent("\(modeName)-\(name).png"))
            }
        }
    }

    @MainActor
    func testArmedWindowReceivesHitsBeforeAFileDragIsConfirmed() throws {
        _ = NSApplication.shared
        let monitor = WheelMonitor(settings: Settings())
        monitor.arm(.conversion)
        defer { monitor.dismiss() }

        let panel = try XCTUnwrap(NSApp.windows.first { $0.contentView is WheelDragView })
        let view = try XCTUnwrap(panel.contentView as? WheelDragView)
        XCTAssertFalse(view.confirmed)
        // Exercise WindowServer hit-testing without covering the desktop for the test.
        let point = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        panel.setFrame(NSRect(x: point.x - 40, y: point.y - 40, width: 80, height: 80), display: true)
        panel.displayIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0), panel.windowNumber,
                       "The armed window must receive drag input before it draws the wheel.")
    }

    func testOutputGrantMustBelongToTheActualSourceParent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("original.txt")
        XCTAssertTrue(AccessStore.isParent(directory, of: source))
        XCTAssertFalse(AccessStore.isParent(directory.deletingLastPathComponent(), of: source))
        let alias = directory.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: directory)
        XCTAssertTrue(AccessStore.isParent(alias, of: source))
    }

    func testTerminalFoldersDeduplicateFilesAndTreatPackagesAsFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("one.txt")
        try Data("one".utf8).write(to: file)
        let package = root.appendingPathComponent("Example.app", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        XCTAssertEqual(try ActionController.terminalFolders([file, root, package]).map(\.path), [root.path])
    }

    func testTriggerLatchesSwitchesAndEscapeSuppressesUntilRelease() {
        var trigger = DragTrigger()
        XCTAssertNil(trigger.update(mouseDown: false, flags: .shift, escape: false, enabled: true, conversion: .shift, actions: .control))
        XCTAssertEqual(trigger.update(mouseDown: true, flags: .shift, escape: false, enabled: true, conversion: .shift, actions: .control), .conversion)
        XCTAssertEqual(trigger.update(mouseDown: true, flags: [], escape: false, enabled: true, conversion: .shift, actions: .control), .conversion)
        XCTAssertEqual(trigger.update(mouseDown: true, flags: .control, escape: false, enabled: true, conversion: .shift, actions: .control), .actions)
        XCTAssertNil(trigger.update(mouseDown: true, flags: .control, escape: true, enabled: true, conversion: .shift, actions: .control))
        XCTAssertNil(trigger.update(mouseDown: true, flags: .shift, escape: false, enabled: true, conversion: .shift, actions: .control))
        XCTAssertNil(trigger.update(mouseDown: false, flags: [], escape: false, enabled: true, conversion: .shift, actions: .control))
        XCTAssertEqual(trigger.update(mouseDown: true, flags: .shift, escape: false, enabled: true, conversion: .control, actions: .shift), .actions)
        XCTAssertNil(trigger.update(mouseDown: true, flags: .shift, escape: false, enabled: false, conversion: .shift, actions: .control))
    }

    func testEverySectorUsesItsVisiblePathAndRejectsCenterAndGaps() {
        let center = CGPoint(x: 150, y: 150)
        for count in [1, 2, 3, 6, 7, 9, 12] {
            for i in 0..<count {
                let angle = WheelGeometry.angle(i, count: count)
                let point = CGPoint(x: center.x + cos(angle) * 80, y: center.y + sin(angle) * 80)
                XCTAssertEqual(WheelGeometry.selection(at: point, count: count, center: center), i)
            }
            XCTAssertNil(WheelGeometry.selection(at: center, count: count, center: center))
            XCTAssertNil(WheelGeometry.selection(at: CGPoint(x: 300, y: 300), count: count, center: center))
        }
        let gap = WheelGeometry.angle(0, count: 6) + .pi / 6
        XCTAssertNil(WheelGeometry.selection(at: CGPoint(x: center.x + cos(gap) * 80,
                                                        y: center.y + sin(gap) * 80), count: 6, center: center))
    }
}
