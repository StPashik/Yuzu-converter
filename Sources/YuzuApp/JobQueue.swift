import AppKit
import Combine
import YuzuCore

enum JobKind: Sendable {
    case conversion(FileFormat), move, compress, importedImage(ImageDrop, FileFormat)
    func title(in language: AppLanguage) -> String {
        switch self {
        case .conversion(let format), .importedImage(_, let format): return L10n.string("Converting to %@", language: language, arguments: [format.label])
        case .move: return L10n.string("Moving files", language: language)
        case .compress: return L10n.string("Compressing to ZIP", language: language)
        }
    }
}

struct JobRequest: Sendable {
    fileprivate(set) var files: ScopedFiles
    let kind: JobKind
    fileprivate(set) var destinations: [URL]
    let options: ConversionOptions
    private var destinationAccess: ScopedFiles

    init(files: ScopedFiles, kind: JobKind, destinations: [URL], options: ConversionOptions = .init()) {
        self.files = files
        self.kind = kind
        self.destinations = destinations
        self.options = options
        // Powerbox already started these scopes; transfer them without starting a second access.
        destinationAccess = ScopedFiles([], activeGrants: destinations)
    }

    @MainActor var filenames: [String] {
        if case .importedImage(let image, _) = kind { return [image.name] }
        return files.urls.map(\.lastPathComponent)
    }

    @MainActor func remaining(after finished: Set<String>) -> JobRequest? {
        if case .importedImage(let image, _) = kind {
            return !files.urls.isEmpty || image.canRetryPreparation ? self : nil
        }
        let indices = files.urls.indices.filter { !finished.contains(files.urls[$0].standardizedFileURL.path) }
        guard !indices.isEmpty else { return nil }
        if indices.count == files.urls.count { return self }
        var request = self
        request.files = ScopedFiles(indices.map { files.urls[$0] }, retaining: [files])
        if case .conversion = kind, destinations.count == files.urls.count {
            request.destinations = indices.map { destinations[$0] }
        }
        // Copies of this value share the original output lease; never transfer an active grant twice.
        return request
    }

    func relocating(_ moves: [FileMove], access: ScopedFiles) -> JobRequest {
        let urls = files.urls.map { url in moves.lazy.compactMap { $0.relocating(url) }.first ?? url }
        var folders = destinations.map { url in moves.lazy.compactMap { $0.relocating(url) }.first ?? url }
        switch kind {
        case .importedImage:
            // Save As is an exact-path agreement; a later folder move must not select another filename.
            folders = destinations
        case .conversion where destinations.count == files.urls.count:
            for index in files.urls.indices where destinations[index].standardizedFileURL.path == files.urls[index].deletingLastPathComponent().standardizedFileURL.path {
                folders[index] = urls[index].deletingLastPathComponent()
            }
        case .conversion, .compress:
            if destinations.count == 1, let first = files.urls.first,
               destinations[0].standardizedFileURL.path == first.deletingLastPathComponent().standardizedFileURL.path,
               let updated = urls.first { folders[0] = updated.deletingLastPathComponent() }
        case .move: break
        }
        guard urls != files.urls || folders != destinations else { return self }
        var request = self
        request.files = ScopedFiles(urls, retaining: [files, access])
        request.destinations = folders
        request.destinationAccess = ScopedFiles([], retaining: [destinationAccess, access])
        return request
    }

    func movedFiles(_ moves: [FileMove]) -> ScopedFiles {
        ScopedFiles(moves.map(\.destination), retaining: [destinationAccess])
    }

    static func run(_ request: JobRequest, progress: @Sendable (QueueProgress) async -> Void) async throws -> [URL] {
        if request.files.urls.isEmpty {
            if case .importedImage = request.kind {} else { throw ConversionError.invalid("Choose at least one file.") }
        }
        switch request.kind {
        case .conversion(let target):
            let engine = ConversionEngine()
            if target == .pdf, request.files.urls.count > 1,
               let sources = try? request.files.urls.map({ try SourceFile(url: $0) }),
               sources.allSatisfy({ $0.format.category == "Images" }) {
                guard !request.destinations.isEmpty else { throw ConversionError.invalid("Choose an output folder.") }
                await progress(QueueProgress(completed: 0, currentFile: request.files.urls[0].lastPathComponent))
                let result = try engine.combineImages(sources, in: request.destinations[0], options: request.options)
                await progress(QueueProgress(completed: sources.count, published: [result], finishedSources: request.files.urls))
                return [result]
            }
            guard request.destinations.count == request.files.urls.count else {
                throw ConversionError.invalid("Every source needs its own output folder.")
            }
            var outputs: [URL] = []
            for (index, url) in request.files.urls.enumerated() {
                try Task.checkCancellation()
                await progress(QueueProgress(completed: index, currentFile: url.lastPathComponent))
                let result = try await engine.convert(SourceFile(url: url), to: target,
                    in: request.destinations[index], options: request.options)
                outputs += result
                await progress(QueueProgress(completed: index + 1, published: result, finishedSources: [url]))
            }
            return outputs
        case .importedImage(let image, let target):
            guard request.destinations.count == 1 else { throw ConversionError.invalid("Choose one destination file.") }
            let files = request.files.urls.isEmpty ? try await image.materialize() : request.files
            defer { withExtendedLifetime(files) {} }
            // A file promise is single-use; keep accepted bytes available if encoding later fails.
            await progress(QueueProgress(completed: 0, preparedImage: files))
            try Task.checkCancellation()
            let output = try ConversionEngine().saveDroppedImage(files.urls[0], to: target,
                destination: request.destinations[0], options: request.options)
            await progress(QueueProgress(completed: 1, published: [output]))
            return [output]
        case .move, .compress:
            guard request.destinations.count == 1 else { throw ConversionError.invalid("Choose one destination folder.") }
            await progress(QueueProgress(completed: 0, currentFile: request.files.urls.first?.lastPathComponent))
            let outputs: [URL]
            if case .move = request.kind {
                // Keep the Core batch contract: normalizing folders/children separately would move files twice.
                var published: [URL] = []
                var finished: [URL] = []
                var moves: [FileMove] = []
                do {
                    outputs = try FileOperations.copy(request.files.urls, to: request.destinations[0], move: true, onMove: { move in
                        moves.append(move)
                        finished += request.files.urls.filter { move.relocating($0) != nil }
                    }, onPublish: { source, result in
                        published.append(result)
                        finished += request.files.urls.filter { $0.standardizedFileURL.path == source.path }
                    })
                } catch {
                    let paths = Set(finished.map { $0.standardizedFileURL.path })
                    let count = request.files.urls.filter { paths.contains($0.standardizedFileURL.path) }.count
                    await progress(QueueProgress(completed: count, published: published, finishedSources: finished, moves: moves))
                    throw error
                }
                await progress(QueueProgress(completed: request.files.urls.count, published: outputs,
                    finishedSources: request.files.urls, moves: moves))
                return outputs
            } else {
                outputs = [try FileOperations.compress(request.files.urls, in: request.destinations[0],
                                                       compression: request.options.compression)]
            }
            await progress(QueueProgress(completed: request.files.urls.count, published: outputs, finishedSources: request.files.urls))
            return outputs
        }
    }
}

struct QueueProgress: Sendable {
    let completed: Int
    var currentFile: String? = nil
    var published: [URL] = []
    var finishedSources: [URL] = []
    var moves: [FileMove] = []
    var preparedImage: ScopedFiles? = nil
}

enum JobState: String {
    case waiting = "Waiting", running = "Running", cancelling = "Cancelling…"
    case completed = "Completed", cancelled = "Cancelled", failed = "Failed"
    var isFinished: Bool { self == .completed || self == .cancelled || self == .failed }
    var canCancel: Bool { self == .waiting || self == .running }
}

struct QueueEntry: Identifiable {
    let id: UUID
    let kind: JobKind
    var filenames: [String]
    var state: JobState = .waiting
    var completedInputs = 0
    var currentFile: String?
    var outputs: [URL] = []
    var error: String?
    var recovery: JobRecovery?
    var canRetry = false

    var diagnostic: String {
        "Operation: \(kind.title(in: .english))\nInputs: \(filenames.joined(separator: ", "))\nCompleted inputs: \(completedInputs)\n\n\(error ?? "")"
    }
}

/// Failed requests keep remaining inputs and their original leases until Retry, Clear Finished, or exit.
@MainActor
final class JobQueue: ObservableObject {
    typealias Executor = @Sendable (JobRequest, @Sendable (QueueProgress) async -> Void) async throws -> [URL]
    @Published private(set) var entries: [QueueEntry] = []
    private var requests: [UUID: JobRequest] = [:]
    private var finishedPaths: [UUID: Set<String>] = [:]
    private var currentTask: Task<Void, Never>?
    private var currentID: UUID?
    private let execute: Executor
    private let successRetention: Duration
    var onIdle: (() -> Void)?
    var onFilesMoved: (([FileMove], ScopedFiles) -> Void)?
    @Published var allowsRetry = true
    var isIdle: Bool { currentTask == nil && !entries.contains { $0.state == .waiting } }
    var activeCount: Int { entries.filter { !$0.state.isFinished }.count }

    init(successRetention: Duration = .seconds(1), execute: @escaping Executor = { try await JobRequest.run($0, progress: $1) }) {
        self.successRetention = successRetention
        self.execute = execute
    }

    @discardableResult func enqueue(_ request: JobRequest) -> UUID {
        let id = UUID()
        requests[id] = request
        entries.append(QueueEntry(id: id, kind: request.kind, filenames: request.filenames))
        startNext()
        return id
    }

    func cancel(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }), entries[index].state.canCancel else { return }
        if currentID == id {
            entries[index].state = .cancelling
            currentTask?.cancel()
        } else {
            entries[index].state = .cancelled
            requests[id] = nil
        }
    }

    func cancelAll() { entries.filter { $0.state.canCancel }.map(\.id).forEach(cancel) }
    func clearFinished() {
        for entry in entries where entry.state.isFinished {
            requests[entry.id] = nil
            finishedPaths[entry.id] = nil
        }
        entries.removeAll { $0.state.isFinished }
    }

    func retry(_ id: UUID) {
        guard allowsRetry, let index = entries.firstIndex(where: { $0.id == id }),
              entries[index].state == .failed, entries[index].canRetry, let request = requests[id] else { return }
        var updated = entries
        var entry = updated.remove(at: index)
        entry.filenames = request.filenames
        entry.state = .waiting
        entry.completedInputs = 0
        entry.currentFile = nil
        entry.error = nil
        entry.recovery = nil
        entry.canRetry = false
        // Retry joins the tail instead of jumping ahead of already waiting jobs.
        updated.append(entry)
        // Publish one coherent list so the window never observes an empty queue during Retry.
        entries = updated
        startNext()
    }
    func waitForCurrentJob() async { await currentTask?.value }

    private func record(_ progress: QueueProgress, for id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }), !entries[index].state.isFinished else { return }
        entries[index].completedInputs = min(entries[index].filenames.count, max(0, progress.completed))
        entries[index].currentFile = progress.currentFile
        entries[index].outputs += progress.published
        finishedPaths[id, default: []].formUnion(progress.finishedSources.map { $0.standardizedFileURL.path })
        if let prepared = progress.preparedImage, case .importedImage = requests[id]?.kind {
            requests[id]?.files = prepared
        }
        let moves = progress.moves.filter { $0.source != $0.destination }
        if !moves.isEmpty, let request = requests[id] {
            let access = request.movedFiles(moves)
            for other in Array(requests.keys) where other != id {
                guard let row = entries.firstIndex(where: { $0.id == other }),
                      entries[row].state == .waiting || entries[row].state == .failed else { continue }
                requests[other] = requests[other]?.relocating(moves, access: access)
                if entries[row].state == .waiting, let next = requests[other] { entries[row].filenames = next.filenames }
            }
            onFilesMoved?(moves, access)
        }
    }

    private func startNext() {
        guard currentTask == nil, let index = entries.firstIndex(where: { $0.state == .waiting }) else { return }
        let id = entries[index].id
        guard let request = requests[id] else { return }
        entries[index].state = .running
        currentID = id
        let execute = execute
        currentTask = Task { [weak self] in
            guard let self else { return }
            let worker = Task.detached(priority: .userInitiated) {
                try await execute(request) { [weak self] update in await self?.record(update, for: id) }
            }
            do {
                let results = try await withTaskCancellationHandler(operation: { try await worker.value },
                                                                    onCancel: { worker.cancel() })
                if let index = entries.firstIndex(where: { $0.id == id }) {
                    let known = Set(entries[index].outputs)
                    entries[index].outputs += results.filter { !known.contains($0) }
                    entries[index].completedInputs = entries[index].filenames.count
                    entries[index].state = Task.isCancelled ? .cancelled : .completed
                }
            } catch {
                if let index = entries.firstIndex(where: { $0.id == id }) {
                    entries[index].state = error is CancellationError || Task.isCancelled ? .cancelled : .failed
                    if entries[index].state == .failed {
                        entries[index].error = error.localizedDescription
                        entries[index].recovery = JobRecovery(error)
                    }
                }
            }
            if let index = entries.firstIndex(where: { $0.id == id }), entries[index].state == .failed {
                requests[id] = requests[id]?.remaining(after: finishedPaths[id] ?? [])
                entries[index].canRetry = requests[id] != nil
                if !entries[index].canRetry {
                    if !entries[index].outputs.isEmpty { entries[index].recovery = .resultsPreserved }
                    else if case .importedImage = entries[index].kind { entries[index].recovery = .newDrag }
                }
            } else { requests[id] = nil }
            finishedPaths[id] = nil
            currentID = nil
            currentTask = nil
            if entries.first(where: { $0.id == id })?.state == .completed {
                let delay = successRetention
                Task { [weak self] in
                    try? await Task.sleep(for: delay)
                    // Cleanup owns a row ID, so it cannot clear a later job or dismiss an error.
                    self?.entries.removeAll { $0.id == id && $0.state == .completed }
                }
            }
            startNext()
            if isIdle { onIdle?() }
        }
    }
}
