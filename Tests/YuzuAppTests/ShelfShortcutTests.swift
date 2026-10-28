import AppKit
import Carbon
import XCTest
@testable import YuzuApp

final class ShelfShortcutTests: XCTestCase {
    func testShortcutValidationDoesNotCaptureTypingOrModifierOnlyKeys() throws {
        XCTAssertEqual(ShelfShortcut.default.flags, [.command, .shift])
        XCTAssertNil(ShelfShortcut(keyCode: UInt16(kVK_ANSI_C), modifiers: .command))
        XCTAssertNil(ShelfShortcut(keyCode: UInt16(kVK_ANSI_C), modifiers: [.option, .shift]))
        for key in [kVK_Command, kVK_Shift, kVK_CapsLock, kVK_Escape, kVK_Delete, kVK_Return, kVK_Tab] {
            XCTAssertNil(ShelfShortcut(keyCode: UInt16(key), modifiers: [.command, .control]))
        }
        let value = try XCTUnwrap(ShelfShortcut(keyCode: UInt16(kVK_Space), modifiers: [.control, .option, .capsLock, .function]))
        XCTAssertEqual(value.flags, [.control, .option])
        XCTAssertEqual(value.carbonModifiers, UInt32(controlKey | optionKey))
        let invalid = try JSONDecoder().decode(ShelfShortcut.self, from: Data(#"{"keyCode":8,"modifiers":0}"#.utf8))
        XCTAssertFalse(invalid.isValid)
    }

    @MainActor
    func testNativeRegistrationReportsConflictsAndPreservesThePreviousPreference() throws {
        _ = NSApplication.shared
        let domain = "YuzuShortcutTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        let otherDomain = domain + ".other"
        let otherDefaults = try XCTUnwrap(UserDefaults(suiteName: otherDomain))
        defer { defaults.removePersistentDomain(forName: domain); otherDefaults.removePersistentDomain(forName: otherDomain) }
        let first = ShelfShortcutController(defaults: defaults)
        let second = ShelfShortcutController(defaults: otherDefaults)
        defer { first.setEnabled(false); second.setEnabled(false) }
        let value = try XCTUnwrap(ShelfShortcut(keyCode: UInt16(kVK_F20), modifiers: [.command, .control, .option, .shift]))
        XCTAssertTrue(first.update(value))
        first.setEnabled(true)
        XCTAssertNil(first.errorMessage)
        XCTAssertFalse(second.update(value))
        XCTAssertEqual(second.shortcut, .default)
        XCTAssertNotNil(second.errorMessage)
        XCTAssertNil(otherDefaults.data(forKey: "shelfShortcut"))
        let otherValue = try XCTUnwrap(ShelfShortcut(keyCode: UInt16(kVK_F19), modifiers: [.command, .control, .option, .shift]))
        XCTAssertTrue(second.update(otherValue))
        second.setEnabled(true)
        XCTAssertNil(second.errorMessage)
        XCTAssertFalse(first.update(otherValue))
        XCTAssertEqual(first.shortcut, value)
        XCTAssertFalse(second.update(value))
        XCTAssertEqual(second.shortcut, otherValue)
        first.setEnabled(false)
        XCTAssertTrue(second.update(value))
        XCTAssertEqual(ShelfShortcutController(defaults: otherDefaults).shortcut, value)
        XCTAssertTrue(second.update(nil))
        XCTAssertNil(ShelfShortcutController(defaults: otherDefaults).shortcut)
        otherDefaults.set(Data("broken".utf8), forKey: "shelfShortcut")
        XCTAssertEqual(ShelfShortcutController(defaults: otherDefaults).shortcut, .default)
    }

    @MainActor
    func testRecorderSupportsCancelReplacementDisableAndInvalidKeys() throws {
        _ = NSApplication.shared
        let domain = "YuzuShortcutTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let controller = ShelfShortcutController(defaults: defaults)
        let button = ShelfShortcutButton(controller: controller)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 240, height: 80),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = button
        func key(_ code: Int, _ flags: NSEvent.ModifierFlags = []) throws {
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "",
                isARepeat: false, keyCode: UInt16(code)))
            button.keyDown(with: event)
        }
        button.performClick(nil)
        XCTAssertTrue(button.isRecording)
        try key(kVK_Escape)
        XCTAssertFalse(button.isRecording)
        XCTAssertEqual(controller.shortcut, .default)
        button.performClick(nil)
        try key(kVK_ANSI_A)
        XCTAssertTrue(button.isRecording)
        XCTAssertNotNil(controller.errorMessage)
        try key(kVK_F19, [.command, .control, .option, .shift])
        XCTAssertFalse(button.isRecording)
        XCTAssertEqual(controller.shortcut?.keyCode, UInt16(kVK_F19))
        XCTAssertEqual(button.title, "⌃⌥⇧⌘F19")
        button.performClick(nil)
        try key(kVK_Delete)
        XCTAssertFalse(button.isRecording)
        XCTAssertNil(controller.shortcut)
        XCTAssertNil(ShelfShortcutController(defaults: defaults).shortcut)
        button.performClick(nil)
        _ = button.resignFirstResponder()
        XCTAssertFalse(button.isRecording)
    }

    func testFinderDescriptorParsingRejectsNonFilesAndKeepsUnicodePaths() throws {
        let url = URL(fileURLWithPath: "/tmp/Yuzu 100% café/файл.png")
        let list = NSAppleEventDescriptor.list()
        list.insert(NSAppleEventDescriptor(fileURL: url), at: 1)
        list.insert(NSAppleEventDescriptor(fileURL: url), at: 2)
        XCTAssertEqual(try FinderSelection.urls(from: list), [url])
        list.insert(NSAppleEventDescriptor(string: "not a file"), at: 3)
        XCTAssertThrowsError(try FinderSelection.urls(from: list))
        XCTAssertThrowsError(try FinderSelection.urls(from: .list()))
        XCTAssertThrowsError(try FinderSelection.urls(from: NSAppleEventDescriptor(string: url.path)))
        let remote = NSAppleEventDescriptor.list()
        remote.insert(try XCTUnwrap(NSAppleEventDescriptor(descriptorType: typeFileURL,
            data: Data("https://example.com/photo.png".utf8))), at: 1)
        XCTAssertThrowsError(try FinderSelection.urls(from: remote))

        let original = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("alias target".utf8).write(to: original)
        defer { try? FileManager.default.removeItem(at: original) }
        let aliases = NSAppleEventDescriptor.list()
        aliases.insert(try XCTUnwrap(NSAppleEventDescriptor(fileURL: original).coerce(toDescriptorType: typeAlias)), at: 1)
        XCTAssertEqual(try FinderSelection.urls(from: aliases).map { $0.resolvingSymlinksInPath() },
                       [original.resolvingSymlinksInPath()])
    }

    @MainActor
    func testShelfAuthorizationPreservesReadableFilesWithoutOpeningAPanel() throws {
        let domain = "YuzuShortcutTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("original".utf8).write(to: file)
        defer { defaults.removePersistentDomain(forName: domain); try? FileManager.default.removeItem(at: file) }
        let store = AccessStore(defaults: defaults)
        let files = try XCTUnwrap(store.shelfFiles([file]))
        XCTAssertEqual(files.urls, [file])
        XCTAssertEqual(try Data(contentsOf: file), Data("original".utf8))
        XCTAssertTrue(store.folders.isEmpty)
        XCTAssertThrowsError(try store.shelfFiles([URL(string: "https://example.com/photo.png")!]))
    }
}
