import Foundation
import Darwin

/// Exit status and the bounded UTF-8 tail of merged stdout/stderr, intended for diagnostics rather than binary data.
struct ProcessResult {
    let status: Int32
    let output: String
}

/// Runs an executable directly with argument arrays, avoiding shell interpretation of user-supplied paths.
/// Blocking process waits belong on a background task; cancellation/timeout terminates the direct child.
enum ProcessRunner {
    /// Drains output while waiting so a verbose tool cannot fill its pipe and deadlock the conversion.
    /// Cancellation observed while polling throws CancellationError; timeouts throw; nonzero exits remain inspectable.
    static func run(_ executable: URL, _ arguments: [String], directory: URL? = nil, timeout: TimeInterval = 300) throws -> ProcessResult {
        try Task.checkCancellation()
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = directory
        var environment = ProcessInfo.processInfo.environment
        // Backend diagnostics stay English even when the application UI uses a different language.
        environment["LC_ALL"] = "en_US.UTF-8"
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        let buffer = ProcessBuffer()
        pipe.fileHandleForReading.readabilityHandler = { handle in buffer.append(handle.availableData) }
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        var cancelled = false
        while process.isRunning {
            if Task.isCancelled || Date() >= deadline {
                cancelled = Task.isCancelled
                // Give the tool a short cleanup window, then kill it so a cancelled job cannot wait indefinitely.
                process.terminate()
                let terminationDeadline = Date().addingTimeInterval(2)
                while process.isRunning && Date() < terminationDeadline { Thread.sleep(forTimeInterval: 0.01) }
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                break
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        process.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil
        buffer.append(pipe.fileHandleForReading.readDataToEndOfFile())
        if cancelled { throw CancellationError() }
        if Date() >= deadline { throw ConversionError.failed("The engine did not finish processing within \(Int(timeout)) seconds.") }
        return ProcessResult(status: process.terminationStatus, output: buffer.string)
    }

    /// Converts a nonzero exit into a concise diagnostic; successful output is still the bounded merged log tail.
    static func checked(_ executable: URL, _ arguments: [String], directory: URL? = nil) throws -> String {
        let result = try run(executable, arguments, directory: directory)
        guard result.status == 0 else {
            throw ConversionError.failed("\(executable.lastPathComponent): \(result.output.suffix(2000))")
        }
        return result.output
    }
}

/// Pipe callbacks and the waiting task share this buffer; its lock protects a fixed-size diagnostic tail.
private final class ProcessBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    func append(_ next: Data) {
        lock.lock(); defer { lock.unlock() }
        data.append(next)
        if data.count > 262_144 { data.removeFirst(data.count - 262_144) }
    }
    var string: String {
        lock.lock(); defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}

/// Optional backend locations, not proof that an executable has every required codec or permission.
/// Sandboxed releases accept bundled tools only; environment/Homebrew discovery is for development builds.
struct Tools: Sendable {
    let ffmpeg: URL?
    let ffprobe: URL?
    let office: URL?
    init() {
        ffmpeg = Self.find("ffmpeg", environment: "YUZU_FFMPEG")
        ffprobe = Self.find("ffprobe", environment: "YUZU_FFPROBE")
        office = Self.find("soffice", environment: "YUZU_LIBREOFFICE", extra: ["/Applications/LibreOffice.app/Contents/MacOS/soffice"])
    }
    private static func find(_ name: String, environment: String, extra: [String] = []) -> URL? {
        let env = ProcessInfo.processInfo.environment
        let resource = Bundle.main.resourceURL?.appendingPathComponent("Tools/" + name).path
        if Bundle.main.object(forInfoDictionaryKey: "YuzuSandboxed") as? Bool == true {
            return resource.flatMap { FileManager.default.isExecutableFile(atPath: $0) ? URL(fileURLWithPath: $0) : nil }
        }
        let paths = [env[environment], resource].compactMap { $0 } + extra + ["/opt/homebrew/bin/" + name, "/usr/local/bin/" + name] + (env["PATH"] ?? "").split(separator: ":").map { String($0) + "/" + name }
        return paths.first { FileManager.default.isExecutableFile(atPath: $0) }.map { URL(fileURLWithPath: $0) }
    }
}
