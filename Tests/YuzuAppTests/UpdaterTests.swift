import XCTest
import Sparkle
@testable import YuzuApp

final class UpdaterTests: XCTestCase {
    func testPackagedChecksDefaultOnButDownloadsAndInstallationRequireConsent() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/Info.plist"))
        let info = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(info["SUEnableAutomaticChecks"] as? Bool, true)
        XCTAssertEqual(info["SUShowReleaseNotes"] as? Bool, true)
        XCTAssertEqual(info["SUAutomaticallyUpdate"] as? Bool, false)
        XCTAssertEqual(info["SUAllowsAutomaticUpdates"] as? Bool, false)
    }

    @MainActor
    func testUnpackagedDevelopmentDoesNotStartNetworkChecks() {
        let updater = AppUpdater()
        updater.start(); updater.start()
        XCTAssertFalse(updater.controller.updater.sessionInProgress)
        XCTAssertFalse(updater.controller.updater.canCheckForUpdates)
        XCTAssertEqual(updater.automaticallyChecksForUpdates, updater.controller.updater.automaticallyChecksForUpdates)
    }

    @MainActor
    func testInstallationWaitsForTheFileQueueAndResumesOnlyOnce() {
        let updater = AppUpdater()
        var busy = true
        var installations = 0
        var committed = false
        updater.canRestart = { !busy }
        updater.onWillRestart = { committed = true }
        XCTAssertTrue(updater.postponeInstallationIfNeeded { XCTAssertTrue(committed); installations += 1 })
        XCTAssertTrue(updater.installationWaiting)
        updater.resumeInstallationIfReady()
        XCTAssertEqual(installations, 0)
        busy = false
        updater.resumeInstallationIfReady()
        updater.resumeInstallationIfReady()
        XCTAssertEqual(installations, 1)
        XCTAssertFalse(updater.installationWaiting)
    }

    @MainActor
    func testSparkleCanCallTheRelaunchDelegate() {
        let updater = AppUpdater()
        XCTAssertTrue(updater.responds(to: #selector(SPUUpdaterDelegate.updater(_:shouldPostponeRelaunchForUpdate:untilInvokingBlock:))))
        XCTAssertTrue(updater.responds(to: #selector(SPUUpdaterDelegate.updater(_:didFinishUpdateCycleFor:error:))))
    }

    @MainActor
    func testCancelledCycleClearsThePostponedInstallerAndRestoresTheApp() {
        let updater = AppUpdater()
        var busy = true
        var restored = false
        updater.canRestart = { !busy }
        updater.onUpdateCycleFinished = { restored = true }
        XCTAssertTrue(updater.postponeInstallationIfNeeded { XCTFail("Cancelled installation must not resume") })
        updater.finishUpdateCycle()
        busy = false
        updater.resumeInstallationIfReady()
        XCTAssertFalse(updater.installationWaiting)
        XCTAssertTrue(restored)
    }

    @MainActor
    func testIdleAppLetsSparkleContinueWithoutSchedulingAnotherInstallation() {
        let updater = AppUpdater()
        XCTAssertFalse(updater.postponeInstallationIfNeeded { XCTFail("Sparkle owns an immediate install") })
        XCTAssertFalse(updater.installationWaiting)
        updater.resumeInstallationIfReady()
    }
}
