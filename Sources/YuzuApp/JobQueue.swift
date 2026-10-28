import AppKit
import Combine
import YuzuCore

enum JobKind: Sendable {
    case conversion(FileFormat), move, compress
    func title(in language: AppLanguage) -> String {
        switch self {
        case .conversion(let format): return L10n.string("Converting to %@", language: language, arguments: [format.label])
        case .move: return L10n.string("Moving files", language: language)
        case .compress: return L10n.string("Compressing to ZIP", language: language)
        }
    }
}

struct JobRequest: Sendable {
    let files: ScopedFiles
    let kind: JobKind
    let destinations: [URL]
    let options: ConversionOptions
    private let destinationAccess: ScopedFiles

    init(files: ScopedFiles, kind: JobKind, destinations: [URL], options: ConversionOptions = .init()) {
        self.files = files
        self.kind = kind
        self.destinations = destinations
        self.options = options
        // Powerbox already started these scopes; transfer them without starting a second access.
        destinationAccess = ScopedFiles([], activeGrants: destinations)
    }

    static func run(_ request: JobRequest, progress: @Sendable (QueueProgress) async -> Void) async throws -> [URL] {
        guard !request.files.urls.isEmpty else { throw ConversionError.invalid("Choose at least one file.") }
        switch request.kind {
        case .conversion(let target):
            guard request.destinations.count == request.files.urls.count else {
                throw ConversionError.invalid("Every source needs its own output folder.")
            }
            let engine = ConversionEngine()
            var outputs: [URL] = []
            for (index, url) in request.files.urls.enumerated() {
                try Task.checkCancellation()
                await progress(QueueProgress(completed: index, currentFile: url.lastPathComponent))
                let result = try await engine.convert(SourceFile(url: url), to: target,
                    in: request.destinations[index], options: request.options)
                outputs += result
                await progress(QueueProgress(completed: index + 1, published: result))
            }
            return outputs
        case .move, .compress:
            guard request.destinations.count == 1 else { throw ConversionError.invalid("Choose one destination folder.") }
            await progress(QueueProgress(completed: 0, currentFile: request.files.urls.first?.lastPathComponent))
            let outputs: [URL]
            if case .move = request.kind {
                // Keep the Core batch contract: normalizing folders/children separately would move files twice.
                var published: [URL] = []
                var completed = 0
                do {
                    outputs = try FileOperations.copy(request.files.urls, to: request.destinations[0], move: true) { source, result in
                        published.append(result)
                        completed += request.files.urls.filter {
                            $0.standardizedFileURL == source || $0.standardizedFileURL.path.hasPrefix(source.path + "/")
                        }.count
                    }
                } catch {
                    await progress(QueueProgress(completed: completed, published: published))
                    throw error
                }
            } else {
                outputs = [try FileOperations.compress(request.files.urls, in: request.destinations[0],
                                                       compression: request.options.compression)]
            }
            await progress(QueueProgress(completed: request.files.urls.count, published: outputs))
            return outputs
        }
    }
}

struct QueueProgress: Sendable {
    let completed: Int
    var currentFile: String? = nil
    var published: [URL] = []
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
    let filenames: [String]
    var state: JobState = .waiting
    var completedInputs = 0
    var currentFile: String?
    var outputs: [URL] = []
    var error: String?
}

/// The serial worker owns grants; finished UI rows retain only labels and published result URLs.
@MainActor
final class JobQueue: ObservableObject {
    typealias Executor = @Sendable (JobRequest, @Sendable (QueueProgress) async -> Void) async throws -> [URL]
    @Published private(set) var entries: [QueueEntry] = []
    private var requests: [UUID: JobRequest] = [:]
    private var currentTask: Task<Void, Never>?
    private var currentID: UUID?
    private let execute: Executor
    var onIdle: (() -> Void)?
    var isIdle: Bool { currentTask == nil && !entries.contains { $0.state == .waiting } }
    var activeCount: Int { entries.filter { !$0.state.isFinished }.count }

    init(execute: @escaping Executor = JobRequest.run) { self.execute = execute }

    @discardableResult func enqueue(_ request: JobRequest) -> UUID {
        let id = UUID()
        requests[id] = request
        entries.append(QueueEntry(id: id, kind: request.kind, filenames: request.files.urls.map(\.lastPathComponent)))
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
    func clearFinished() { entries.removeAll { $0.state.isFinished } }
    func waitForCurrentJob() async { await currentTask?.value }

    private func record(_ progress: QueueProgress, for id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }), !entries[index].state.isFinished else { return }
        entries[index].completedInputs = min(entries[index].filenames.count, max(0, progress.completed))
        entries[index].currentFile = progress.currentFile
        entries[index].outputs += progress.published
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
                    entries[index].outputs = results
                    entries[index].completedInputs = entries[index].filenames.count
                    entries[index].state = Task.isCancelled ? .cancelled : .completed
                }
            } catch {
                if let index = entries.firstIndex(where: { $0.id == id }) {
                    entries[index].state = error is CancellationError || Task.isCancelled ? .cancelled : .failed
                    if entries[index].state == .failed { entries[index].error = error.localizedDescription }
                }
            }
            requests[id] = nil
            currentID = nil
            currentTask = nil
            startNext()
            if isIdle { onIdle?() }
        }
    }
}
