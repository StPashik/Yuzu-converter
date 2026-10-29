import AppKit
import Sparkle

/// A real Sparkle background session with a noninteractive driver; no test can authorize a download.
@MainActor
final class StartupDriver: SPUStandardUserDriver {
    var onOffer: ((SUAppcastItem, SPUUserUpdateState, @escaping (SPUUserUpdateChoice) -> Void) -> Void)?
    override func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState,
                                  reply: @escaping (SPUUserUpdateChoice) -> Void) {
        onOffer?(appcastItem, state, reply)
    }
    override func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}
    override func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        fatalError("A background no-update check must stay quiet.")
    }
    override func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        fatalError("A background network failure must stay quiet.")
    }
    override func showDownloadInitiated(cancellation: @escaping () -> Void) {
        fatalError("A startup check must never download or install without consent.")
    }
}

@MainActor
final class StartupProbe: NSObject, SPUUpdaterDelegate {
    let mode: String
    let expected: String
    let build: String
    private var updater: SPUUpdater!
    private var result = ""
    private var offered = false

    init(mode: String, expected: String, build: String) {
        self.mode = mode; self.expected = expected; self.build = build
    }

    func start(_ bundle: Bundle) throws {
        let driver = StartupDriver(hostBundle: bundle, delegate: nil)
        driver.onOffer = { [self] item, state, reply in
            precondition(item.versionString == build && item.itemDescriptionFormat == "markdown")
            precondition(item.itemDescription?.contains("PDF crop and rotation fixture.") == true)
            precondition(state.stage == .notDownloaded)
            precondition(state.userInitiated == (mode == "manual"))
            precondition(!updater.automaticallyDownloadsUpdates && updater.allowsAutomaticUpdates == false)
            offered = true
            reply(mode == "skip" ? .skip : .dismiss)
        }
        updater = SPUUpdater(hostBundle: bundle, applicationBundle: bundle, userDriver: driver, delegate: self)
        if mode == "disable" { updater.automaticallyChecksForUpdates = false }
        if mode == "enable" { updater.automaticallyChecksForUpdates = true }
        try updater.start()
        precondition(!updater.automaticallyDownloadsUpdates && updater.allowsAutomaticUpdates == false)
        if mode == "manual" { updater.checkForUpdates() }
        else if updater.automaticallyChecksForUpdates { updater.checkForUpdatesInBackground() }
        else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                precondition(!updater.sessionInProgress && !offered)
                complete("disabled")
            }
        }
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) { result = "available" }
    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) { result = "current" }
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        if result.isEmpty { result = "error" }
    }
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        precondition((result == "available") == offered)
        complete(result)
    }
    private func complete(_ value: String) {
        print("Startup Sparkle probe: \(mode) → \(value); no download or installation")
        exit(value == expected ? 0 : 1)
    }
}

@main
enum StartupProbeMain {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 5, let bundle = Bundle(path: CommandLine.arguments[1]) else {
            fatalError("Usage: StartupProbe app mode expected-result build-number")
        }
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let probe = StartupProbe(mode: CommandLine.arguments[2], expected: CommandLine.arguments[3], build: CommandLine.arguments[4])
        try probe.start(bundle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { fputs("Startup Sparkle probe timed out\n", stderr); exit(2) }
        withExtendedLifetime(probe) { app.run() }
    }
}
