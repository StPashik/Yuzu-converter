import AppKit
import ServiceManagement
import XCTest
@testable import YuzuApp

final class SystemPreferencesTests: XCTestCase {
    func testAncestorGrantContainsOnlyItsRealDescendants() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let granted = root.appendingPathComponent("allowed", isDirectory: true)
        let nested = granted.appendingPathComponent("nested", isDirectory: true)
        let sibling = root.appendingPathComponent("allowed-other", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertTrue(AccessStore.contains(granted.appendingPathComponent("photo.png"), in: granted))
        XCTAssertTrue(AccessStore.contains(nested.appendingPathComponent("photo.png"), in: granted))
        XCTAssertTrue(AccessStore.contains(nested.appendingPathComponent("photo.png"), in: URL(fileURLWithPath: "/")))
        XCTAssertFalse(AccessStore.contains(sibling.appendingPathComponent("photo.png"), in: granted))
        XCTAssertFalse(AccessStore.contains(root.appendingPathComponent("photo.png"), in: granted))
        XCTAssertFalse(AccessStore.contains(URL(string: "https://example.com/photo.png")!, in: granted))

        let escape = granted.appendingPathComponent("escape", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: escape, withDestinationURL: sibling)
        XCTAssertFalse(AccessStore.contains(escape.appendingPathComponent("photo.png"), in: granted))
        let alias = root.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: granted)
        XCTAssertTrue(AccessStore.contains(nested.appendingPathComponent("photo.png"), in: alias))
    }

    @MainActor
    func testRememberedFolderListAndRemovalUseOnlyTheInjectedDefaults() throws {
        let suite = "YuzuSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["/tmp/Yuzu/Allowed": Data([0]), "/tmp/Yuzu/Other": Data([1]),
                      "relative": Data([2]), "/tmp/invalid": "not bookmark data"] as [String: Any],
                     forKey: "outputBookmarks")
        defaults.set("keep", forKey: "unrelated")
        let store = AccessStore(defaults: defaults)
        XCTAssertEqual(store.folders.map(\.path), ["/tmp/Yuzu/Allowed", "/tmp/Yuzu/Other"])
        store.forgetFolder(URL(fileURLWithPath: "/tmp/Yuzu/Allowed", isDirectory: true))
        XCTAssertEqual(store.folders.map(\.path), ["/tmp/Yuzu/Other"])
        XCTAssertNil(defaults.dictionary(forKey: "outputBookmarks")?["/tmp/Yuzu/Allowed"])
        XCTAssertEqual(defaults.string(forKey: "unrelated"), "keep")
        XCTAssertEqual(AccessStore(defaults: defaults).folders.map(\.path), ["/tmp/Yuzu/Other"])
    }

    @MainActor
    func testDeveloperTestBundleCannotRegisterItselfAtLogin() {
        let login = LoginItemController()
        XCTAssertFalse(login.isAvailable)
        XCTAssertEqual(login.status, .notFound)
        login.setEnabled(true)
        XCTAssertFalse(login.isRequested)
        XCTAssertFalse(login.isEnabled)
        XCTAssertNotNil(login.errorMessage)
    }

    func testTerminalChoicesHaveStableNativeApplicationIdentifiers() {
        XCTAssertEqual(TerminalApplication.terminal.bundleIdentifier, "com.apple.Terminal")
        XCTAssertEqual(TerminalApplication.iTerm2.bundleIdentifier, "com.googlecode.iterm2")
        XCTAssertEqual(Set(TerminalApplication.allCases.map(\.id)).count, 2)
        XCTAssertEqual(TerminalApplication(rawValue: "iTerm2"), .iTerm2)
    }
}
