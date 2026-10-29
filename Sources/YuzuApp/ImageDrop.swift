import AppKit
import UniformTypeIdentifiers
import ImageIO
import YuzuCore

/// A virtual raster image snapshots accepted drag data; remote URLs are fetched only after Save.
@MainActor
final class ImageDrop {
    enum Content { case data(Data), pasteboard(NSPasteboardItem, NSPasteboard.PasteboardType), remote(URL), promise(NSFilePromiseReceiver) }
    private(set) var content: Content
    let name: String
    private var promise: PromisedImage?
    private var preparationDirectory: URL?
    static let promiseContentType = NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-content-type")
    init(content: Content, name: String) { self.content = content; self.name = name }
    nonisolated static let maximumBytes = 32 * 1024 * 1024
    static let pasteboardTypes: [NSPasteboard.PasteboardType] = [.png, .tiff, .URL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType(rawValue: $0) }

    static func read(_ board: NSPasteboard) -> ImageDrop? {
        if let item = board.pasteboardItems?.first,
           let type = item.types.first(where: { UTType($0.rawValue)?.conforms(to: .image) == true && UTType($0.rawValue) != .svg }) {
            return ImageDrop(content: .pasteboard(item, type), name: "Image")
        }
        if let receivers = board.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver],
           receivers.count == 1, let receiver = receivers.first,
           receiver.fileTypes.allSatisfy({ UTType($0)?.conforms(to: .image) == true && UTType($0) != .svg }), !receiver.fileTypes.isEmpty {
            return ImageDrop(content: .promise(receiver), name: "Image")
        }
        if let value = board.string(forType: .URL), value.utf8.count <= 8192, let url = URL(string: value),
           ImageDownload.allowed(url), ["jpg", "jpeg", "png", "tiff", "tif", "bmp", "heic", "heif", "webp", "avif", "gif"].contains(url.pathExtension.lowercased()) {
            return ImageDrop(content: .remote(url), name: url.lastPathComponent)
        }
        return nil
    }

    /// Preserve lazy representations while AppKit still owns the accepted drag session.
    func accept() throws {
        switch content {
        case .pasteboard(let item, let type):
            guard let data = item.data(forType: type), !data.isEmpty, data.count <= Self.maximumBytes else {
                throw ConversionError.invalid("The image provider is unavailable or the image exceeds 32 MiB.")
            }
            content = .data(data)
        case .promise(let receiver):
            guard promise == nil else { return }
            let directory = try makeDirectory()
            preparationDirectory = directory
            promise = PromisedImage(receiver, directory: directory)
        default: break
        }
    }
    func cancelPreparation() {
        promise?.cancel()
        if let preparationDirectory { try? FileManager.default.removeItem(at: preparationDirectory) }
        preparationDirectory = nil
    }
    deinit {
        if let preparationDirectory {
            let promise = promise
            Task { @MainActor in promise?.cancel(); try? FileManager.default.removeItem(at: preparationDirectory) }
        }
    }
    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("yuzu-image-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        return directory
    }

    func materialize() async throws -> ScopedFiles {
        try Task.checkCancellation()
        try accept()
        let directory = try preparationDirectory ?? makeDirectory()
        do {
            let url: URL
            switch content {
            case .data(let data):
                guard !data.isEmpty, data.count <= Self.maximumBytes else { throw ConversionError.invalid("The image exceeds 32 MiB or is empty.") }
                url = directory.appendingPathComponent("Image.data")
                try await Task.detached { try data.write(to: url, options: .withoutOverwriting) }.value
            case .pasteboard: throw ConversionError.failed("The pasteboard image was not accepted.")
            case .remote(let remote):
                let data = try await ImageDownload().fetch(remote)
                url = directory.appendingPathComponent("Image.data")
                try await Task.detached { try data.write(to: url, options: .withoutOverwriting) }.value
            case .promise:
                guard let promise else { throw ConversionError.failed("The image promise was not accepted.") }
                url = try await promise.value()
            }
            try Task.checkCancellation()
            try await Task.detached { try Self.validate(url, in: directory) }.value
            preparationDirectory = nil
            return ScopedFiles([url], temporaryDirectory: directory)
        } catch { cancelPreparation(); try? FileManager.default.removeItem(at: directory); throw error }
    }

    nonisolated static func validate(_ url: URL, in directory: URL) throws {
        let root = directory.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        guard url.isFileURL, url.resolvingSymlinksInPath().path.hasPrefix(root) else {
            throw ConversionError.invalid("The image provider returned a path outside its temporary folder.")
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true,
              values.isSymbolicLink != true, let size = values.fileSize, size > 0, size <= maximumBytes,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0,
              CGImageSourceGetCount(source) <= 256 else { throw ConversionError.invalid("The drop is not a supported raster image, or exceeds 32 MiB.") }
        var pixels: Double = 0
        for index in 0..<CGImageSourceGetCount(source) {
            guard let info = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
                  let width = info[kCGImagePropertyPixelWidth as String] as? NSNumber,
                  let height = info[kCGImagePropertyPixelHeight as String] as? NSNumber,
                  width.doubleValue > 0, height.doubleValue > 0 else { throw ConversionError.invalid("Invalid image dimensions.") }
            pixels += width.doubleValue * height.doubleValue
            guard pixels.isFinite, pixels <= 64_000_000 else { throw ConversionError.unsupported("The dropped image exceeds the 64-megapixel decoding limit.") }
        }
    }
}

@MainActor
private final class PromisedImage {
    private let directory: URL
    private var continuation: CheckedContinuation<URL, Error>?
    private var result: Result<URL, Error>?
    private var timeout: Task<Void, Never>?
    private var cancelled = false
    init(_ receiver: NSFilePromiseReceiver, directory: URL) {
        self.directory = directory
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
        receiver.receivePromisedFiles(atDestination: directory, options: [:], operationQueue: queue) { url, error in
            Task { @MainActor in self.finish(error.map { .failure($0) } ?? .success(url)) }
        }
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            self?.cancel(ConversionError.failed("The image provider did not finish within 30 seconds."))
        }
    }
    func value() async throws -> URL {
        try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            guard !cancelled else { throw CancellationError() }
            if let result { return try result.get() }
            return try await withCheckedThrowingContinuation { self.continuation = $0 }
        }, onCancel: { Task { @MainActor in self.cancel() } })
    }
    func cancel(_ error: Error = CancellationError()) {
        cancelled = true
        if result == nil { finish(.failure(error)) }
        try? FileManager.default.removeItem(at: directory)
    }
    private func finish(_ result: Result<URL, Error>) {
        // A provider may finish after cancellation; its output is confined to our disposable directory.
        if cancelled { try? FileManager.default.removeItem(at: directory) }
        guard self.result == nil else { return }
        self.result = result
        timeout?.cancel(); timeout = nil
        let continuation = self.continuation; self.continuation = nil
        continuation?.resume(with: result)
    }
}

/// An ephemeral, bounded GET with no browser cookies or credentials. The lock also serializes cancellation.
private final class ImageDownload: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var bytes = Data()
    private var continuation: CheckedContinuation<Data, Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var cancelled = false
    private var redirects = 0
    static func allowed(_ url: URL) -> Bool {
        ["https", "http"].contains(url.scheme?.lowercased() ?? "") && url.host != nil && url.user == nil && url.password == nil
    }
    func fetch(_ url: URL) async throws -> Data {
        guard Self.allowed(url) else { throw ConversionError.invalid("Unsupported image URL.") }
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                guard !cancelled else { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
                let config = URLSessionConfiguration.ephemeral
                config.httpCookieStorage = nil; config.urlCredentialStorage = nil; config.urlCache = nil
                config.timeoutIntervalForRequest = 20; config.timeoutIntervalForResource = 30
                let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
                let session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
                self.session = session; self.continuation = continuation
                let task = session.dataTask(with: url); self.task = task
                lock.unlock(); task.resume()
            }
        }, onCancel: { self.lock.lock(); self.cancelled = true; self.lock.unlock(); self.finish(.failure(CancellationError())) })
    }
    private func finish(_ result: Result<Data, Error>) {
        lock.lock()
        let continuation = self.continuation; self.continuation = nil
        let session = self.session; self.session = nil; self.task = nil
        lock.unlock()
        continuation?.resume(with: result); session?.invalidateAndCancel()
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              response.expectedContentLength <= ImageDrop.maximumBytes,
              response.mimeType?.hasPrefix("image/") == true || response.mimeType == "application/octet-stream" else {
            completionHandler(.cancel); finish(.failure(ConversionError.failed("The URL did not return an image, or exceeds 32 MiB."))); return
        }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard continuation != nil else { lock.unlock(); return }
        guard data.count <= ImageDrop.maximumBytes - bytes.count else {
            lock.unlock(); finish(.failure(ConversionError.failed("The image download exceeds 32 MiB."))); return
        }
        bytes.append(data); lock.unlock()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock(); let data = bytes; lock.unlock()
        finish(error.map { .failure($0) } ?? .success(data))
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        redirects += 1
        guard redirects <= 5, let url = request.url, Self.allowed(url) else {
            completionHandler(nil); finish(.failure(ConversionError.failed("Unsupported image redirect."))); return
        }
        completionHandler(request)
    }
}

@MainActor
final class ImageSaveDelegate: NSObject, NSOpenSavePanelDelegate {
    func panel(_ sender: Any, validate url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileWriteFileExists, userInfo: [NSLocalizedDescriptionKey: L10n.text("Choose a new filename. Existing files are never replaced.")])
        }
    }
}
