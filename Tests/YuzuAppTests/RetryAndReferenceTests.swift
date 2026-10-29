import AppKit
import XCTest
import YuzuCore
@testable import YuzuApp

private actor RetryOrder {
    var names: [String] = []
    private var continuation: CheckedContinuation<Void, Never>?
    var blocked = false
    func enter(_ name: String) async -> Int {
        names.append(name)
        let attempt = names.filter { $0 == name }.count
        if name == "B.txt" {
            blocked = true
            await withCheckedContinuation { continuation = $0 }
        }
        return attempt
    }
    func release() { continuation?.resume(); continuation = nil }
}

final class RetryAndReferenceTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    @MainActor private func eventually(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(condition())
    }
    @MainActor private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }

    @MainActor
    func testRetryConvertsOnlyRemainingSourcesInTheirOwnDestinationsAndReleasesGrants() async throws {
        let a = root.appendingPathComponent("First.txt"), b = root.appendingPathComponent("Second.txt")
        let firstOutput = root.appendingPathComponent("One"), secondOutput = root.appendingPathComponent("Two")
        try FileManager.default.createDirectory(at: firstOutput, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: secondOutput, withIntermediateDirectories: false)
        try Data("First contents".utf8).write(to: a)
        let queue = JobQueue(successRetention: .seconds(60))
        var batch: ScopedFiles? = ScopedFiles([a, b])
        weak var lease = batch
        let id = queue.enqueue(JobRequest(files: try XCTUnwrap(batch), kind: .conversion(.md), destinations: [firstOutput, secondOutput]))
        batch = nil
        try await eventually { queue.isIdle }
        XCTAssertEqual(queue.entries[0].state, .failed)
        XCTAssertEqual(queue.entries[0].completedInputs, 1)
        XCTAssertTrue(queue.entries[0].canRetry)
        XCTAssertNotNil(lease)
        XCTAssertEqual(queue.entries[0].recovery, .missing)
        XCTAssertEqual(queue.entries[0].outputs, [firstOutput.appendingPathComponent("First.md")])
        try Data("Restored second contents".utf8).write(to: b)
        queue.allowsRetry = false
        queue.retry(id)
        XCTAssertEqual(queue.entries[0].state, .failed)
        queue.allowsRetry = true
        queue.retry(id)
        queue.retry(id)
        try await eventually { queue.isIdle && lease == nil }
        XCTAssertEqual(queue.entries.count, 1)
        XCTAssertEqual(queue.entries[0].state, .completed)
        XCTAssertEqual(queue.entries[0].filenames, ["Second.txt"])
        XCTAssertEqual(queue.entries[0].outputs, [firstOutput.appendingPathComponent("First.md"), secondOutput.appendingPathComponent("Second.md")])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: firstOutput.path), ["First.md"])
        XCTAssertEqual(try String(contentsOf: secondOutput.appendingPathComponent("Second.md")), "Restored second contents")
        XCTAssertEqual(try String(contentsOf: a), "First contents")
        XCTAssertNil(queue.entries[0].error)
    }

    @MainActor
    func testRetryJoinsTheQueueTailAndPreservesItsOptions() async throws {
        let order = RetryOrder()
        let queue = JobQueue(successRetention: .seconds(60)) { request, _ in
            let name = request.files.urls[0].lastPathComponent
            let attempt = await order.enter(name)
            if name == "A.txt" {
                XCTAssertEqual(request.options.quality, .high)
                if attempt == 1 { throw CocoaError(.fileReadCorruptFile) }
            }
            return []
        }
        let id = queue.enqueue(JobRequest(files: ScopedFiles([root.appendingPathComponent("A.txt")]), kind: .compress,
            destinations: [], options: .init(quality: .high)))
        try await eventually { queue.isIdle }
        queue.enqueue(JobRequest(files: ScopedFiles([root.appendingPathComponent("B.txt")]), kind: .compress, destinations: []))
        queue.enqueue(JobRequest(files: ScopedFiles([root.appendingPathComponent("C.txt")]), kind: .compress, destinations: []))
        while !(await order.blocked) { try await Task.sleep(for: .milliseconds(10)) }
        queue.retry(id)
        XCTAssertEqual(queue.entries.map { $0.filenames[0] }, ["B.txt", "C.txt", "A.txt"])
        await order.release()
        try await eventually { queue.isIdle }
        let names = await order.names
        XCTAssertEqual(names, ["A.txt", "B.txt", "C.txt", "A.txt"])
        XCTAssertTrue(queue.entries.allSatisfy { $0.state == .completed })
    }

    @MainActor
    func testClearingFailureReleasesRetainedInputsAndPreventsRetry() async throws {
        let queue = JobQueue { _, _ in throw CocoaError(.fileReadCorruptFile) }
        var batch: ScopedFiles? = ScopedFiles([root.appendingPathComponent("Missing.txt")])
        weak var lease = batch
        let id = queue.enqueue(JobRequest(files: try XCTUnwrap(batch), kind: .compress, destinations: []))
        batch = nil
        try await eventually { queue.isIdle }
        XCTAssertNotNil(lease)
        queue.clearFinished()
        queue.retry(id)
        try await eventually { lease == nil }
        XCTAssertTrue(queue.entries.isEmpty)
    }

    func testRecoveryUsesErrorCodesAndKeepsTechnicalDetailsSeparate() {
        let wrapped = NSError(domain: "Wrapper", code: 0, userInfo: [NSUnderlyingErrorKey: POSIXError(.ENOSPC)])
        XCTAssertEqual(JobRecovery(wrapped), .space)
        XCTAssertEqual(JobRecovery(CocoaError(.fileWriteNoPermission)), .access)
        XCTAssertEqual(JobRecovery(POSIXError(.ENOENT)), .missing)
        XCTAssertEqual(JobRecovery(POSIXError(.EEXIST)), .exists)
        XCTAssertEqual(JobRecovery(URLError(.timedOut)), .network)
        XCTAssertEqual(JobRecovery(ConversionError.unsupported("Unsupported codec")), .unsupported)
        for recovery in [JobRecovery.missing, .access, .space, .exists, .damaged, .network, .unsupported, .other, .newDrag, .resultsPreserved] {
            for language in AppLanguage.allCases {
                XCTAssertFalse(L10n.string(recovery.text.title, language: language).isEmpty)
                if language != .english {
                    XCTAssertNotEqual(L10n.string(recovery.text.suggestion, language: language), recovery.text.suggestion)
                }
            }
        }
    }

    @MainActor
    func testPartialMoveUpdatesHiddenShelvesAndQueuedChildrenThenRetriesOnlyTheBlockedFile() async throws {
        _ = NSApplication.shared
        let folder = root.appendingPathComponent("Folder"), protected = root.appendingPathComponent("Protected")
        let target = root.appendingPathComponent("Target"), converted = root.appendingPathComponent("Converted")
        for url in [folder, protected, target, converted] { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false) }
        let child = folder.appendingPathComponent("Child.txt"), second = protected.appendingPathComponent("Second.txt")
        try Data("Child contents".utf8).write(to: child)
        try Data("Second contents".utf8).write(to: second)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: protected.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: protected.path) }
        XCTAssertFalse(FileManager.default.isWritableFile(atPath: protected.path))
        let domain = "ReferenceMoveTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let settings = Settings(defaults: defaults)
        settings.addToShelf = false
        let actions = ActionController(access: AccessStore(defaults: defaults), settings: settings)
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))
        func shelves() -> [ShelfController] {
            NSApp.windows.filter { !before.contains(ObjectIdentifier($0)) }.compactMap { $0.delegate as? ShelfController }
        }
        actions.perform(.float, files: ScopedFiles([folder, child, second]))
        let first = try XCTUnwrap(shelves().first)
        first.close()
        let newFolder = target.appendingPathComponent("Folder"), newChild = newFolder.appendingPathComponent("Child.txt")
        actions.perform(.float, files: ScopedFiles([child, newChild]))
        let other = try XCTUnwrap(shelves().first { $0 !== first })
        other.close()
        defer { for shelf in shelves() { shelf.close(); shelf.removeFiles(at: IndexSet(shelf.files.indices)) } }
        let queue = JobQueue(successRetention: .seconds(60))
        queue.onFilesMoved = { moves, access in actions.filesMoved(moves, access: access) }
        let move = queue.enqueue(JobRequest(files: ScopedFiles([child, folder, second]), kind: .move, destinations: [target]))
        queue.enqueue(JobRequest(files: actions.scopedFiles([child]), kind: .conversion(.md), destinations: [converted]))
        queue.enqueue(JobRequest(files: actions.scopedFiles([child]), kind: .conversion(.md), destinations: [folder]))
        try await eventually { queue.isIdle }
        XCTAssertEqual(queue.entries.map(\.state), [.failed, .completed, .completed])
        XCTAssertEqual(queue.entries[0].completedInputs, 2)
        XCTAssertEqual(first.files.map(\.path), [newFolder.path, newChild.path, second.path])
        XCTAssertEqual(other.files, [newChild], "A previously unavailable destination reference must be deduplicated")
        XCTAssertFalse(first.window?.isVisible ?? true)
        XCTAssertFalse(other.window?.isVisible ?? true)
        XCTAssertEqual(try String(contentsOf: converted.appendingPathComponent("Child.md")), "Child contents")
        XCTAssertEqual(try String(contentsOf: newFolder.appendingPathComponent("Child.md")), "Child contents")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: protected.path)
        queue.retry(move)
        try await eventually { queue.isIdle }
        XCTAssertEqual(queue.entries.map(\.state), [.completed, .completed, .completed])
        XCTAssertEqual(queue.entries.last?.filenames, ["Second.txt"])
        XCTAssertEqual(first.files.map(\.path), [newFolder.path, newChild.path, target.appendingPathComponent("Second.txt").path])
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: target.path)), ["Folder", "Second.txt"])
        XCTAssertEqual(try String(contentsOf: newChild), "Child contents")
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.path))
    }

    @MainActor
    func testFailedRequestFollowsAKnownMoveAndRetainsItsNewGrantUntilRetry() async throws {
        let source = root.appendingPathComponent("Note.txt"), target = root.appendingPathComponent("Target")
        let output = root.appendingPathComponent("Later")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        try Data("Moved original".utf8).write(to: source)
        let existing = target.appendingPathComponent("Note.txt")
        try Data("Keep existing".utf8).write(to: existing)
        let queue = JobQueue(successRetention: .milliseconds(30))
        weak var movedAccess: ScopedFiles?
        queue.onFilesMoved = { _, access in movedAccess = access }
        let conversion = queue.enqueue(JobRequest(files: ScopedFiles([source]), kind: .conversion(.md), destinations: [output]))
        try await eventually { queue.isIdle }
        XCTAssertTrue(queue.entries[0].canRetry)
        let move = queue.enqueue(JobRequest(files: ScopedFiles([source]), kind: .move, destinations: [target]))
        try await eventually { queue.isIdle && !queue.entries.contains { $0.id == move } }
        XCTAssertNotNil(movedAccess, "A failed request must retain the new destination grant after the Move row expires")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
        queue.retry(conversion)
        try await eventually { queue.isIdle && movedAccess == nil }
        XCTAssertEqual(try String(contentsOf: output.appendingPathComponent("Note_yuzu.md")), "Moved original")
        XCTAssertEqual(try String(contentsOf: existing), "Keep existing")
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
    }

    @MainActor
    func testPublishedCopiesAreNotRetriedWhenSourceCleanupFails() async throws {
        let source = root.appendingPathComponent("Source.txt"), copy = root.appendingPathComponent("Copy.txt")
        try Data("Original contents".utf8).write(to: source)
        let queue = JobQueue { request, progress in
            try Data(contentsOf: source).write(to: copy, options: .withoutOverwriting)
            await progress(QueueProgress(completed: 1, published: [copy], finishedSources: request.files.urls))
            throw CocoaError(.fileWriteNoPermission)
        }
        var batch: ScopedFiles? = ScopedFiles([source])
        weak var access = batch
        let id = queue.enqueue(JobRequest(files: try XCTUnwrap(batch), kind: .move, destinations: [root]))
        batch = nil
        try await eventually { queue.isIdle && access == nil }
        XCTAssertFalse(queue.entries[0].canRetry)
        XCTAssertEqual(queue.entries[0].recovery, .resultsPreserved)
        queue.retry(id)
        XCTAssertEqual(queue.entries[0].state, .failed)
        XCTAssertEqual(try Data(contentsOf: source), try Data(contentsOf: copy))
    }

    @MainActor
    func testMissingAndDeniedShelfFilesHaveRepairControlsAndCanBeRelocatedWithoutTouchingData() async throws {
        _ = NSApplication.shared
        let original = root.appendingPathComponent("Original.txt"), replacement = root.appendingPathComponent("Renamed.txt")
        try Data("Preserved replacement".utf8).write(to: replacement)
        let shelf = ShelfController()
        defer { shelf.close(); shelf.removeFiles(at: IndexSet(shelf.files.indices)) }
        shelf.add(ScopedFiles([original]))
        try await eventually { shelf.fileStates[original] == .missing }
        XCTAssertNil(shelf.tableView(NSTableView(), pasteboardWriterForRow: 0))
        let cell = try XCTUnwrap(shelf.tableView(NSTableView(), viewFor: nil, row: 0))
        XCTAssertTrue(descendants(cell).compactMap { $0 as? NSTextField }.contains { $0.stringValue == L10n.text("File not found") })
        XCTAssertTrue(descendants(cell).compactMap { $0 as? NSButton }.contains { $0.toolTip?.hasPrefix(L10n.text("Locate Original…")) == true })
        var access: ScopedFiles? = ScopedFiles([replacement])
        weak var retained = access
        shelf.replaceReference(original, with: try XCTUnwrap(access))
        access = nil
        try await eventually { shelf.fileStates[replacement] == .available }
        XCTAssertEqual(shelf.files, [replacement])
        XCTAssertNotNil(retained)
        XCTAssertEqual(shelf.tableView(NSTableView(), pasteboardWriterForRow: 0) as? NSURL, replacement as NSURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: replacement.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: replacement.path) }
        shelf.refreshAvailability()
        try await eventually { shelf.fileStates[replacement] == .accessRequired }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: replacement.path)
        shelf.replaceReference(replacement, with: ScopedFiles([replacement]))
        try await eventually { shelf.fileStates[replacement] == .available }
        XCTAssertEqual(try String(contentsOf: replacement), "Preserved replacement")
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
    }

    @MainActor
    func testVisibleShelfRefreshesDeletedFilesAndReopeningFindsRestoredFiles() async throws {
        _ = NSApplication.shared
        let file = root.appendingPathComponent("Visible.txt")
        try Data("Visible contents".utf8).write(to: file)
        let shelf = ShelfController()
        defer { shelf.close(); shelf.removeFiles(at: IndexSet(shelf.files.indices)) }
        shelf.add(ScopedFiles([file]))
        shelf.present(relativeTo: nil)
        try await eventually { shelf.fileStates[file] == .available }
        try FileManager.default.removeItem(at: file)
        try await eventually { shelf.fileStates[file] == .missing }
        shelf.close()
        try Data("Restored contents".utf8).write(to: file)
        shelf.present(relativeTo: nil)
        try await eventually { shelf.fileStates[file] == .available }
        XCTAssertEqual(shelf.files, [file])
    }

    @MainActor
    func testDirectoryURLVariantsShareOneShelfReferenceAndItsOriginalGrant() throws {
        _ = NSApplication.shared
        let folder = root.appendingPathComponent("Folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let variant = URL(fileURLWithPath: folder.path, isDirectory: true)
        var original: ScopedFiles? = ScopedFiles([folder])
        weak var batch = original
        let shelf = ShelfController()
        defer { shelf.close(); shelf.removeFiles(at: IndexSet(shelf.files.indices)) }
        shelf.add(try XCTUnwrap(original))
        original = nil
        shelf.add(ScopedFiles([variant]))
        XCTAssertEqual(shelf.files.count, 1)
        XCTAssertTrue(shelf.retainedBatches(for: [variant]).first === batch)
        shelf.replaceReference(folder, with: ScopedFiles([variant]))
        XCTAssertEqual(shelf.files.count, 1)
        XCTAssertEqual(shelf.files.first?.path, folder.path)
        XCTAssertEqual(shelf.retainedBatches(for: [folder]).count, 1)
    }
}
