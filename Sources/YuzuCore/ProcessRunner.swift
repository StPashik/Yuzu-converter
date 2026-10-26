import Foundation
import Darwin

struct ProcessResult {
    let status: Int32
    let output: String
}

enum ProcessRunner {
    static func run(_ executable: URL, _ arguments: [String], directory: URL? = nil, timeout: TimeInterval = 300) throws -> ProcessResult {
        try Task.checkCancellation()
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = directory
        var environment = ProcessInfo.processInfo.environment
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
        if Date() >= deadline { throw ConversionError.failed("Движок не завершил обработку за \(Int(timeout)) секунд.") }
        return ProcessResult(status: process.terminationStatus, output: buffer.string)
    }

    static func checked(_ executable: URL, _ arguments: [String], directory: URL? = nil) throws -> String {
        let result = try run(executable, arguments, directory: directory)
        guard result.status == 0 else {
            throw ConversionError.failed("\(executable.lastPathComponent): \(result.output.suffix(2000))")
        }
        return result.output
    }
}

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
