import AppKit
import XCTest
import YuzuCore
@testable import YuzuApp

private actor QueueGate {
    private var continuations: [String: CheckedContinuation<Void, Never>] = [:]
    private(set) var started: [String] = []
    func enter(_ name: String) async {
        started.append(name)
        await withCheckedContinuation { continuations[name] = $0 }
    }
    func release(_ name: String) { continuations.removeValue(forKey: name)?.resume() }
}

private actor ProgressLog {
    var updates: [QueueProgress] = []
    func append(_ update: QueueProgress) { updates.append(update) }
}

final class JobQueueTests: XCTestCase {
    @MainActor
    private func eventually(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition() && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(condition(), "The queue did not reach the expected state")
    }

    @MainActor
    func testSerialOrderQueuedCancellationAndGrantLifetime() async throws {
        let gate = QueueGate()
        let queue = JobQueue { request, progress in
            let name = request.files.urls[0].lastPathComponent
            await gate.enter(name)
            try Task.checkCancellation()
            await progress(QueueProgress(completed: 1))
            return [URL(fileURLWithPath: "/tmp/" + name)]
        }
        var first: ScopedFiles? = ScopedFiles([URL(fileURLWithPath: "/tmp/first.txt")])
        var second: ScopedFiles? = ScopedFiles([URL(fileURLWithPath: "/tmp/second.txt")])
        weak var firstLease = first
        weak var secondLease = second
        let id = queue.enqueue(JobRequest(files: try XCTUnwrap(first), kind: .compress, destinations: []))
        let cancelled = queue.enqueue(JobRequest(files: try XCTUnwrap(second), kind: .compress, destinations: []))
        first = nil; second = nil
        XCTAssertNotNil(firstLease)
        XCTAssertNotNil(secondLease)
        XCTAssertEqual(queue.entries.map(\.state), [.running, .waiting])
        queue.cancel(cancelled)
        XCTAssertNil(secondLease, "A cancelled waiting job must release its grants")
        while await gate.started.isEmpty { try await Task.sleep(nanoseconds: 10_000_000) }
        queue.cancel(id)
        XCTAssertEqual(queue.entries[0].state, .cancelling)
        await gate.release("first.txt")
        try await eventually { queue.isIdle && firstLease == nil }
        XCTAssertEqual(queue.entries.map(\.state), [.cancelled, .cancelled])
        let started = await gate.started
        XCTAssertEqual(started, ["first.txt"])
        queue.clearFinished()
        XCTAssertTrue(queue.entries.isEmpty)
    }

    @MainActor
    func testFailureKeepsPublishedResultsAndStartsTheNextJob() async throws {
        let result = URL(fileURLWithPath: "/tmp/Finished first page.png")
        let queue = JobQueue { request, progress in
            if request.files.urls[0].lastPathComponent == "broken.txt" {
                await progress(QueueProgress(completed: 1, published: [result]))
                throw CocoaError(.fileReadCorruptFile)
            }
            return [URL(fileURLWithPath: "/tmp/next.zip")]
        }
        let files = ScopedFiles([URL(fileURLWithPath: "/tmp/broken.txt"), URL(fileURLWithPath: "/tmp/later.txt")])
        queue.enqueue(JobRequest(files: files, kind: .conversion(.png), destinations: []))
        queue.enqueue(JobRequest(files: ScopedFiles([URL(fileURLWithPath: "/tmp/next.txt")]), kind: .compress, destinations: []))
        try await eventually { queue.isIdle }
        XCTAssertEqual(queue.entries.map(\.state), [.failed, .completed])
        XCTAssertEqual(queue.entries[0].completedInputs, 1)
        XCTAssertEqual(queue.entries[0].outputs, [result])
        XCTAssertNotNil(queue.entries[0].error)
        queue.clearFinished()
        XCTAssertTrue(queue.entries.isEmpty)
    }

    func testRealConversionPreservesEarlierOutputOnLaterFailure() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("notes.txt")
        try Data("Readable notes".utf8).write(to: source)
        let existing = directory.appendingPathComponent("notes.md")
        try Data("Keep existing".utf8).write(to: existing)
        let log = ProgressLog()
        do {
            _ = try await JobRequest.run(JobRequest(files: ScopedFiles([source, directory.appendingPathComponent("missing.txt")]),
                kind: .conversion(.md), destinations: [directory, directory])) { await log.append($0) }
            XCTFail("A missing second source must fail")
        } catch { XCTAssertTrue(FileManager.default.fileExists(atPath: source.path)) }
        let updates = await log.updates
        let published = updates.flatMap(\.published)
        XCTAssertEqual(published.map(\.lastPathComponent), ["notes_yuzu.md"])
        XCTAssertEqual(try String(contentsOf: try XCTUnwrap(published.first)), "Readable notes")
        XCTAssertEqual(try String(contentsOf: existing), "Keep existing")
        XCTAssertEqual(updates.map(\.completed), [0, 1, 1])
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasPrefix(".yuzu-") })
    }

    func testMoveNormalizesFoldersAndReportsPublishedItemsBeforeLaterFailure() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = directory.appendingPathComponent("Folder")
        let destination = directory.appendingPathComponent("Destination")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let child = folder.appendingPathComponent("child.txt")
        try Data("Keep child".utf8).write(to: child)
        let log = ProgressLog()
        let outputs = try await JobRequest.run(JobRequest(files: ScopedFiles([child, folder]), kind: .move,
                                                         destinations: [destination])) { await log.append($0) }
        XCTAssertEqual(outputs.count, 1)
        XCTAssertEqual(try String(contentsOf: outputs[0].appendingPathComponent("child.txt")), "Keep child")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        let first = directory.appendingPathComponent("first.txt")
        let blocked = directory.appendingPathComponent("Blocked")
        let nested = blocked.appendingPathComponent("Inside")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data("First".utf8).write(to: first)
        let partial = ProgressLog()
        do {
            _ = try await JobRequest.run(JobRequest(files: ScopedFiles([first, blocked]), kind: .move,
                destinations: [nested])) { await partial.append($0) }
            XCTFail("A recursive destination must fail")
        } catch { }
        let updates = await partial.updates
        XCTAssertEqual(updates.flatMap(\.published), [nested.appendingPathComponent("first.txt")])
        XCTAssertEqual(updates.last?.completed, 1)
        XCTAssertEqual(try String(contentsOf: nested.appendingPathComponent("first.txt")), "First")
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: blocked.path))
    }

    func testInvalidDestinationCountsAndZIPPublication() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("note.txt")
        try Data("ZIP original".utf8).write(to: file)
        for kind in [JobKind.conversion(.md), .move, .compress] {
            do {
                _ = try await JobRequest.run(JobRequest(files: ScopedFiles([file]), kind: kind, destinations: [])) { _ in }
                XCTFail("Invalid destination count must fail")
            } catch { }
        }
        let outputs = try await JobRequest.run(JobRequest(files: ScopedFiles([file]), kind: .compress,
                                                         destinations: [directory])) { _ in }
        XCTAssertEqual(outputs.map(\.lastPathComponent), ["note.txt.zip"])
        XCTAssertEqual(try String(contentsOf: file), "ZIP original")
    }
}
