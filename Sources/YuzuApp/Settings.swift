import AppKit
import SwiftUI
import YuzuCore

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General", formats = "Formats", compatibility = "Compatibility", folders = "Folders", about = "About"
    var id: String { rawValue }
}

enum WheelStyle: String, CaseIterable, Identifiable {
    case glass = "Glass", solid = "Solid"
    var id: String { rawValue }
}

/// Only the four standard modifiers participate; Caps Lock and Fn do not change a saved shortcut.
enum DragModifier: String, CaseIterable, Identifiable {
    case shift, control, option, command
    case controlShift, optionShift, commandShift, controlOption, controlCommand, optionCommand
    case controlOptionShift, controlCommandShift, optionCommandShift, controlOptionCommand, all
    var id: String { rawValue }

    var flags: NSEvent.ModifierFlags {
        switch self {
        case .shift: return .shift
        case .control: return .control
        case .option: return .option
        case .command: return .command
        case .controlShift: return [.control, .shift]
        case .optionShift: return [.option, .shift]
        case .commandShift: return [.command, .shift]
        case .controlOption: return [.control, .option]
        case .controlCommand: return [.control, .command]
        case .optionCommand: return [.option, .command]
        case .controlOptionShift: return [.control, .option, .shift]
        case .controlCommandShift: return [.control, .command, .shift]
        case .optionCommandShift: return [.option, .command, .shift]
        case .controlOptionCommand: return [.control, .option, .command]
        case .all: return [.control, .option, .shift, .command]
        }
    }

    private var keys: [(flag: NSEvent.ModifierFlags, symbol: String, name: String)] {
        [(.control, "⌃", "Control"), (.option, "⌥", "Option"), (.shift, "⇧", "Shift"), (.command, "⌘", "Command")]
            .filter { flags.contains($0.0) }
    }
    var symbols: String { keys.map(\.symbol).joined() }
    var title: String { keys.map { L10n.text($0.name) }.joined(separator: " + ") }
    var displayName: String { keys.count == 1 ? "\(symbols) \(title)" : symbols }
}

@MainActor
final class Settings: ObservableObject {
    private let defaults: UserDefaults
    @Published var section: SettingsSection = .general
    @Published var language = L10n.language {
        didSet { L10n.language = language }
    }
    @Published var wheelsEnabled: Bool {
        didSet { defaults.set(wheelsEnabled, forKey: "wheelsEnabled") }
    }
    @Published var addToShelf: Bool {
        didSet { defaults.set(addToShelf, forKey: "addToShelf") }
    }
    @Published var wheelStyle: WheelStyle {
        didSet { defaults.set(wheelStyle.rawValue, forKey: "wheelStyle") }
    }
    @Published var soundsAndHapticsEnabled: Bool {
        didSet { defaults.set(soundsAndHapticsEnabled, forKey: "soundsAndHapticsEnabled") }
    }
    @Published var terminalApplication: TerminalApplication {
        didSet { defaults.set(terminalApplication.rawValue, forKey: "terminalApplication") }
    }
    @Published private(set) var conversionModifier: DragModifier {
        didSet { defaults.set(conversionModifier.rawValue, forKey: "conversionModifier") }
    }
    @Published private(set) var actionsModifier: DragModifier {
        didSet { defaults.set(actionsModifier.rawValue, forKey: "actionsModifier") }
    }
    @Published private(set) var profiles: [String: ConversionOptions]
    let loginItem = LoginItemController()
    let shelfShortcut: ShelfShortcutController
    private var window: NSWindow?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shelfShortcut = ShelfShortcutController(defaults: defaults)
        wheelsEnabled = defaults.object(forKey: "wheelsEnabled") as? Bool ?? true
        addToShelf = defaults.object(forKey: "addToShelf") as? Bool ?? true
        wheelStyle = defaults.string(forKey: "wheelStyle").flatMap(WheelStyle.init(rawValue:)) ?? .glass
        soundsAndHapticsEnabled = defaults.object(forKey: "soundsAndHapticsEnabled") as? Bool ?? true
        terminalApplication = defaults.string(forKey: "terminalApplication").flatMap(TerminalApplication.init(rawValue:)) ?? .terminal
        // Preserve the original preview's swapped keys when upgrading to independent shortcut pickers.
        let swapped = defaults.bool(forKey: "swapModifiers")
        let conversion = defaults.string(forKey: "conversionModifier").flatMap(DragModifier.init(rawValue:)) ?? (swapped ? .control : .shift)
        let actions = defaults.string(forKey: "actionsModifier").flatMap(DragModifier.init(rawValue:)) ?? (swapped ? .shift : .control)
        conversionModifier = conversion
        actionsModifier = actions == conversion ? (conversion == .control ? .shift : .control) : actions
        profiles = defaults.data(forKey: "conversionProfiles").flatMap {
            try? JSONDecoder().decode([String: ConversionOptions].self, from: $0)
        } ?? [:]
    }

    var shortcutDescription: String {
        "\(conversionModifier.symbols) \(L10n.text("Convert")) · \(actionsModifier.symbols) \(L10n.text("Actions"))"
    }
    var shortcutHint: String { "\(conversionModifier.symbols) / \(actionsModifier.symbols) · Esc" }

    func setModifier(_ modifier: DragModifier, for mode: WheelMode) {
        // Swapping a conflicting choice keeps both wheels reachable without another confirmation dialog.
        switch mode {
        case .conversion:
            if modifier == actionsModifier { actionsModifier = conversionModifier }
            conversionModifier = modifier
        case .actions:
            if modifier == conversionModifier { conversionModifier = actionsModifier }
            actionsModifier = modifier
        }
    }

    func options(for format: FileFormat) -> ConversionOptions { profiles[format.rawValue] ?? ConversionOptions() }

    func setOptions(_ options: ConversionOptions, for format: FileFormat) {
        var updated = profiles
        updated[format.rawValue] = options
        saveProfiles(updated)
    }

    func resetOptions(for format: FileFormat) {
        var updated = profiles
        updated.removeValue(forKey: format.rawValue)
        saveProfiles(updated)
    }

    private func saveProfiles(_ updated: [String: ConversionOptions]) {
        guard let data = try? JSONEncoder().encode(updated) else { return }
        defaults.set(data, forKey: "conversionProfiles")
        profiles = updated
    }

    func refreshLanguage() { window?.title = L10n.text("Yuzu Converter Settings") }

    func show(updater: AppUpdater, access: AccessStore) {
        loginItem.refresh()
        access.refresh()
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 640),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = L10n.text("Yuzu Converter Settings")
            window.contentMinSize = NSSize(width: 620, height: 560)
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("YuzuSettings")
            window.contentView = NSHostingView(rootView: SettingsView(settings: self, updater: updater, access: access))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
