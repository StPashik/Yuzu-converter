import AppKit
import SwiftUI

@MainActor
final class Settings: ObservableObject {
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
        swapModifiers ? "⌃ Конвертация · ⇧ Actions" : "⇧ Конвертация · ⌃ Actions"
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 330),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Yuzu Converter — настройки"
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
        VStack(alignment: .leading, spacing: 18) {
            Label("Yuzu Converter", systemImage: "arrow.triangle.2.circlepath")
                .font(.title2.bold())
            Text("Перетащите файл и нажмите клавишу. Отпустите файл над нужным сектором.")
                .foregroundStyle(.secondary)
            Toggle("Включить колёса", isOn: $settings.wheelsEnabled)
            Toggle("Поменять Shift и Control местами", isOn: $settings.swapModifiers)
            Text(settings.shortcutDescription).font(.callout.monospaced())
            Toggle("Добавлять файлы в существующую полку", isOn: $settings.addToShelf)
            Text("Escape отменяет выбор. Результаты сохраняются рядом с оригиналом под свободным именем.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 440, height: 330)
    }
}
