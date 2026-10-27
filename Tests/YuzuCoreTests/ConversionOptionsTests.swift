import AppKit
import AVFoundation
import ImageIO
import XCTest
@testable import YuzuCore

final class ConversionOptionsTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("yuzu-option-tests-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testProfilesRoundTripAndRejectInvalidOrUnavailableSettings() throws {
        let options = ConversionOptions(quality: .high, preserveMetadata: false, videoMaxHeight: 1080,
                                        audioBitrate: 256, audioSampleDepth: .bit24, gifFrameRate: 24,
                                        gifMaxWidth: 720, compression: .maximum, epubReflowVersion: 3)
        let encoded = try JSONEncoder().encode(options)
        XCTAssertEqual(try JSONDecoder().decode(ConversionOptions.self, from: encoded), options)
        var invalidEnum = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        invalidEnum["quality"] = "unknown"
        XCTAssertThrowsError(try JSONDecoder().decode(ConversionOptions.self, from: JSONSerialization.data(withJSONObject: invalidEnum)))
        for value in [Int.min, 0, Int.max] {
            XCTAssertThrowsError(try ConversionOptions(videoMaxHeight: value).validate(for: .mp4))
            XCTAssertThrowsError(try ConversionOptions(audioBitrate: value).validate(for: .m4a))
            XCTAssertThrowsError(try ConversionOptions(gifFrameRate: value).validate(for: .gif))
            XCTAssertThrowsError(try ConversionOptions(gifMaxWidth: value).validate(for: .gif))
            XCTAssertThrowsError(try ConversionOptions(epubReflowVersion: value).validate(for: .epub))
        }
        XCTAssertThrowsError(try ConversionOptions(quality: .high).validate(for: .png))
        XCTAssertThrowsError(try ConversionOptions(preserveMetadata: false).validate(for: .wav))
        XCTAssertThrowsError(try ConversionOptions(audioSampleDepth: .bit24).validate(for: .pdf))
        XCTAssertThrowsError(try ConversionOptions(compression: .maximum).validate(for: .tar))
        XCTAssertThrowsError(try ConversionOptions(epubLayout: .preservePages).validate(for: .epub))
        XCTAssertThrowsError(try ConversionOptions(pdfOfficeLayout: .preservePages).validate(for: .docx))
        for format in FileFormat.allCases { XCTAssertNoThrow(try ConversionOptions().validate(for: format)) }
    }

    func testAvailabilityUsesTheExistingCandidateAndBackendGates() {
        let engine = ConversionEngine()
        for format in FileFormat.allCases { XCTAssertEqual(engine.availability(from: format, to: format), .unavailable) }
        XCTAssertEqual(engine.availability(from: .pdf, to: .docx), .unavailable)
        XCTAssertEqual(engine.availability(from: .html, to: .pdf), .unavailable)
        XCTAssertEqual(engine.availability(from: .pdf, to: .jpg), .available)
        XCTAssertNotEqual(engine.availability(from: .wav, to: .m4a), .unavailable)
        if Tools().ffmpeg == nil {
            XCTAssertEqual(engine.availability(from: .wav, to: .m4a), .dependsOnFile)
            XCTAssertEqual(engine.availability(from: .mov, to: .mp4), .dependsOnFile)
            XCTAssertEqual(engine.availability(from: .gif, to: .mp4), .unavailable)
        }
    }

    func testJPEGQualityChangesRealOutputAndLeavesTheOriginalUnchanged() async throws {
        let input = directory.appendingPathComponent("detail.png")
        try NativeDocuments.writeImage(pattern(width: 256, height: 256), to: .png, output: input)
        let original = try Data(contentsOf: input)
        let source = try SourceFile(url: input)
        let engine = ConversionEngine()
        let compact = try await engine.convert(source, to: .jpg, in: directory, options: .init(quality: .compact))[0]
        let high = try await engine.convert(source, to: .jpg, in: directory, options: .init(quality: .high))[0]
        XCTAssertLessThan(try Data(contentsOf: compact).count, try Data(contentsOf: high).count)
        for output in [compact, high] {
            let image = try XCTUnwrap(CGImageSourceCreateWithURL(output as CFURL, nil))
            let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(image, 0, nil))
            XCTAssertEqual(decoded.width, 256)
            XCTAssertEqual(decoded.height, 256)
        }
        XCTAssertEqual(try Data(contentsOf: input), original)
        XCTAssertNotEqual(compact, high)
    }

    func testMetadataRemovalRetainsOrientationColorAndEveryTIFFFrame() async throws {
        let input = directory.appendingPathComponent("private.tiff")
        let writer = try XCTUnwrap(CGImageDestinationCreateWithURL(input as CFURL, "public.tiff" as CFString, 2, nil))
        let properties: [String: Any] = [
            kCGImagePropertyOrientation as String: 6,
            kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifDateTimeOriginal as String: "2020:01:02 03:04:05"],
            kCGImagePropertyTIFFDictionary as String: [kCGImagePropertyTIFFArtist as String: "Private Artist"],
            kCGImagePropertyGPSDictionary as String: [kCGImagePropertyGPSLatitude as String: 51.5, kCGImagePropertyGPSLatitudeRef as String: "N",
                                                     kCGImagePropertyGPSLongitude as String: 0.1, kCGImagePropertyGPSLongitudeRef as String: "E"]
        ]
        for _ in 0..<2 { CGImageDestinationAddImage(writer, try pattern(width: 60, height: 40), properties as CFDictionary) }
        XCTAssertTrue(CGImageDestinationFinalize(writer))
        let original = try Data(contentsOf: input)
        let engine = ConversionEngine()
        let source = try SourceFile(url: input)
        let kept = try await engine.convert(source, to: .jpg, in: directory)[0]
        let removed = try await engine.convert(source, to: .jpg, in: directory, options: .init(preserveMetadata: false))[0]
        let keptProperties = try imageProperties(kept)
        XCTAssertNotNil(keptProperties[kCGImagePropertyGPSDictionary as String])
        try assertPrivateMetadataAbsent(removed)
        let stripped = try XCTUnwrap(CGImageSourceCreateWithURL(removed as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(stripped, 0, nil))
        XCTAssertEqual(image.width, 40)
        XCTAssertEqual(image.height, 60)
        XCTAssertEqual(image.colorSpace?.model, .rgb)
        let tiff = directory.appendingPathComponent("stripped-frames.tiff")
        try NativeDocuments.image(input, to: .tiff, output: tiff, options: .init(preserveMetadata: false))
        let frames = try XCTUnwrap(CGImageSourceCreateWithURL(tiff as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetCount(frames), 2)
        for index in 0..<2 { try assertPrivateMetadataAbsent(tiff, at: index) }
        XCTAssertEqual(try Data(contentsOf: input), original)
    }

    func testPDFJPEGQualityStillPublishesAllPagesAt300DPI() async throws {
        let input = directory.appendingPathComponent("pages.pdf")
        var box = CGRect(x: 0, y: 0, width: 72, height: 144)
        let context = try XCTUnwrap(CGContext(input as CFURL, mediaBox: &box, nil))
        for _ in 0..<2 {
            context.beginPDFPage(nil)
            context.draw(try pattern(width: 100, height: 200), in: box)
            context.endPDFPage()
        }
        context.closePDF()
        let outputs = try await ConversionEngine().convert(SourceFile(url: input), to: .jpg, in: directory,
                                                            options: .init(quality: .compact, preserveMetadata: false))
        XCTAssertEqual(outputs.count, 2)
        for output in outputs {
            let properties = try imageProperties(output)
            XCTAssertEqual((properties[kCGImagePropertyPixelWidth as String] as? NSNumber)?.intValue, 300)
            XCTAssertEqual((properties[kCGImagePropertyPixelHeight as String] as? NSNumber)?.intValue, 600)
            XCTAssertEqual((properties[kCGImagePropertyDPIWidth as String] as? NSNumber)?.doubleValue ?? 0, 300, accuracy: 0.1)
        }
    }

    func testNativePCMDepthsAndMatchSourceRetainRateChannelsAndFrames() async throws {
        let source = try SourceFile(url: audioFixture())
        let original = try Data(contentsOf: source.url)
        for depth in AudioSampleDepth.allCases {
            let output = directory.appendingPathComponent("depth-\(depth.rawValue).wav")
            try await NativeMedia.convert(source, to: .wav, output: output, options: .init(audioSampleDepth: depth))
            let decoded = try AVAudioFile(forReading: output)
            let settings = decoded.fileFormat.settings
            let expected = depth == .bit16 ? 16 : depth == .bit24 || depth == .matchSource ? 24 : 32
            XCTAssertEqual((settings[AVLinearPCMBitDepthKey] as? NSNumber)?.intValue, expected, depth.rawValue)
            XCTAssertEqual(settings[AVLinearPCMIsFloatKey] as? Bool ?? false, depth == .float32)
            XCTAssertEqual(decoded.fileFormat.sampleRate, 44_100)
            XCTAssertEqual(decoded.fileFormat.channelCount, 1)
            XCTAssertEqual(decoded.length, 44_100)
        }
        XCTAssertEqual(try Data(contentsOf: source.url), original)
    }

    func testNativeInt32AndMatchSourcePreserveLowSampleBits() async throws {
        let samples: [Int32] = [1, -1, 16_777_217, -16_777_217, 0x12345679, -0x12345679, .max - 1, .min + 1]
        var bytes = Data()
        for sample in samples {
            var value = sample.littleEndian
            withUnsafeBytes(of: &value) { bytes.append(contentsOf: $0) }
        }
        // Write literal PCM bytes so the fixture itself cannot lose bits through a Float32 writer.
        let input = try waveFixture("int32.wav", bits: 32, format: 1, samples: bytes)
        let source = try SourceFile(url: input)
        XCTAssertEqual(try integerSamples(input), samples)
        let original = try Data(contentsOf: input)
        for depth: AudioSampleDepth in [.bit32, .matchSource] {
            let output = directory.appendingPathComponent("exact-\(depth.rawValue).aiff")
            try await NativeMedia.convert(source, to: .aiff, output: output, options: .init(audioSampleDepth: depth))
            XCTAssertEqual(try integerSamples(output), samples, depth.rawValue)
        }
        XCTAssertEqual(try Data(contentsOf: input), original)
    }

    func testMatchingFloat64IsRejectedWithoutPublishingATruncatedOutput() async throws {
        var bytes = Data()
        for sample in [0.1234567890123456, -0.1234567890123456] {
            var value = sample.bitPattern.littleEndian
            withUnsafeBytes(of: &value) { bytes.append(contentsOf: $0) }
        }
        let input = try waveFixture("float64.wav", bits: 64, format: 3, samples: bytes)
        let file = try AVAudioFile(forReading: input)
        XCTAssertEqual((file.fileFormat.settings[AVLinearPCMBitDepthKey] as? NSNumber)?.intValue, 64)
        XCTAssertEqual(file.fileFormat.settings[AVLinearPCMIsFloatKey] as? Bool, true)
        XCTAssertThrowsError(try NativeMedia.resolvedDepth(.matchSource, source: input))
        let original = try Data(contentsOf: input)
        let before = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        do {
            _ = try await ConversionEngine().convert(SourceFile(url: input), to: .aiff, in: directory,
                                                      options: .init(audioSampleDepth: .matchSource))
            XCTFail("Match source must not silently convert Float64 to Float32")
        } catch is ConversionError { }
        XCTAssertEqual(try Data(contentsOf: input), original)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), before)
    }

    func testNativeAACUsesRequestedBitrateAndRemovesDescriptiveMetadata() async throws {
        let input = try audioFixture()
        let tagged = directory.appendingPathComponent("tagged.m4a")
        let tagger = try XCTUnwrap(AVAssetExportSession(asset: AVURLAsset(url: input), presetName: AVAssetExportPresetAppleM4A))
        tagger.outputURL = tagged
        tagger.outputFileType = .m4a
        tagger.metadata = [titleMetadata("Private Recording")]
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in tagger.exportAsynchronously { continuation.resume() } }
        XCTAssertEqual(tagger.status, .completed, tagger.error?.localizedDescription ?? "")
        let source = try SourceFile(url: tagged)
        let compact = directory.appendingPathComponent("compact.m4a")
        let high = directory.appendingPathComponent("high.m4a")
        try await NativeMedia.convert(source, to: .m4a, output: compact,
                                      options: .init(quality: .compact, preserveMetadata: false, audioBitrate: 64))
        try await NativeMedia.convert(source, to: .m4a, output: high,
                                      options: .init(quality: .high, audioBitrate: 192))
        XCTAssertLessThan(try Data(contentsOf: compact).count, try Data(contentsOf: high).count)
        XCTAssertFalse(AVURLAsset(url: compact).commonMetadata.contains { $0.stringValue == "Private Recording" })
        XCTAssertTrue(AVURLAsset(url: high).commonMetadata.contains { $0.stringValue == "Private Recording" })
        XCTAssertGreaterThan(try AVAudioFile(forReading: compact).length, 0)
        XCTAssertGreaterThan(try AVAudioFile(forReading: high).length, 0)
    }

    func testNativeVideoHeightCapHandlesPortraitAndMetadata() async throws {
        let input = try await videoFixture()
        let source = try SourceFile(url: input)
        let original = try Data(contentsOf: input)
        for (name, metadata, target, height) in [("kept", true, FileFormat.mp4, Optional(160)),
                                                 ("removed", false, .mp4, Optional(160)),
                                                 ("removed-original-size", false, .mov, nil)] {
            let output = directory.appendingPathComponent("\(name).\(target.rawValue)")
            try await NativeMedia.convert(source, to: target, output: output,
                                          options: .init(quality: .high, preserveMetadata: metadata, videoMaxHeight: height))
            let asset = AVURLAsset(url: output)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            let track = try XCTUnwrap(tracks.first)
            let size = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let bounds = CGRect(origin: .zero, size: size).applying(transform).standardized
            if let height { XCTAssertLessThanOrEqual(bounds.height, CGFloat(height) + 0.1) }
            XCTAssertEqual(bounds.width / bounds.height, 0.75, accuracy: 0.03)
            XCTAssertEqual(asset.commonMetadata.contains { $0.stringValue == "Private Clip" }, metadata)
        }
        XCTAssertEqual(try Data(contentsOf: input), original)
    }

    func testMetadataRemovalPreservesDisabledVideoAndMutedAudio() async throws {
        for volume: Float in [0, 0.5] {
            let input = try await videoFixture(includePlaybackStateTracks: true, audioVolume: volume)
            let originalBytes = try Data(contentsOf: input)
            let asset = AVURLAsset(url: input)
            let originalVideo = try await asset.loadTracks(withMediaType: .video)
            let originalAudioTracks = try await asset.loadTracks(withMediaType: .audio)
            let originalAudio = try XCTUnwrap(originalAudioTracks.first(where: \.isEnabled))
            XCTAssertEqual(originalVideo.count, 2)
            XCTAssertEqual(originalVideo.filter(\.isEnabled).count, 1)
            XCTAssertEqual(originalAudioTracks.count, 2)
            XCTAssertEqual(originalAudioTracks.filter(\.isEnabled).count, 1)
            XCTAssertEqual(originalAudio.preferredVolume, volume)
            let sourcePeak = try audioPeak(asset, track: originalAudio)
            XCTAssertEqual(sourcePeak, 0.25, accuracy: 0.001, "The fixture contains a quarter-scale sine wave")

            let rebuilt = try NativeMedia.mediaWithoutMetadata(asset)
            XCTAssertEqual(rebuilt.tracks(withMediaType: .video).map(\.isEnabled), originalVideo.map(\.isEnabled))
            XCTAssertEqual(rebuilt.tracks(withMediaType: .audio).map(\.isEnabled), originalAudioTracks.map(\.isEnabled))
            XCTAssertEqual(rebuilt.tracks(withMediaType: .audio).first(where: \.isEnabled)?.preferredVolume, volume)

            for metadata in [true, false] {
                let output = directory.appendingPathComponent("playback-\(volume)-\(metadata).mov")
                try await NativeMedia.convert(SourceFile(url: input), to: .mov, output: output,
                                              options: .init(quality: .high, preserveMetadata: metadata))
                let exported = AVURLAsset(url: output)
                let video = try await exported.loadTracks(withMediaType: .video)
                XCTAssertEqual(video.filter(\.isEnabled).count, 1)
                let audio = try await exported.loadTracks(withMediaType: .audio).filter(\.isEnabled)
                if volume > 0 { XCTAssertFalse(audio.isEmpty, "Reduced-gain audio must remain in the output") }
                for track in audio {
                    let audiblePeak = try audioPeak(exported, track: track) * abs(track.preferredVolume)
                    if volume == 0 {
                        XCTAssertLessThanOrEqual(audiblePeak, 0.000_001)
                    } else {
                        // Allow codec peak overshoot while detecting ignored gain or gain applied twice.
                        XCTAssertEqual(audiblePeak, sourcePeak * volume, accuracy: 0.015)
                    }
                }
                XCTAssertEqual(exported.commonMetadata.contains { $0.stringValue == "Private Clip" }, metadata)
            }
            XCTAssertEqual(try Data(contentsOf: input), originalBytes)
        }
    }

    func testDeveloperGIFRateWidthAndVideoHeightWhenFFmpegIsAvailable() async throws {
        guard Tools().ffmpeg != nil else { throw XCTSkip("Developer-only FFmpeg is not installed") }
        let input = try await videoFixture()
        let source = try SourceFile(url: input)
        let engine = ConversionEngine()
        guard engine.targets(for: [source]).contains(.gif) else { throw XCTSkip("The developer FFmpeg has no GIF encoder") }
        let compact = try await engine.convert(source, to: .gif, in: directory,
                                               options: .init(gifFrameRate: 5, gifMaxWidth: 80))[0]
        let larger = try await engine.convert(source, to: .gif, in: directory,
                                              options: .init(gifFrameRate: 10, gifMaxWidth: 160))[0]
        let first = try XCTUnwrap(CGImageSourceCreateWithURL(compact as CFURL, nil))
        let second = try XCTUnwrap(CGImageSourceCreateWithURL(larger as CFURL, nil))
        XCTAssertGreaterThan(CGImageSourceGetCount(first), 0)
        XCTAssertLessThan(CGImageSourceGetCount(first), CGImageSourceGetCount(second))
        XCTAssertEqual(try XCTUnwrap(CGImageSourceCreateImageAtIndex(first, 0, nil)).width, 80)
        XCTAssertEqual(try XCTUnwrap(CGImageSourceCreateImageAtIndex(second, 0, nil)).width, 160)
        if engine.targets(for: [source]).contains(.mp4) {
            let video = try await engine.convert(source, to: .mp4, in: directory,
                                                 options: .init(quality: .high, preserveMetadata: false, videoMaxHeight: 72))[0]
            let tracks = try await AVURLAsset(url: video).loadTracks(withMediaType: .video)
            let track = try XCTUnwrap(tracks.first)
            let size = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            XCTAssertLessThanOrEqual(CGRect(origin: .zero, size: size).applying(transform).standardized.height, 72.1)
        }
    }

    func testDeveloperMetadataRemovalDropsGlobalStreamAndChapterTags() async throws {
        let tools = Tools()
        guard let ffmpeg = tools.ffmpeg, let ffprobe = tools.ffprobe else {
            throw XCTSkip("Developer metadata verification requires FFmpeg and FFprobe")
        }
        let video = try await videoFixture()
        let metadata = directory.appendingPathComponent("private.ffmetadata")
        try ";FFMETADATA1\ntitle=Global Secret\n[CHAPTER]\nTIMEBASE=1/1000\nSTART=0\nEND=500\ntitle=Chapter Secret\n"
            .write(to: metadata, atomically: false, encoding: .utf8)
        let input = directory.appendingPathComponent("tagged-stream.mov")
        _ = try ProcessRunner.checked(ffmpeg, ["-hide_banner", "-nostdin", "-loglevel", "error", "-n",
                                               "-i", video.path, "-f", "ffmetadata", "-i", metadata.path,
                                               "-map", "0:v:0", "-c:v", "copy", "-map_metadata", "1", "-map_chapters", "1",
                                               "-metadata:s:v:0", "handler_name=Stream Secret", input.path])
        func probe(_ url: URL) throws -> String {
            try ProcessRunner.checked(ffprobe, ["-v", "error", "-show_entries", "format_tags:stream_tags:chapter_tags",
                                                "-of", "json", url.path])
        }
        let original = try probe(input)
        for tag in ["Global Secret", "Stream Secret", "Chapter Secret"] { XCTAssertTrue(original.contains(tag), tag) }
        let source = try SourceFile(url: input)
        let engine = ConversionEngine()
        guard engine.targets(for: [source]).contains(.mkv) else { throw XCTSkip("The developer FFmpeg has no required video encoder") }
        let kept = try await engine.convert(source, to: .mkv, in: directory)[0]
        let removed = try await engine.convert(source, to: .mkv, in: directory, options: .init(preserveMetadata: false))[0]
        let keptTags = try probe(kept), removedTags = try probe(removed)
        for tag in ["Global Secret", "Stream Secret", "Chapter Secret"] {
            XCTAssertTrue(keptTags.contains(tag), tag)
            XCTAssertFalse(removedTags.contains(tag), tag)
        }
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(removedTags.utf8)) as? [String: Any])
        XCTAssertTrue((result["chapters"] as? [[String: Any]] ?? []).isEmpty)
        XCTAssertEqual(try probe(input), original)
    }

    func testZIPAndTarGzipCompressionLevelsAffectArchivesWithoutChangingContents() async throws {
        let input = directory.appendingPathComponent("payload.txt")
        let data = Data(String(repeating: "repeated content and a predictable paragraph\n", count: 30_000).utf8)
        try data.write(to: input)
        let fast = try FileOperations.compress([input], in: directory, compression: .fast)
        let maximum = try FileOperations.compress([input], in: directory, compression: .maximum)
        XCTAssertLessThan(try Data(contentsOf: maximum).count, try Data(contentsOf: fast).count)
        XCTAssertEqual(try ArchiveReader(fast).file(named: "payload.txt", maximumBytes: data.count), data)
        XCTAssertEqual(try ArchiveReader(maximum).file(named: "payload.txt", maximumBytes: data.count), data)
        let source = try SourceFile(url: maximum)
        let engine = ConversionEngine()
        let fastGzip = try await engine.convert(source, to: .gzip, in: directory, options: .init(compression: .fast))[0]
        let maximumGzip = try await engine.convert(source, to: .gzip, in: directory, options: .init(compression: .maximum))[0]
        XCTAssertLessThan(try Data(contentsOf: maximumGzip).count, try Data(contentsOf: fastGzip).count)
        for output in [fastGzip, maximumGzip] {
            let extraction = try FileOperations.scratch(in: directory)
            defer { try? FileManager.default.removeItem(at: extraction) }
            _ = try ArchiveReader(output).entries(extractingTo: extraction)
            XCTAssertEqual(try Data(contentsOf: extraction.appendingPathComponent("payload.txt")), data)
        }
        XCTAssertEqual(try Data(contentsOf: input), data)
    }

    func testEPUBVersionsHaveCorrectNavigationAndRejectUnsupportedLayoutBeforePublishing() async throws {
        let input = directory.appendingPathComponent("book.txt")
        try "A readable chapter.\nSecond paragraph.".write(to: input, atomically: false, encoding: .utf8)
        let source = try SourceFile(url: input)
        let engine = ConversionEngine()
        for version in [2, 3] {
            let output = try await engine.convert(source, to: .epub, in: directory, options: .init(epubReflowVersion: version))[0]
            let package = String(decoding: try XCTUnwrap(ArchiveReader(output).file(named: "OEBPS/content.opf")), as: UTF8.self)
            XCTAssertTrue(package.contains("version=\"\(version).0\""))
            XCTAssertTrue(package.contains("toc.ncx"))
            let navigation = try ArchiveReader(output).file(named: "OEBPS/nav.xhtml")
            if version == 3 {
                XCTAssertTrue(package.contains("properties=\"nav\""))
                XCTAssertTrue(package.contains("dcterms:modified"))
                XCTAssertTrue(String(decoding: try XCTUnwrap(navigation), as: UTF8.self).contains("epub:type=\"toc\""))
            } else { XCTAssertNil(navigation) }
            let chapter = String(decoding: try XCTUnwrap(ArchiveReader(output).file(named: "OEBPS/chapter.xhtml")), as: UTF8.self)
            XCTAssertTrue(chapter.contains("A readable chapter."))
        }
        let before = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        do {
            _ = try await engine.convert(source, to: .epub, in: directory, options: .init(epubLayout: .preservePages))
            XCTFail("Unavailable page preservation must fail")
        } catch is ConversionError { }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), before)
    }

    private func imageProperties(_ url: URL, at index: Int = 0) throws -> [String: Any] {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any])
    }

    private func assertPrivateMetadataAbsent(_ url: URL, at index: Int = 0) throws {
        let properties = try imageProperties(url, at: index)
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary as String])
        XCTAssertNil((properties[kCGImagePropertyExifDictionary as String] as? [String: Any])?[kCGImagePropertyExifDateTimeOriginal as String])
        XCTAssertNil((properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any])?[kCGImagePropertyTIFFArtist as String])
    }

    private func pattern(width: Int, height: Int) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: 0, space: XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        for y in 0..<height {
            for x in 0..<width {
                let value = (x * 73 + y * 151 + x * y * 17) & 255
                context.setFillColor(CGColor(red: Double(value) / 255, green: Double((value * 37) & 255) / 255,
                                             blue: Double((value * 71) & 255) / 255, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        return try XCTUnwrap(context.makeImage())
    }

    private func audioFixture() throws -> URL {
        let input = directory.appendingPathComponent("source-24bit.aiff")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100))
        buffer.frameLength = 44_100
        let samples = try XCTUnwrap(buffer.floatChannelData)[0]
        for index in 0..<44_100 { samples[index] = Float(sin(Double(index) * 440 * 2 * .pi / 44_100)) * 0.25 }
        let writer = try AVAudioFile(forWriting: input, settings: [AVFormatIDKey: kAudioFormatLinearPCM,
                                                                 AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1,
                                                                 AVLinearPCMBitDepthKey: 24, AVLinearPCMIsBigEndianKey: true])
        try writer.write(from: buffer)
        return input
    }

    private func waveFixture(_ name: String, bits: UInt16, format: UInt16, samples: Data) throws -> URL {
        var data = Data("RIFF".utf8)
        func append<T: FixedWidthInteger>(_ value: T) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        append(UInt32(36 + samples.count))
        data.append(Data("WAVEfmt ".utf8))
        append(UInt32(16))
        append(format)
        append(UInt16(1))
        append(UInt32(44_100))
        append(UInt32(44_100) * UInt32(bits / 8))
        append(bits / 8)
        append(bits)
        data.append(Data("data".utf8))
        append(UInt32(samples.count))
        data.append(samples)
        let output = directory.appendingPathComponent(name)
        try data.write(to: output)
        return output
    }

    private func integerSamples(_ url: URL) throws -> [Int32] {
        let input = try AVAudioFile(forReading: url, commonFormat: .pcmFormatInt32, interleaved: false)
        let capacity = AVAudioFrameCount(input.length)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: capacity))
        try input.read(into: buffer, frameCount: capacity)
        return Array(UnsafeBufferPointer(start: try XCTUnwrap(buffer.int32ChannelData)[0], count: Int(buffer.frameLength)))
    }

    private func titleMetadata(_ title: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = .commonIdentifierTitle
        item.value = title as NSString
        return item
    }

    private func audioPeak(_ asset: AVAsset, track: AVAssetTrack) throws -> Float {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM,
                                                                          AVLinearPCMBitDepthKey: 32,
                                                                          AVLinearPCMIsFloatKey: true,
                                                                          AVLinearPCMIsBigEndianKey: false,
                                                                          AVLinearPCMIsNonInterleaved: false])
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? ConversionError.failed("Audio fixture could not be read") }
        var peak: Float = 0
        while let sample = output.copyNextSampleBuffer() {
            let description = try XCTUnwrap(CMSampleBufferGetFormatDescription(sample))
            let format = try XCTUnwrap(CMAudioFormatDescriptionGetStreamBasicDescription(description)).pointee
            let incompatibleFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsNonInterleaved
            guard format.mFormatID == kAudioFormatLinearPCM, format.mBitsPerChannel == 32,
                  format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
                  format.mFormatFlags & incompatibleFlags == 0,
                  format.mChannelsPerFrame > 0,
                  format.mBytesPerFrame == format.mChannelsPerFrame * UInt32(MemoryLayout<Float>.size) else {
                throw ConversionError.failed("Audio fixture decoder did not deliver interleaved little-endian Float32 samples")
            }
            let data = try XCTUnwrap(CMSampleBufferGetDataBuffer(sample))
            let length = CMBlockBufferGetDataLength(data)
            guard length > 0, length % MemoryLayout<Float>.size == 0 else { throw ConversionError.failed("Audio fixture has an invalid PCM sample block") }
            var values = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
            let status = values.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(data, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }
            XCTAssertEqual(status, kCMBlockBufferNoErr)
            peak = max(peak, values.map(abs).max() ?? 0)
        }
        guard reader.status == .completed else { throw reader.error ?? ConversionError.failed("Audio fixture decoding did not complete") }
        return peak
    }

    private func videoFixture(includePlaybackStateTracks: Bool = false, audioVolume: Float = 0) async throws -> URL {
        let input = directory.appendingPathComponent("portrait-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: input, fileType: .mov)
        writer.metadata = [titleMetadata("Private Clip")]
        let adaptors = (includePlaybackStateTracks ? [true, false] : [true]).map { enabled in
            let track = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
                                                                            AVVideoWidthKey: 320, AVVideoHeightKey: 240])
            track.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 240, ty: 0)
            track.marksOutputTrackAsEnabled = enabled
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: track, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240])
            writer.add(track)
            return adaptor
        }
        var audioReader: AVAssetReader?, audioOutput: AVAssetReaderTrackOutput?
        var audioInputs: [AVAssetWriterInput] = []
        if includePlaybackStateTracks {
            let audio = AVURLAsset(url: try audioFixture())
            let audioTracks = try await audio.loadTracks(withMediaType: .audio)
            let track = try XCTUnwrap(audioTracks.first)
            let reader = try AVAssetReader(asset: audio)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            reader.add(output)
            for enabled in [true, false] {
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
                input.preferredVolume = enabled ? audioVolume : 1
                input.marksOutputTrackAsEnabled = enabled
                writer.add(input)
                audioInputs.append(input)
            }
            audioReader = reader
            audioOutput = output
        }
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        var pixel: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(nil, 320, 240, kCVPixelFormatType_32BGRA, nil, &pixel), kCVReturnSuccess)
        let buffer = try XCTUnwrap(pixel)
        CVPixelBufferLockBaseAddress(buffer, [])
        memset(try XCTUnwrap(CVPixelBufferGetBaseAddress(buffer)), 128, CVPixelBufferGetDataSize(buffer))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        let deadline = Date().addingTimeInterval(10)
        if let audioReader, !audioReader.startReading() {
            throw audioReader.error ?? ConversionError.failed("Muted audio fixture could not start reading")
        }
        var audioSample = audioOutput?.copyNextSampleBuffer()
        if audioSample == nil { audioInputs.forEach { $0.markAsFinished() } }
        var frames = [Int](repeating: 0, count: adaptors.count)
        while frames.contains(where: { $0 < 10 }) || audioSample != nil {
            for (index, adaptor) in adaptors.enumerated() where frames[index] < 10 && adaptor.assetWriterInput.isReadyForMoreMediaData {
                XCTAssertTrue(adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frames[index]), timescale: 10)))
                frames[index] += 1
                if frames[index] == 10 { adaptor.assetWriterInput.markAsFinished() }
            }
            if let sample = audioSample, audioInputs.allSatisfy(\.isReadyForMoreMediaData) {
                audioInputs.forEach { XCTAssertTrue($0.append(sample)) }
                audioSample = audioOutput?.copyNextSampleBuffer()
                if audioSample == nil { audioInputs.forEach { $0.markAsFinished() } }
            }
            guard writer.status != .failed, Date() < deadline else { throw writer.error ?? ConversionError.failed("Video options fixture stalled") }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        if let audioReader { XCTAssertEqual(audioReader.status, .completed) }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in writer.finishWriting { continuation.resume() } }
        XCTAssertEqual(writer.status, .completed, writer.error?.localizedDescription ?? "")
        return input
    }
}
