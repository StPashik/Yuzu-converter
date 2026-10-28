import AppKit
import QuartzCore
import SwiftUI
import XCTest
import YuzuCore
@testable import YuzuApp

final class SettingsTests: XCTestCase {
    private func preferences() throws -> (UserDefaults, String) {
        let name = "YuzuSettingsTests." + UUID().uuidString
        return (try XCTUnwrap(UserDefaults(suiteName: name)), name)
    }

    @MainActor
    func testLegacyShortcutMigrationAndConflictsKeepBothWheelsReachable() throws {
        let (defaults, domain) = try preferences()
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: "swapModifiers")
        defaults.set(false, forKey: "wheelsEnabled")
        defaults.set(false, forKey: "addToShelf")
        let settings = Settings(defaults: defaults)
        XCTAssertEqual(settings.conversionModifier, .control)
        XCTAssertEqual(settings.actionsModifier, .shift)
        XCTAssertFalse(settings.wheelsEnabled)
        XCTAssertFalse(settings.addToShelf)
        settings.setModifier(.shift, for: .conversion)
        XCTAssertEqual(settings.actionsModifier, .control)
        settings.setModifier(.controlOption, for: .actions)
        let reloaded = Settings(defaults: defaults)
        XCTAssertEqual(reloaded.conversionModifier, .shift)
        XCTAssertEqual(reloaded.actionsModifier, .controlOption)
        XCTAssertNotEqual(reloaded.conversionModifier, reloaded.actionsModifier)
        XCTAssertEqual(Set(DragModifier.allCases.map(\.flags.rawValue)).count, 15)
        XCTAssertTrue(DragModifier.allCases.allSatisfy { !$0.flags.isEmpty })
        XCTAssertTrue(settings.shortcutDescription.contains(settings.conversionModifier.symbols))
    }

    @MainActor
    func testProfilesPersistSnapshotAndResetOnlyTheSelectedOutput() throws {
        let (defaults, domain) = try preferences()
        defer { defaults.removePersistentDomain(forName: domain) }
        let settings = Settings(defaults: defaults)
        let jpeg = ConversionOptions(quality: .compact, preserveMetadata: false)
        let zip = ConversionOptions(compression: .maximum)
        settings.setOptions(jpeg, for: .jpg)
        settings.setOptions(zip, for: .zip)
        let queued = settings.options(for: .jpg)
        settings.setOptions(ConversionOptions(quality: .high), for: .jpg)
        XCTAssertEqual(queued, jpeg)
        let reloaded = Settings(defaults: defaults)
        XCTAssertEqual(reloaded.options(for: .jpg).quality, .high)
        XCTAssertEqual(reloaded.options(for: .zip), zip)
        reloaded.resetOptions(for: .jpg)
        XCTAssertEqual(reloaded.options(for: .jpg), ConversionOptions())
        XCTAssertEqual(Settings(defaults: defaults).options(for: .zip), zip)
    }

    @MainActor
    func testMalformedPreferencesFallBackWithoutDuplicateShortcuts() throws {
        let (defaults, domain) = try preferences()
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(Data("invalid JSON".utf8), forKey: "conversionProfiles")
        defaults.set("shift", forKey: "conversionModifier")
        defaults.set("shift", forKey: "actionsModifier")
        defaults.set("unknown app", forKey: "terminalApplication")
        let settings = Settings(defaults: defaults)
        XCTAssertNotEqual(settings.conversionModifier, settings.actionsModifier)
        XCTAssertEqual(settings.options(for: .jpg), ConversionOptions())
        XCTAssertEqual(settings.terminalApplication, .terminal)
    }

    func testModifierChordsMatchExactlyAndIgnoreCapsLock() {
        var trigger = DragTrigger()
        XCTAssertNil(trigger.update(mouseDown: true, flags: .control, escape: false, enabled: true,
                                    conversion: .controlShift, actions: .option))
        XCTAssertEqual(trigger.update(mouseDown: true, flags: [.control, .shift, .capsLock], escape: false,
                                      enabled: true, conversion: .controlShift, actions: .option), .conversion)
        XCTAssertEqual(trigger.update(mouseDown: true, flags: [], escape: false, enabled: true,
                                      conversion: .controlShift, actions: .option), .conversion)
        XCTAssertEqual(trigger.update(mouseDown: true, flags: [.option, .function], escape: false, enabled: true,
                                      conversion: .controlShift, actions: .option), .actions)
        XCTAssertNil(trigger.update(mouseDown: true, flags: .option, escape: true, enabled: true,
                                    conversion: .controlShift, actions: .option))
        XCTAssertNil(trigger.update(mouseDown: true, flags: [.control, .shift], escape: false, enabled: true,
                                    conversion: .controlShift, actions: .option))
    }

    @MainActor
    func testBackdropDoesNotInterceptDropsAndHighlightFeedbackOnlyFiresOnChanges() throws {
        _ = NSApplication.shared
        let view = WheelDragView(frame: NSRect(x: 0, y: 0, width: 320, height: 320))
        view.onSources = { _, view in view.options = FileAction.allCases.map(WheelOption.action) }
        var feedback = 0
        view.onHighlight = { feedback += 1 }
        let drag = DragFixture()
        defer { drag.draggingPasteboard.releaseGlobally() }
        XCTAssertEqual(view.draggingEntered(drag), .copy)
        drag.draggingLocation = NSPoint(x: 160, y: 264)
        XCTAssertEqual(view.draggingUpdated(drag), .copy)
        XCTAssertEqual(view.draggingUpdated(drag), .copy)
        XCTAssertEqual(feedback, 1)
        let backdrop = try XCTUnwrap(view.subviews.first { $0 is WheelMaterialView })
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) { XCTAssertTrue(backdrop.subviews.first is NSGlassEffectView) }
        else { XCTAssertTrue(backdrop.subviews.first is NSVisualEffectView) }
        #else
        XCTAssertTrue(backdrop.subviews.first is NSVisualEffectView)
        #endif
        XCTAssertNil(backdrop.hitTest(drag.draggingLocation))
        let mask = try XCTUnwrap(backdrop.layer?.mask as? CAShapeLayer)
        XCTAssertFalse(try XCTUnwrap(mask.path).contains(drag.draggingLocation))
        view.style = .solid
        XCTAssertTrue(backdrop.isHidden)
        drag.draggingLocation = NSPoint(x: 160, y: 160)
        XCTAssertEqual(view.draggingUpdated(drag), [])
        XCTAssertEqual(feedback, 1)
    }

    @MainActor
    func testSettingsRenderEverySectionLanguageAndRelevantFormatEditor() throws {
        fputs("Settings previews: initializing AppKit\n", stderr)
        _ = NSApplication.shared
        let previousLanguage = UserDefaults.standard.object(forKey: "appLanguage")
        let previousSystemLanguage = UserDefaults.standard.object(forKey: "AppleLanguages")
        let previousIcon = NSApp.applicationIconImage
        defer {
            if let previousLanguage { UserDefaults.standard.set(previousLanguage, forKey: "appLanguage") }
            else { UserDefaults.standard.removeObject(forKey: "appLanguage") }
            if let previousSystemLanguage { UserDefaults.standard.set(previousSystemLanguage, forKey: "AppleLanguages") }
            else { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
            NSApp.applicationIconImage = previousIcon
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        NSApp.applicationIconImage = NSImage(contentsOf: root.appendingPathComponent("Resources/YuzuAppIcon.icns"))
        let directory = root.appendingPathComponent(".build/settings-preview", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let (defaults, domain) = try preferences()
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(["/Users/example/Documents": Data()], forKey: "outputBookmarks")
        let settings = Settings(defaults: defaults)
        let access = AccessStore(defaults: defaults)
        let updater = AppUpdater()
        fputs("Settings previews: discovering format routes\n", stderr)
        let catalog = try SettingsView.makeCatalog()
        fputs("Settings previews: format routes ready\n", stderr)

        func render(_ name: String, format: FileFormat = .jpg, appearance: NSAppearance.Name, revealShortcut: Bool = false) throws {
            fputs("Settings preview \(name): starting\n", stderr)
            // Release offscreen SwiftUI trees between snapshots instead of retaining their drawing resources for the whole matrix.
            try autoreleasepool {
                let view = NSHostingView(rootView: SettingsView(settings: settings, updater: updater, access: access,
                                                               selectedFormat: format, catalog: catalog))
                let bounds = NSRect(x: 0, y: 0, width: 660, height: 640)
                let window = NSWindow(contentRect: bounds, styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                defer { window.contentView = nil; window.close() }
                window.appearance = NSAppearance(named: appearance)
                window.contentView = view
                view.frame = bounds
                view.layoutSubtreeIfNeeded()
                RunLoop.current.run(until: Date().addingTimeInterval(0.04))
                view.layoutSubtreeIfNeeded()
                if revealShortcut {
                    @MainActor func recorder(in view: NSView) -> ShelfShortcutButton? {
                        if let button = view as? ShelfShortcutButton { return button }
                        for child in view.subviews {
                            if let button = recorder(in: child) { return button }
                        }
                        return nil
                    }
                    let button = try XCTUnwrap(recorder(in: view))
                    let scroll = try XCTUnwrap(button.enclosingScrollView)
                    let document = try XCTUnwrap(scroll.documentView)
                    let bottom = document.isFlipped ? max(0, document.bounds.height - scroll.contentView.bounds.height) : 0
                    scroll.contentView.scroll(to: NSPoint(x: 0, y: bottom))
                    scroll.reflectScrolledClipView(scroll.contentView)
                    RunLoop.current.run(until: Date().addingTimeInterval(0.04))
                    XCTAssertGreaterThan(button.visibleRect.height, 0)
                    XCTAssertEqual(button.accessibilityLabel(), L10n.text("Add Finder selection to shelf"))
                }
                window.displayIfNeeded()
                let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                XCTAssertGreaterThan(png.count, 5000, name)
                try png.write(to: directory.appendingPathComponent(name + ".png"))
            }
            fputs("Settings preview \(name): passed\n", stderr)
        }

        for (theme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            for language in AppLanguage.allCases {
                settings.language = language
                for section in SettingsSection.allCases {
                    settings.section = section
                    try render("\(language.rawValue)-\(section.rawValue.lowercased())-\(theme)", appearance: appearance)
                    if section == .general {
                        try render("\(language.rawValue)-general-actions-\(theme)", appearance: appearance, revealShortcut: true)
                    }
                }
            }
            settings.language = .english
            settings.section = .formats
            for format in [FileFormat.m4a, .wav, .mp4, .gif, .zip, .epub, .docx] {
                try render("en-formats-\(format.rawValue)-\(theme)", format: format, appearance: appearance)
            }
        }
    }
}
