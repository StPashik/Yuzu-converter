import AppKit
import Combine
import Sparkle

/// Startup and manual checks share Sparkle's session, signature checks, and installation UI.
@MainActor
final class AppUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    private(set) var controller: SPUStandardUpdaterController!
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var installationWaiting = false
    @Published private(set) var automaticallyChecksForUpdates = false
    private var started = false
    var canRestart: () -> Bool = { true }
    var onWillRestart: () -> Void = {}
    var onUpdateCycleFinished: () -> Void = {}
    private var pendingInstallation: (() -> Void)?

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$automaticallyChecksForUpdates)
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }

    func start() {
        // SwiftPM runs have no signed app bundle, feed, or installer service to update.
        guard Bundle.main.bundleIdentifier == "com.stpashik.yuzu-converter", !started else { return }
        controller.startUpdater()
        guard controller.updater.canCheckForUpdates else { return }
        started = true
        // Sparkle permits a launch check here before its scheduler starts; background checks stay quiet when current/offline.
        if controller.updater.automaticallyChecksForUpdates { controller.updater.checkForUpdatesInBackground() }
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        // Persist through Sparkle so its reminder schedule and the Settings checkbox share one preference.
        controller.updater.automaticallyChecksForUpdates = enabled
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
