import XCTest
import Sparkle
@testable import YuzuApp

final class UpdaterTests: XCTestCase {
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
