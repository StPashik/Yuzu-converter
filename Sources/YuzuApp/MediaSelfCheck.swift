import Foundation
import YuzuCore

/// Runs the shipped helpers inside the signed Sandbox, independent of Homebrew and developer overrides.
enum MediaSelfCheck {
    static func run(in directory: URL) async throws {
        let helpers = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers")
        func run(_ name: String, _ arguments: [String]) throws -> String {
            let process = Process()
            process.executableURL = helpers.appendingPathComponent(name)
            process.arguments = arguments
            process.standardInput = FileHandle.nullDevice
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw ConversionError.failed("Bundled \(name): \(String(decoding: output.suffix(2000), as: UTF8.self))")
            }
            return String(decoding: output, as: UTF8.self)
        }
        for tool in ["ffmpeg", "ffprobe"] {
            guard try run(tool, ["-version"]).hasPrefix("\(tool) version 9.0.2 ") else {
                throw ConversionError.failed("The bundled \(tool) version does not match the source manifest.")
            }
        }
        let protocols = try run("ffmpeg", ["-hide_banner", "-protocols"])
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.hasSuffix(":") }
        guard Set(protocols) == ["fd", "file", "pipe"],
              try run("ffmpeg", ["-hide_banner", "-L"]).contains("GNU Lesser General Public") else {
            throw ConversionError.failed("The bundled media build has unexpected protocols or licensing.")
        }
        let input = directory.appendingPathComponent("video.mov")
        _ = try run("ffmpeg", ["-v", "error", "-f", "lavfi", "-i", "testsrc2=size=192x144:rate=10:duration=1",
            "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=44100:duration=1",
            "-c:v", "mpeg4", "-c:a", "aac", input.path])
        let original = try Data(contentsOf: input)
        let source = try SourceFile(url: input)
        let engine = ConversionEngine()
        let expected: Set<FileFormat> = [.mp4, .mkv, .webm, .avi, .wmv, .gif, .mp3]
        guard Set(engine.targets(for: [source])) == expected else {
            throw ConversionError.failed("The shipped video wheel is missing a required target.")
        }
        for target in engine.targets(for: [source]) {
            let options: ConversionOptions = target == .gif ? .init(gifFrameRate: 5, gifMaxWidth: 80)
                : target == .mp3 ? .init(preserveMetadata: false, audioBitrate: 128)
                : .init(quality: .high, preserveMetadata: false, videoMaxHeight: 72)
            let output = try await engine.convert(source, to: target, in: directory, options: options)[0]
            guard try SourceFile(url: output).format == target else { throw CocoaError(.fileReadCorruptFile) }
            let probe = try run("ffprobe", ["-v", "error", "-count_frames", "-show_entries",
                "stream=codec_type,nb_read_frames,width,height", "-of", "json", output.path])
            guard let object = try JSONSerialization.jsonObject(with: Data(probe.utf8)) as? [String: Any],
                  let streams = object["streams"] as? [[String: Any]],
                  let track = streams.first(where: { $0["codec_type"] as? String == (target == .mp3 ? "audio" : "video") }),
                  let count = Int(track["nb_read_frames"] as? String ?? ""), count > 1 else {
                throw ConversionError.failed("\(target.label) did not contain decodable media frames.")
            }
            if target != .mp3 {
                guard let height = track["height"] as? Int, height <= 72 else { throw CocoaError(.fileReadCorruptFile) }
            }
            _ = try run("ffmpeg", ["-v", "error", "-i", output.path, "-f", "null", "-"])
            if target != .mp3 {
                let restored = try await engine.convert(SourceFile(url: output), to: .mov, in: directory)[0]
                _ = try run("ffmpeg", ["-v", "error", "-i", restored.path, "-f", "null", "-"])
            }
            print("Bundled media: MOV → \(target.label), probe, decode, and return conversion passed")
        }
        guard try Data(contentsOf: input) == original else { throw CocoaError(.fileReadCorruptFile) }
    }
}
