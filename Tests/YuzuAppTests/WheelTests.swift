import AppKit
import XCTest
@testable import YuzuApp

final class WheelTests: XCTestCase {
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
        XCTAssertNil(trigger.update(mouseDown: false, flags: .shift, escape: false, enabled: true, swapped: false))
        XCTAssertEqual(trigger.update(mouseDown: true, flags: .shift, escape: false, enabled: true, swapped: false), .conversion)
        XCTAssertEqual(trigger.update(mouseDown: true, flags: [], escape: false, enabled: true, swapped: false), .conversion)
        XCTAssertEqual(trigger.update(mouseDown: true, flags: .control, escape: false, enabled: true, swapped: false), .actions)
        XCTAssertNil(trigger.update(mouseDown: true, flags: .control, escape: true, enabled: true, swapped: false))
        XCTAssertNil(trigger.update(mouseDown: true, flags: .shift, escape: false, enabled: true, swapped: false))
        XCTAssertNil(trigger.update(mouseDown: false, flags: [], escape: false, enabled: true, swapped: false))
        XCTAssertEqual(trigger.update(mouseDown: true, flags: .shift, escape: false, enabled: true, swapped: true), .actions)
        XCTAssertNil(trigger.update(mouseDown: true, flags: .shift, escape: false, enabled: false, swapped: false))
    }

    func testEverySectorUsesItsVisiblePathAndRejectsCenterAndGaps() {
        let center = CGPoint(x: 150, y: 150)
        for count in [1, 2, 3, 6, 7, 9] {
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
