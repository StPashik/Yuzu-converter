import Foundation
import YuzuCore

/// Exercises child-process grants inside the signed app using only its own temporary files.
enum AppSelfCheck {
    static func run() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("yuzu-check-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = ConversionEngine()
        let text = root.appendingPathComponent("sample.txt")
        try "Yuzu sandbox check".write(to: text, atomically: true, encoding: .utf8)
        let docx = try await engine.convert(SourceFile(url: text), to: .docx, in: root)[0]
        let restored = try await engine.convert(SourceFile(url: docx), to: .txt, in: root)[0]
        guard try String(contentsOf: restored, encoding: .utf8).contains("Yuzu sandbox check") else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let csv = root.appendingPathComponent("values.csv")
        try "name,value\nYuzu,42\n".write(to: csv, atomically: true, encoding: .utf8)
        let xlsx = try await engine.convert(SourceFile(url: csv), to: .xlsx, in: root)[0]
        _ = try await engine.convert(SourceFile(url: xlsx), to: .csv, in: root)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        let zip = root.appendingPathComponent("sample.zip")
        process.arguments = ["-q", zip.path, text.lastPathComponent]
        process.currentDirectoryURL = root
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.executableRuntimeMismatch) }
        let tar = try await engine.convert(SourceFile(url: zip), to: .tar, in: root)[0]
        _ = try await engine.convert(SourceFile(url: tar), to: .zip, in: root)
        _ = try FileOperations.compress([text, csv], in: root)
    }
}
