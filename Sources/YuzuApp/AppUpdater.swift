import AppKit
import Combine
import Sparkle

/// Both entry points share Sparkle's session, signature checks, and installation UI.
@MainActor
final class AppUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    private(set) var controller: SPUStandardUpdaterController!
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var installationWaiting = false
    var canRestart: () -> Bool = { true }
    var onWillRestart: () -> Void = {}
    var onUpdateCycleFinished: () -> Void = {}
    private var pendingInstallation: (() -> Void)?

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }

    func start() {
        // SwiftPM runs have no signed app bundle, feed, or installer service to update.
        guard Bundle.main.bundleIdentifier == "com.stpashik.yuzu-converter" else { return }
        controller.startUpdater()
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
                 untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        postponeInstallationIfNeeded(installHandler)
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        finishUpdateCycle()
    }

    func finishUpdateCycle() {
        // A cancelled or failed install must not leave a stale restart handler or disable file dragging.
        pendingInstallation = nil
        installationWaiting = false
        onUpdateCycleFinished()
    }

    func postponeInstallationIfNeeded(_ installHandler: @escaping () -> Void) -> Bool {
        guard !canRestart() else { onWillRestart(); return false }
        // Finish the existing file queue before Sparkle asks the application to terminate.
        pendingInstallation = installHandler
        installationWaiting = true
        return true
    }

    func resumeInstallationIfReady() {
        guard canRestart(), let install = pendingInstallation else { return }
        pendingInstallation = nil
        installationWaiting = false
        onWillRestart()
        install()
    }
}
