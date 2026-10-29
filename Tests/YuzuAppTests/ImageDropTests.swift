import AppKit
import ImageIO
import XCTest
import YuzuCore
@testable import YuzuApp

private final class RasterProvider: NSObject, NSPasteboardItemDataProvider {
    let bytes: Data
    private let lock = NSLock()
    private var count = 0
    var calls: Int { lock.lock(); defer { lock.unlock() }; return count }
    init(_ bytes: Data) { self.bytes = bytes }
    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        lock.lock(); count += 1; lock.unlock(); item.setData(bytes, forType: type)
    }
}

private final class PromiseFixture: NSFilePromiseReceiver, @unchecked Sendable {
    let bytes: Data
    private let lock = NSLock()
    private var count = 0
    var calls: Int { lock.lock(); defer { lock.unlock() }; return count }
    init(bytes: Data) { self.bytes = bytes; super.init() }
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) { return nil }
    override var fileTypes: [String] { ["public.png"] }
    override func receivePromisedFiles(atDestination destinationDir: URL, options: [AnyHashable: Any] = [:],
        operationQueue: OperationQueue, reader: @escaping (URL, Error?) -> Void) {
        lock.lock(); count += 1; lock.unlock()
        let data = bytes
        operationQueue.addOperation {
            let url = destinationDir.appendingPathComponent("Promised.png")
            do { try data.write(to: url, options: .withoutOverwriting); reader(url, nil) }
            catch { reader(url, error) }
        }
    }
}

private actor PreparedImages {
    var urls: [URL] = []
    func record(_ update: QueueProgress) { if let url = update.preparedImage?.urls.first { urls.append(url) } }
}

final class ImageDropTests: XCTestCase {
    @MainActor private func eventually(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(condition())
    }
    private func png() throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: 16, height: 24, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor.black); context.fill(CGRect(x: 0, y: 0, width: 16, height: 24))
        let bytes = NSMutableData()
        let writer = try XCTUnwrap(CGImageDestinationCreateWithData(bytes, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(writer, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(writer))
        return bytes as Data
    }

    @MainActor
    func testRawImageIsLazyShowsConversionWheelAndCleansItsPrivateFiles() async throws {
        _ = NSApplication.shared
        let drag = DragFixture(urls: [])
        defer { drag.draggingPasteboard.releaseGlobally() }
        let provider = RasterProvider(try png())
        let item = NSPasteboardItem()
        item.setDataProvider(provider, forTypes: [.png])
        XCTAssertTrue(drag.draggingPasteboard.writeObjects([item]))
        let wheel = WheelDragView(frame: NSRect(x: 0, y: 0, width: 320, height: 320))
        wheel.onImageSources = { _, view in view.options = [.conversion(.png), .conversion(.pdf)] }
        var captured: ImageDrop?
        wheel.onImageDrop = { image, option in captured = image; XCTAssertEqual(option, .conversion(.png)) }
        XCTAssertEqual(wheel.draggingEntered(drag), .copy)
        XCTAssertTrue(wheel.isWheelVisible)
        XCTAssertEqual(provider.calls, 0, "A pasteboard provider must not render on first hover")
        drag.draggingLocation = NSPoint(x: 160, y: 264)
        XCTAssertEqual(wheel.draggingUpdated(drag), .copy)
        XCTAssertTrue(wheel.prepareForDragOperation(drag))
        XCTAssertTrue(wheel.performDragOperation(drag))
        XCTAssertEqual(provider.calls, 1, "Snapshot on acceptance, never on hover")
        var files: ScopedFiles? = try await XCTUnwrap(captured).materialize()
        let file = try XCTUnwrap(files?.urls.first)
        XCTAssertEqual(try Data(contentsOf: file), try png())
        XCTAssertEqual(provider.calls, 1)
        files = nil
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    @MainActor
    func testUnsavedScreenshotUsesImageRepresentationEvenWhenItAlsoSuppliesAFileURL() throws {
        let drag = DragFixture(urls: [])
        defer { drag.draggingPasteboard.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("file:///tmp/Unsaved-screenshot.png", forType: .fileURL)
        item.setString("public.png", forType: ImageDrop.promiseContentType)
        item.setData(try png(), forType: .png)
        drag.draggingPasteboard.writeObjects([item])
        let wheel = WheelDragView(frame: NSRect(x: 0, y: 0, width: 320, height: 320))
        wheel.onImageSources = { _, view in view.options = [.conversion(.png)] }
        XCTAssertEqual(wheel.draggingEntered(drag), .copy)
        XCTAssertNotNil(wheel.imageDrop)
        XCTAssertTrue(wheel.sources.isEmpty)
        XCTAssertTrue(wheel.isWheelVisible)
    }

    @MainActor
    func testPromiseStartsAtAcceptanceSurvivesSaveDelayAndTransfersTemporaryOwnership() async throws {
        let data = try png()
        let drop = ImageDrop(content: .promise(PromiseFixture(bytes: data)), name: "Promise")
        try drop.accept()
        try await Task.sleep(for: .milliseconds(30))
        var files: ScopedFiles? = try await drop.materialize()
        let url = try XCTUnwrap(files?.urls.first)
        XCTAssertEqual(try Data(contentsOf: url), data)
        files = nil
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let cancelled = ImageDrop(content: .promise(PromiseFixture(bytes: data)), name: "Cancelled")
        try cancelled.accept()
        cancelled.cancelPreparation()
        do { _ = try await cancelled.materialize(); XCTFail("A cancelled promise cannot be used") } catch { }
    }

    @MainActor
    func testOnlyRasterURLsAreAcceptedAndMalformedDataFailsBeforePublication() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        for value in ["https://example.com/article", "file:///private/image.png", "javascript:alert(1)", "blob:https://example.com/image.png", "https://user:password@example.com/image.png"] {
            board.clearContents(); board.setString(value, forType: .URL)
            XCTAssertNil(ImageDrop.read(board), value)
        }
        board.clearContents(); board.setString("https://example.com/image.png?size=2", forType: .URL)
        XCTAssertNotNil(ImageDrop.read(board))
        do { _ = try await ImageDrop(content: .data(Data("not an image".utf8)), name: "Bad").materialize(); XCTFail("Reject malformed images") }
        catch { }
    }

    func testProviderPathsCannotEscapeThroughParentsOrLinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let staging = root.appendingPathComponent("Stage")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let outside = root.appendingPathComponent("Private.png"), valid = staging.appendingPathComponent("Valid.png")
        try png().write(to: outside); try png().write(to: valid)
        XCTAssertNoThrow(try ImageDrop.validate(valid, in: staging))
        XCTAssertThrowsError(try ImageDrop.validate(outside, in: staging))
        let link = staging.appendingPathComponent("Link.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        XCTAssertThrowsError(try ImageDrop.validate(link, in: staging))
    }

    @MainActor
    func testImportedImageRunsInQueueAndOneFolderCombinesTheWholeImageBatch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = JobQueue()
        let output = directory.appendingPathComponent("Saved.png")
        let data = try png()
        queue.enqueue(JobRequest(files: ScopedFiles([]), kind: .importedImage(ImageDrop(content: .data(data), name: "Browser image"), .png), destinations: [output]))
        await queue.waitForCurrentJob()
        XCTAssertEqual(queue.entries.first?.state, .completed)
        XCTAssertEqual(try SourceFile(url: output).format, .png)
        let other = directory.appendingPathComponent("Other.png")
        try data.write(to: other)
        queue.enqueue(JobRequest(files: ScopedFiles([output, other]), kind: .conversion(.pdf), destinations: [directory]))
        await queue.waitForCurrentJob()
        XCTAssertEqual(queue.entries.last?.state, .completed)
        XCTAssertEqual(queue.entries.last?.outputs.count, 1)
    }
    @MainActor
    func testRemoteImageDownloadsAreBoundedRejectRedirectsAndCanBeCancelled() async throws {
        let server = Process()
        let pipe = Pipe()
        server.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        server.arguments = ["python3", "-u", "-c", #"""
import base64, http.server, sys, time
image = base64.b64decode(sys.argv[1])
class Handler(http.server.BaseHTTPRequestHandler):
    retry_requests = 0
    def do_GET(self):
        if self.path == '/retry.png':
            Handler.retry_requests += 1
            if Handler.retry_requests == 1:
                self.send_response(503); self.end_headers(); return
        if self.path == '/redirect.png':
            self.send_response(302); self.send_header('Location', 'file:///private/example.png'); self.end_headers(); return
        self.send_response(200)
        self.send_header('Content-Type', 'text/html' if self.path == '/html.png' else 'image/png')
        if self.path == '/large.png': self.send_header('Content-Length', str(33 * 1024 * 1024))
        self.end_headers()
        if self.path == '/large.png': return
        if self.path == '/slow.png': time.sleep(2)
        try:
            if self.path == '/stream.png':
                for _ in range(34): self.wfile.write(bytes(1024 * 1024))
            else: self.wfile.write(image)
        except (BrokenPipeError, ConnectionResetError): pass
    def log_message(self, *args): pass
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
print(server.server_port, flush=True)
server.serve_forever()
"""#, try png().base64EncodedString()]
        server.standardOutput = pipe
        try server.run()
        defer { server.terminate(); server.waitUntilExit() }
        let port = try XCTUnwrap(Int(String(decoding: pipe.fileHandleForReading.availableData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)))
        func image(_ path: String) throws -> ImageDrop {
            ImageDrop(content: .remote(try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)/" + path))), name: "Remote image")
        }
        let success = try await image("ok.png").materialize()
        XCTAssertEqual(try Data(contentsOf: success.urls[0]), try png())
        for path in ["html.png", "large.png", "stream.png", "redirect.png"] {
            do { _ = try await image(path).materialize(); XCTFail("Reject \(path)") } catch { }
        }
        let slow = try image("slow.png")
        let cancelled = Task { try await slow.materialize() }
        try await Task.sleep(for: .milliseconds(50))
        cancelled.cancel()
        do { _ = try await cancelled.value; XCTFail("Expected cancelled image download") } catch is CancellationError {}
        catch { XCTAssertEqual((error as NSError).code, NSURLErrorCancelled) }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let destination = folder.appendingPathComponent("Retried.png")
        let queue = JobQueue()
        let id = queue.enqueue(JobRequest(files: ScopedFiles([]), kind: .importedImage(try image("retry.png"), .png), destinations: [destination]))
        try await eventually { queue.isIdle }
        XCTAssertEqual(queue.entries.first?.state, .failed)
        XCTAssertEqual(queue.entries.first?.canRetry, true)
        XCTAssertEqual(queue.entries.first?.recovery, .network)
        queue.retry(id)
        try await eventually { queue.isIdle }
        XCTAssertEqual(queue.entries.first?.state, .completed)
        XCTAssertEqual(try Data(contentsOf: destination).prefix(8), try png().prefix(8))
    }

    @MainActor
    func testPromisedImageRetryUsesPreparedBytesWithoutConsumingThePromiseAgain() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = folder.appendingPathComponent("Chosen.png")
        try Data("Keep existing".utf8).write(to: target)
        let receiver = PromiseFixture(bytes: try png())
        let image = ImageDrop(content: .promise(receiver), name: "Screenshot")
        try image.accept()
        let prepared = PreparedImages()
        let queue = JobQueue(successRetention: .seconds(60)) { request, progress in
            try await JobRequest.run(request) { update in await prepared.record(update); await progress(update) }
        }
        let id = queue.enqueue(JobRequest(files: ScopedFiles([]), kind: .importedImage(image, .png), destinations: [target]))
        try await eventually { queue.isIdle }
        XCTAssertEqual(queue.entries[0].state, .failed)
        XCTAssertTrue(queue.entries[0].canRetry)
        XCTAssertEqual(queue.entries[0].recovery, .exists)
        let captured = await prepared.urls
        let input = try XCTUnwrap(captured.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: input.path))
        XCTAssertEqual(try String(contentsOf: target), "Keep existing")
        try FileManager.default.removeItem(at: target)
        queue.retry(id)
        try await eventually { queue.isIdle && !FileManager.default.fileExists(atPath: input.path) }
        XCTAssertEqual(queue.entries[0].state, .completed)
        XCTAssertEqual(receiver.calls, 1)
        let inputs = await prepared.urls
        XCTAssertEqual(inputs, [input, input])
        XCTAssertNotNil(CGImageSourceCreateWithURL(target as CFURL, nil))
    }

    @MainActor
    func testClearingFailedImageRemovesItsPreparedTemporaryFile() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = folder.appendingPathComponent("Existing.png")
        try Data("Keep existing".utf8).write(to: target)
        let prepared = PreparedImages()
        let queue = JobQueue { request, progress in
            try await JobRequest.run(request) { update in await prepared.record(update); await progress(update) }
        }
        queue.enqueue(JobRequest(files: ScopedFiles([]), kind: .importedImage(ImageDrop(content: .data(try png()), name: "Image"), .png), destinations: [target]))
        try await eventually { queue.isIdle }
        let captured = await prepared.urls
        let input = try XCTUnwrap(captured.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: input.path))
        queue.clearFinished()
        try await eventually { !FileManager.default.fileExists(atPath: input.path) }
        XCTAssertEqual(try String(contentsOf: target), "Keep existing")
    }

    @MainActor
    func testFailedUnmaterializedPromiseRequiresANewDragInsteadOfAFalseRetry() async throws {
        let receiver = PromiseFixture(bytes: Data())
        let queue = JobQueue()
        let target = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        let id = queue.enqueue(JobRequest(files: ScopedFiles([]), kind: .importedImage(ImageDrop(content: .promise(receiver), name: "Image"), .png), destinations: [target]))
        try await eventually { queue.isIdle }
        XCTAssertEqual(queue.entries[0].state, .failed)
        XCTAssertFalse(queue.entries[0].canRetry)
        XCTAssertEqual(queue.entries[0].recovery, .newDrag)
        queue.retry(id)
        XCTAssertEqual(receiver.calls, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }

}
