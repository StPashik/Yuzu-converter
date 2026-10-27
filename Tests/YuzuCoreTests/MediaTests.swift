import Foundation
import XCTest
@testable import YuzuCore

final class MediaTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("yuzu-media-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    private func tools() throws -> (URL, URL) {
        guard let ffmpeg = Tools().ffmpeg, let ffprobe = Tools().ffprobe else {
            if ProcessInfo.processInfo.environment["YUZU_MEDIA_REQUIRED"] == "1" {
                XCTFail("Release verification requires both pinned media executables.")
                throw ConversionError.failed("Required media executables are missing.")
            }
            throw XCTSkip("Build media tools or set YUZU_FFMPEG and YUZU_FFPROBE.")
        }
        return (ffmpeg, ffprobe)
    }

    private func fixture(_ ffmpeg: URL, audio: Bool = true) throws -> URL {
        let source = directory.appendingPathComponent(audio ? "source.mov" : "silent.mov")
        var arguments = ["-v", "error", "-f", "lavfi", "-i", "testsrc2=size=192x144:rate=10:duration=1"]
        if audio { arguments += ["-f", "lavfi", "-i", "sine=frequency=440:sample_rate=44100:duration=1", "-c:a", "aac"] }
        arguments += ["-c:v", "mpeg4", "-pix_fmt", "yuv420p", source.path]
        _ = try ProcessRunner.checked(ffmpeg, arguments)
        return source
    }

    func testEveryVideoInputAndOutputWithRealStreams() async throws {
        let (ffmpeg, ffprobe) = try tools()
        let input = try fixture(ffmpeg)
        let original = try Data(contentsOf: input)
        let engine = ConversionEngine()
        XCTAssertEqual(engine.availability(from: .mov, to: .mp3), .dependsOnFile)
        let formats: [FileFormat] = [.mp4, .mov, .mkv, .webm, .avi, .wmv, .gif]
        var sources = [try SourceFile(url: input)]
        for target in formats where target != .mov {
            sources.append(try SourceFile(url: await engine.convert(sources[0], to: target, in: directory)[0]))
        }
        for source in sources {
            let expected = formats.filter { $0 != source.format && !(source.format == .gif && $0 == .gif) }
                + (source.format == .gif ? [] : [.mp3])
            XCTAssertEqual(Set(engine.targets(for: [source])), Set(expected), source.format.label)
            for target in engine.targets(for: [source]) {
                let output = try await engine.convert(source, to: target, in: directory)[0]
                XCTAssertEqual(try SourceFile(url: output).format, target, "\(source.format) → \(target)")
                let streams = try ProcessRunner.checked(ffprobe, ["-v", "error", "-count_frames",
                    "-show_entries", "stream=codec_type,nb_read_frames", "-of", "json", output.path])
                let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(streams.utf8)) as? [String: Any])
                let tracks = try XCTUnwrap(object["streams"] as? [[String: Any]])
                let kind = target == .mp3 ? "audio" : "video"
                let track = try XCTUnwrap(tracks.first { $0["codec_type"] as? String == kind })
                XCTAssertGreaterThan(Int(track["nb_read_frames"] as? String ?? "0") ?? 0, 1)
                _ = try ProcessRunner.checked(ffmpeg, ["-v", "error", "-i", output.path, "-f", "null", "-"])
            }
        }
        XCTAssertEqual(try Data(contentsOf: input), original)
    }

    func testSilentVideoHidesMP3AndDamagedInputPublishesNothing() async throws {
        let (ffmpeg, _) = try tools()
        let engine = ConversionEngine()
        XCTAssertFalse(engine.targets(for: [try SourceFile(url: fixture(ffmpeg, audio: false))]).contains(.mp3))
        let damaged = directory.appendingPathComponent("damaged.mp4")
        try Data([0, 0, 0, 24] + Array("ftypisom".utf8) + Array(repeating: 0, count: 32)).write(to: damaged)
        let before = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        do {
            _ = try await engine.convert(SourceFile(url: damaged), to: .mkv, in: directory)
            XCTFail("A container header without media must fail.")
        } catch is ConversionError { }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), before)
    }

    func testOpenDescriptorsKeepSeekingAndNeverOverwriteExistingFiles() throws {
        let (ffmpeg, ffprobe) = try tools()
        let source = try fixture(ffmpeg)
        let output = directory.appendingPathComponent("copy.mov")
        _ = try ProcessRunner.checked(URL(fileURLWithPath: "/bin/cat"), [], input: source, output: output)
        XCTAssertEqual(try Data(contentsOf: source), try Data(contentsOf: output))
        let streams = try ProcessRunner.checked(ffprobe, ["-v", "error", "-protocol_whitelist", "fd",
            "-show_entries", "stream=codec_type", "-of", "csv=p=0", "fd:"], input: output)
        XCTAssertTrue(streams.contains("video"))
        XCTAssertTrue(streams.contains("audio"))
        XCTAssertThrowsError(try ProcessRunner.checked(URL(fileURLWithPath: "/bin/cat"), [], input: source, output: output))
        XCTAssertEqual(try Data(contentsOf: source), try Data(contentsOf: output))
    }
}
