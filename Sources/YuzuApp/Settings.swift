import AppKit
import SwiftUI

@MainActor
final class Settings: ObservableObject {
    @Published var language = L10n.language {
        didSet { L10n.language = language }
    }
    @Published var wheelsEnabled = UserDefaults.standard.object(forKey: "wheelsEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(wheelsEnabled, forKey: "wheelsEnabled") }
    }
    @Published var swapModifiers = UserDefaults.standard.bool(forKey: "swapModifiers") {
        didSet { UserDefaults.standard.set(swapModifiers, forKey: "swapModifiers") }
    }
    @Published var addToShelf = UserDefaults.standard.object(forKey: "addToShelf") as? Bool ?? true {
        didSet { UserDefaults.standard.set(addToShelf, forKey: "addToShelf") }
    }
    private var window: NSWindow?

    var shortcutDescription: String {
        let convert = L10n.text("Convert"), actions = L10n.text("Actions")
        return swapModifiers ? "⌃ \(convert) · ⇧ \(actions)" : "⇧ \(convert) · ⌃ \(actions)"
    }

    func refreshLanguage() { window?.title = L10n.text("Yuzu Converter Settings") }

    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = L10n.text("Yuzu Converter Settings")
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(settings: self))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Yuzu Converter", systemImage: "arrow.triangle.2.circlepath")
                .font(.title2.bold())
            Text(L10n.text("Drag a file and hold a shortcut key. Drop it on the action or format you need."))
                .foregroundStyle(.secondary)
            Toggle(L10n.text("Enable wheels"), isOn: $settings.wheelsEnabled)
            Toggle(L10n.text("Swap Shift and Control"), isOn: $settings.swapModifiers)
            Text(settings.shortcutDescription).font(.callout.monospaced())
            Picker(L10n.text("Language"), selection: $settings.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.name).tag(language)
                }
            }
            Text(L10n.text("Some system dialogs use the new language after restarting the app."))
                .font(.caption).foregroundStyle(.secondary)
            Toggle(L10n.text("Add files to the existing floating shelf"), isOn: $settings.addToShelf)
            Text(L10n.text("Escape cancels selection. Results are saved beside the original under an available name."))
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 480, height: 420)
    }
}
