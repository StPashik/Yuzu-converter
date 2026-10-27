import AppKit
import Sparkle

/// Exercises Sparkle's real HTTP/signature/version path without downloading or installing an app.
@MainActor
final class FeedProbe: NSObject, SPUUpdaterDelegate {
    var expected = ""
    var expectedBuild = ""
    private var updater: SPUUpdater!

    func start(bundle: Bundle) throws {
        let driver = SPUStandardUserDriver(hostBundle: bundle, delegate: nil)
        updater = SPUUpdater(hostBundle: bundle, applicationBundle: bundle, userDriver: driver, delegate: self)
        try updater.start()
        updater.checkForUpdateInformation()
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        complete("available", valid: item.versionString == expectedBuild)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) { complete("current") }
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) { complete("error") }

    private func complete(_ result: String, valid: Bool = true) {
        print("Sparkle probe: \(result)")
        exit(result == expected && valid ? 0 : 1)
    }
}

@main
enum ProbeMain {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 4, let bundle = Bundle(path: CommandLine.arguments[1]) else {
            fatalError("Usage: FeedProbe app expected-result build-number")
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let probe = FeedProbe()
        probe.expected = CommandLine.arguments[2]
        probe.expectedBuild = CommandLine.arguments[3]
        try probe.start(bundle: bundle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { fputs("Sparkle probe timed out\n", stderr); exit(2) }
        withExtendedLifetime(probe) { app.run() }
    }
}
