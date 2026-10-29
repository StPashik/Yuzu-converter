import Foundation
import XCTest
@testable import YuzuCore

private actor TrackWarnings {
    var values: [String] = []
    func append(_ messages: [String]) { values += messages }
}

final class MediaTrackTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("yuzu-tracks-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testMultipleAudioTextSubtitlesChaptersAndLanguagesAcrossContainers() async throws {
        let (ffmpeg, probe) = try tools()
        let input = try fixture(ffmpeg)
        let original = try Data(contentsOf: input)
        let source = try SourceFile(url: input)
        for target: FileFormat in [.mp4, .mov, .webm, .avi, .wmv] {
            let warnings = TrackWarnings()
            let output = try await ConversionEngine().convert(source, to: target, in: directory,
                options: .init(videoMaxHeight: 72), onWarning: { await warnings.append($0) })[0]
            let result = try MediaTracks(url: output, probe: probe)
            XCTAssertEqual(result.streams.filter { $0.codec_type == "audio" }.count, 2, target.label)
            let compatible = [.mp4, .mov, .webm].contains(target)
            XCTAssertEqual(result.streams.filter { $0.codec_type == "subtitle" }.count, compatible ? 1 : 0, target.label)
            XCTAssertEqual(result.chapterCount, compatible ? 2 : 0, target.label)
            let messages = await warnings.values
            if !compatible { XCTAssertFalse(messages.isEmpty, target.label) }
            if target == .mov { XCTAssertTrue(messages.contains { $0.contains("playback flags") }, target.label) }
            let metadata = try ProcessRunner.checked(probe, ["-v", "error", "-show_streams", "-show_chapters", "-of", "json", output.path])
            let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            try metadata.write(to: project.appendingPathComponent(".build/track-inventory-" + target.rawValue + ".json"), atomically: false, encoding: .utf8)
            if compatible { XCTAssertTrue(metadata.contains("eng"), target.label); XCTAssertTrue(metadata.contains("fra"), target.label) }
            if compatible {
                let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(metadata.utf8)) as? [String: Any])
                let streams = try XCTUnwrap(object["streams"] as? [[String: Any]])
                let audio = streams.filter { $0["codec_type"] as? String == "audio" }
                XCTAssertEqual((audio[0]["disposition"] as? [String: Int])?["default"], 1, target.label)
                XCTAssertEqual((audio[1]["disposition"] as? [String: Int])?["default"], 0, target.label)
                let subtitle = streams.first { $0["codec_type"] as? String == "subtitle" }
                XCTAssertEqual((subtitle?["disposition"] as? [String: Int])?["forced"], target == .mov ? 0 : 1, target.label)
                XCTAssertTrue(metadata.contains("Introduction")); XCTAssertTrue(metadata.contains("Second chapter"))
                let subtitles = try ProcessRunner.checked(ffmpeg, ["-v", "error", "-i", output.path, "-map", "0:s:0", "-f", "srt", "-"])
                XCTAssertTrue(subtitles.contains("Hello subtitle"))
                let restored = try await ConversionEngine().convert(SourceFile(url: output), to: .mkv, in: directory)[0]
                XCTAssertEqual(try MediaTracks(url: restored, probe: probe).streams.filter { $0.codec_type == "audio" }.count, 2)
            }
            for track in ["0:a:0", "0:a:1"] {
                _ = try ProcessRunner.checked(ffmpeg, ["-v", "error", "-i", output.path, "-map", track, "-f", "null", "-"])
            }
        }
        let clean = try await ConversionEngine().convert(source, to: .mp4, in: directory,
            options: .init(preserveMetadata: false))[0]
        let result = try MediaTracks(url: clean, probe: probe)
        XCTAssertEqual(result.chapterCount, 0)
        XCTAssertEqual(result.streams.filter { $0.codec_type == "audio" }.count, 2)
        XCTAssertEqual(result.streams.filter { $0.codec_type == "subtitle" }.count, 1)
        let tags = try ProcessRunner.checked(probe, ["-v", "error", "-show_entries", "stream_tags:format_tags", "-of", "json", clean.path])
        XCTAssertFalse(tags.contains("Private video")); XCTAssertFalse(tags.contains("fra"))
        XCTAssertEqual(try Data(contentsOf: input), original)
    }

    func testASSConversionProducesAnExplicitStylingWarning() async throws {
        let (ffmpeg, probe) = try tools()
        let source = try fixture(ffmpeg)
        let styled = directory.appendingPathComponent("Styled.mkv")
        _ = try ProcessRunner.checked(ffmpeg, ["-v", "error", "-i", source.path, "-map", "0", "-c", "copy", "-c:s", "ass", styled.path])
        let warnings = TrackWarnings()
        let output = try await ConversionEngine().convert(SourceFile(url: styled), to: .mp4, in: directory,
            onWarning: { await warnings.append($0) })[0]
        let messages = await warnings.values
        XCTAssertTrue(messages.contains { $0.contains("Styled subtitles") })
        XCTAssertEqual(try MediaTracks(url: output, probe: probe).streams.filter { $0.codec_type == "subtitle" }.count, 1)
    }

    private func tools() throws -> (URL, URL) {
        guard let ffmpeg = Tools().ffmpeg, let probe = Tools().ffprobe else {
            if ProcessInfo.processInfo.environment["YUZU_MEDIA_REQUIRED"] == "1" { throw ConversionError.failed("Required bundled media tools are missing.") }
            throw XCTSkip("Bundled media tools are unavailable.")
        }
        return (ffmpeg, probe)
    }

    private func fixture(_ ffmpeg: URL) throws -> URL {
        let subtitles = directory.appendingPathComponent("Subtitles.srt")
        try "1\n00:00:00,000 --> 00:00:00,900\nHello subtitle\n".write(to: subtitles, atomically: false, encoding: .utf8)
        let metadata = directory.appendingPathComponent("Metadata.txt")
        try """
        ;FFMETADATA1
        title=Private video
        [CHAPTER]
        TIMEBASE=1/1000
        START=0
        END=500
        title=Introduction
        [CHAPTER]
        TIMEBASE=1/1000
        START=500
        END=1000
        title=Second chapter
        """.write(to: metadata, atomically: false, encoding: .utf8)
        let input = directory.appendingPathComponent("Multitrack.mkv")
        _ = try ProcessRunner.checked(ffmpeg, ["-v", "error", "-f", "lavfi", "-i", "testsrc2=size=192x144:rate=10:duration=1",
            "-f", "lavfi", "-i", "sine=frequency=440:duration=1", "-f", "lavfi", "-i", "sine=frequency=880:duration=1",
            "-i", subtitles.path, "-i", metadata.path, "-map", "0:v", "-map", "1:a", "-map", "2:a", "-map", "3:s",
            "-map_metadata", "4", "-map_chapters", "4", "-metadata:s:a:0", "language=eng", "-metadata:s:a:1", "language=fra",
            "-metadata:s:s:0", "language=eng", "-disposition:a:0", "default", "-disposition:a:1", "0", "-disposition:s:0", "forced",
            "-c:v", "mpeg4", "-c:a", "aac", "-c:s", "srt", input.path])
        return input
    }
}
