import AppKit
import Combine
import ServiceManagement

enum TerminalApplication: String, CaseIterable, Identifiable {
    case terminal, iTerm2

    var id: String { rawValue }
    var name: String { self == .terminal ? "Terminal" : "iTerm2" }
    var bundleIdentifier: String { self == .terminal ? "com.apple.Terminal" : "com.googlecode.iterm2" }
}

/// The system owns login registration; a saved checkbox cannot establish authorization.
@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var status: SMAppService.Status = .notFound
    @Published private(set) var errorMessage: String?

    var isAvailable: Bool {
        Bundle.main.bundleIdentifier == "com.stpashik.yuzu-converter" && Bundle.main.bundleURL.pathExtension == "app"
    }
    var isEnabled: Bool { status == .enabled }
    var isRequested: Bool { status == .enabled || status == .requiresApproval }
    var requiresApproval: Bool { status == .requiresApproval }
    var message: String? {
        if !isAvailable { return L10n.text("Install the app in Applications to use launch at login.") }
        if requiresApproval { return L10n.text("Allow Yuzu Converter in macOS Login Items to finish setup.") }
        if let errorMessage { return L10n.text(errorMessage) }
        if status == .notFound { return L10n.text("macOS could not find this login item. Reinstall the app and try again.") }
        return nil
    }

    init() { refresh() }

    func refresh() {
        let updated = isAvailable ? SMAppService.mainApp.status : .notFound
        if updated != status { errorMessage = nil }
        status = updated
    }

    func setEnabled(_ enabled: Bool) {
        guard isAvailable else {
            errorMessage = "Install the app in Applications to use launch at login."
            return
        }
        refresh()
        guard enabled != isRequested else { return }
        errorMessage = nil
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refresh()
        } catch {
            refresh()
            errorMessage = "Could not change launch at login. Try again or open Login Items."
        }
    }

    func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }
}
