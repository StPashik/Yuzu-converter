import XCTest
import AppKit
import ImageIO
import PDFKit
import AVFoundation
@testable import YuzuCore

final class ConversionTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("yuzu-core-tests-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    private func file(_ name: String, text: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try text.write(to: url, atomically: false, encoding: .utf8)
        return url
    }

    func testContentWinsOverMisleadingExtensionAndMixedTargetsIntersect() throws {
        let image = try makeImage("photo.mp3")
        let source = try SourceFile(url: image)
        XCTAssertEqual(source.format, .png)
        let second = directory.appendingPathComponent("second.jpg")
        try NativeDocuments.image(image, to: .jpg, output: second)
        let targets = ConversionEngine().targets(for: [source, try SourceFile(url: second)])
        XCTAssertTrue(targets.contains(.pdf))
        XCTAssertFalse(targets.contains(.png))
        XCTAssertFalse(targets.contains(.jpg))
        XCTAssertTrue(ConversionEngine().targets(for: [source, try SourceFile(url: file("text.txt", text: "hello"))]).contains(.pdf))
    }

    func testImageConversionDoesNotOverwriteExistingResult() async throws {
        let source = try SourceFile(url: makeImage("photo.png"))
        let existing = try file("photo.jpg", text: "keep me")
        let outputs = try await ConversionEngine().convert(source, to: .jpg, in: directory)
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "keep me")
        XCTAssertEqual(outputs.count, 1)
        XCTAssertEqual(outputs[0].lastPathComponent, "photo_yuzu.jpg")
        XCTAssertEqual(try SourceFile(url: outputs[0]).format, .jpg)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.url.path))
    }

    func testPDFExportsEveryPageAt300DPI() async throws {
        let input = directory.appendingPathComponent("two.pdf")
        var box = CGRect(x: 0, y: 0, width: 72, height: 144)
        let context = try XCTUnwrap(CGContext(input as CFURL, mediaBox: &box, nil))
        for _ in 0..<2 { context.beginPDFPage(nil); context.setFillColor(CGColor.black); context.fill(box); context.endPDFPage() }
        context.closePDF()
        let outputs = try await ConversionEngine().convert(SourceFile(url: input), to: .png, in: directory)
        XCTAssertEqual(outputs.count, 2)
        XCTAssertEqual(Set(outputs.map { $0.deletingLastPathComponent() }).count, 1)
        for url in outputs {
            let image = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
            let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [String: Any])
            XCTAssertEqual((properties[kCGImagePropertyPixelWidth as String] as? NSNumber)?.intValue, 300)
            XCTAssertEqual((properties[kCGImagePropertyPixelHeight as String] as? NSNumber)?.intValue, 600)
            XCTAssertEqual((properties[kCGImagePropertyDPIWidth as String] as? NSNumber)?.doubleValue ?? 0, 300, accuracy: 0.1)
            let pixels = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: url)))
            let corner = try XCTUnwrap(pixels.colorAt(x: 10, y: 10)?.usingColorSpace(.deviceRGB))
            XCTAssertLessThan(corner.redComponent + corner.greenComponent + corner.blueComponent, 0.05)
        }
    }

    func testPDFVisibleCropAndRotationFillTheImageAt300DPI() async throws {
        let input = directory.appendingPathComponent("cropped.pdf")
        var media = CGRect(x: 0, y: 0, width: 360, height: 720)
        let crop = CGRect(x: 108, y: 216, width: 72, height: 144)
        let writer = try XCTUnwrap(CGContext(input as CFURL, mediaBox: &media, nil))
        for _ in 0..<4 {
            writer.beginPDFPage(nil)
            writer.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); writer.fill(crop)
            writer.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            writer.fill(CGRect(x: crop.minX, y: crop.minY, width: 36, height: 72))
            writer.endPDFPage()
        }
        writer.closePDF()
        let pdf = try XCTUnwrap(PDFDocument(url: input))
        for index in 0..<4 {
            let page = try XCTUnwrap(pdf.page(at: index))
            page.setBounds(crop, for: .cropBox)
            page.rotation = index * 90
        }
        XCTAssertTrue(pdf.write(to: input))
        for target: FileFormat in [.png, .jpg] {
            let outputs = try await ConversionEngine().convert(SourceFile(url: input), to: target, in: directory)
            XCTAssertEqual(outputs.count, 4)
            for (index, output) in outputs.enumerated() {
                let image = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: output)))
                XCTAssertEqual(image.pixelsWide, index % 2 == 0 ? 300 : 600)
                XCTAssertEqual(image.pixelsHigh, index % 2 == 0 ? 600 : 300)
                var red = 0, blue = 0
                // Inspect visible content, not only DPI metadata: an incorrectly scaled page leaves white corners.
                for x in [image.pixelsWide / 4, image.pixelsWide * 3 / 4] {
                    for y in [image.pixelsHigh / 4, image.pixelsHigh * 3 / 4] {
                        let color = try XCTUnwrap(image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                        if color.redComponent > 0.9 && color.blueComponent < 0.1 { red += 1 }
                        if color.blueComponent > 0.9 && color.redComponent < 0.1 { blue += 1 }
                    }
                }
                XCTAssertEqual(red, 3, "Page \(index + 1) must fill its visible crop")
                XCTAssertEqual(blue, 1, "Page content must survive rotation")
                let blueX = index < 2 ? image.pixelsWide / 4 : image.pixelsWide * 3 / 4
                let blueY = index == 0 || index == 3 ? image.pixelsHigh * 3 / 4 : image.pixelsHigh / 4
                let rotatedCorner = try XCTUnwrap(image.colorAt(x: blueX, y: blueY)?.usingColorSpace(.deviceRGB))
                XCTAssertGreaterThan(rotatedCorner.blueComponent, 0.9)
                XCTAssertLessThan(rotatedCorner.redComponent, 0.1)
            }
        }
    }

    func testPublicationKeepsShortNamesAndSkipsEveryExistingCollision() throws {
        for name in ["report.pdf", "report_yuzu.pdf", "report_yuzu_2.pdf", "folder", "folder_yuzu"] {
            try Data("Keep existing".utf8).write(to: directory.appendingPathComponent(name))
        }
        let staged = directory.appendingPathComponent("staged")
        try Data("New result".utf8).write(to: staged)
        let published = try FileOperations.publish(staged, named: "report.pdf", in: directory)
        XCTAssertEqual(published.lastPathComponent, "report_yuzu_3.pdf")
        XCTAssertEqual(try String(contentsOf: published), "New result")
        for name in ["report.pdf", "report_yuzu.pdf", "report_yuzu_2.pdf"] {
            XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent(name)), "Keep existing")
        }
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: false)
        XCTAssertEqual(try FileOperations.publish(staged, named: "folder", in: directory).lastPathComponent, "folder_yuzu_2")
    }

    func testSubtitlesRetainTimesAndTextAndRejectInvalidInput() async throws {
        let source = try SourceFile(url: file("captions.srt", text: "1\n00:00:01,250 --> 00:00:02,500\nHello <b>world 🌍</b>\n\n2\n00:00:03,000 --> 00:00:04,000\nSecond line\n"))
        let outputs = try await ConversionEngine().convert(source, to: .vtt, in: directory)
        let vtt = try String(contentsOf: outputs[0], encoding: .utf8)
        XCTAssertTrue(vtt.hasPrefix("WEBVTT"))
        XCTAssertEqual(try Subtitles.parse(vtt, format: .vtt), try Subtitles.parse(String(contentsOf: source.url, encoding: .utf8), format: .srt))
        XCTAssertThrowsError(try Subtitles.parse("1\n00:99:00,000 --> 00:00:01,000\nBad", format: .srt))
    }

    func testQuotedDelimitedTableRoundTripThroughXLSXAndODS() async throws {
        let rows = [["Name", "Note"], ["Zoë", "comma, quote \" and\nnewline"], ["", "tail"]]
        let csv = try file("table.csv", text: DelimitedText.write(rows, separator: ","))
        XCTAssertEqual(try DelimitedText.parse(String(contentsOf: csv, encoding: .utf8), separator: ","), rows)
        let engine = ConversionEngine()
        for format: FileFormat in [.xlsx, .ods] {
            let output = try await engine.convert(SourceFile(url: csv), to: format, in: directory)[0]
            XCTAssertEqual(try SourceFile(url: output).format, format)
            let scratch = try FileOperations.scratch(in: directory)
            defer { try? FileManager.default.removeItem(at: scratch) }
            XCTAssertEqual(try Spreadsheet.read(SourceFile(url: output), scratch: scratch).first?.rows, rows)
        }
        XCTAssertThrowsError(try DelimitedText.parse("a,\"unterminated", separator: ","))
        let mixedXML = try file("mixed.xml", text: "<root><t>first<r>middle</r><![CDATA[last]]></t></root>")
        XCTAssertEqual(try XMLTree.read(mixedXML).descendants("t").first?.textContent, "firstmiddlelast")
        let entities = try file("entities.xml", text: "<!DOCTYPE root [<!ENTITY secret SYSTEM 'file:///etc/passwd'>]><root>&secret;</root>")
        XCTAssertThrowsError(try XMLTree.read(entities))
    }

    func testArchiveRoundTripAndRejectsSymlink() async throws {
        let contents = directory.appendingPathComponent("archive-input", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: false)
        try "archived data".write(to: contents.appendingPathComponent("hello.txt"), atomically: false, encoding: .utf8)
        let zip = directory.appendingPathComponent("input.zip")
        _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/zip"), ["-qr", zip.path, "."], directory: contents)
        let output = try await ConversionEngine().convert(SourceFile(url: zip), to: .gzip, in: directory)[0]
        let unpacked = directory.appendingPathComponent("unpacked", isDirectory: true)
        try FileManager.default.createDirectory(at: unpacked, withIntermediateDirectories: false)
        _ = try ArchiveReader(output).entries(extractingTo: unpacked)
        XCTAssertEqual(try String(contentsOf: unpacked.appendingPathComponent("hello.txt"), encoding: .utf8), "archived data")
        try FileManager.default.createSymbolicLink(atPath: contents.appendingPathComponent("link").path, withDestinationPath: "/etc/passwd")
        let unsafe = directory.appendingPathComponent("unsafe.tar")
        _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/tar"), ["-cf", unsafe.path, "-C", contents.path, "."])
        XCTAssertThrowsError(try ArchiveReader(unsafe).entries())
        var traversal = try Data(contentsOf: zip)
        let oldName = Data("hello.txt".utf8), badName = Data("../escape".utf8)
        while let range = traversal.range(of: oldName) { traversal.replaceSubrange(range, with: badName) }
        let unsafeZIP = directory.appendingPathComponent("traversal.zip")
        try traversal.write(to: unsafeZIP)
        XCTAssertThrowsError(try ArchiveReader(unsafeZIP).entries())
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("escape").path))
        let rawGZIP = directory.appendingPathComponent("single.gz")
        // A valid gzip stream containing "hello", rather than a tar payload.
        try Data([31, 139, 8, 0, 0, 0, 0, 0, 2, 255, 203, 72, 205, 201, 201, 7, 0, 134, 166, 16, 54, 5, 0, 0, 0]).write(to: rawGZIP)
        XCTAssertThrowsError(try SourceFile(url: rawGZIP))
    }

    func testCopyAndMovePreserveExistingFilesAndRejectRecursion() throws {
        let input = try file("source.txt", text: "original")
        let destination = directory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        try "keep".write(to: destination.appendingPathComponent("source.txt"), atomically: false, encoding: .utf8)
        let copied = try FileOperations.copy([input], to: destination, move: false)
        XCTAssertEqual(copied[0].lastPathComponent, "source_yuzu.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: input.path))
        let moved = try FileOperations.copy([input], to: destination, move: true)
        XCTAssertEqual(try String(contentsOf: moved[0], encoding: .utf8), "original")
        XCTAssertFalse(FileManager.default.fileExists(atPath: input.path))
        XCTAssertThrowsError(try FileOperations.copy([directory], to: destination, move: false))
    }

    func testMoveFolderAndChildOnceEvenWhenChildSelectedFirst() throws {
        let folder = directory.appendingPathComponent("folder", isDirectory: true)
        let target = directory.appendingPathComponent("target", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        let child = folder.appendingPathComponent("child.txt")
        try "keep child".write(to: child, atomically: false, encoding: .utf8)
        let outputs = try FileOperations.copy([child, folder, child, folder], to: target, move: true)
        XCTAssertEqual(outputs.count, 1)
        XCTAssertEqual(try String(contentsOf: outputs[0].appendingPathComponent("child.txt"), encoding: .utf8), "keep child")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.appendingPathComponent("child.txt").path))
    }

    func testUTF16ContentDetectionAndConversion() async throws {
        let input = directory.appendingPathComponent("utf16.txt")
        try XCTUnwrap("English café text 🌍\nSecond paragraph".data(using: .utf16)).write(to: input)
        let source = try SourceFile(url: input)
        XCTAssertEqual(source.format, .txt)
        let output = try await ConversionEngine().convert(source, to: .docx, in: directory)[0]
        XCTAssertEqual(try SourceFile(url: output).format, .docx)
        let scratch = try FileOperations.scratch(in: directory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let restoredText = try await NativeDocuments.readText(SourceFile(url: output), scratch: scratch)
        XCTAssertTrue(restoredText.string.contains("English café text 🌍"))
    }

    func testCancellationLeavesNoPublishedResult() async throws {
        let source = try SourceFile(url: makeImage("cancel.png"))
        let gate = TestLatch()
        let outputDirectory = directory!
        let task = Task.detached { () throws -> [URL] in
            await gate.wait()
            return try await ConversionEngine().convert(source, to: .jpg, in: outputDirectory)
        }
        task.cancel()
        await gate.release()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch is CancellationError { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("cancel.jpg").path))
    }

    func testRunningProcessRespondsToCancellation() async throws {
        let started = Date()
        let task = Task.detached { try ProcessRunner.run(URL(fileURLWithPath: "/bin/sleep"), ["10"]) }
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch is CancellationError { }
        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
    }

    func testEditableDOCXAndEPUBContainText() async throws {
        let text = "A heading\nEditable café text & symbols 🌍 < >\nSecond paragraph"
        let source = try SourceFile(url: file("document.txt", text: text))
        let engine = ConversionEngine()
        for format: FileFormat in [.docx, .epub] {
            let output = try await engine.convert(source, to: format, in: directory)[0]
            XCTAssertEqual(try SourceFile(url: output).format, format)
            let scratch = try FileOperations.scratch(in: directory)
            defer { try? FileManager.default.removeItem(at: scratch) }
            if format == .docx {
                let contents = try XCTUnwrap(ArchiveReader(output).file(named: "word/document.xml", maximumBytes: 1_000_000))
                XCTAssertTrue(String(decoding: contents, as: UTF8.self).contains("Editable"))
            } else {
                let contents = try XCTUnwrap(ArchiveReader(output).file(named: "OEBPS/chapter.xhtml"))
                XCTAssertTrue(String(decoding: contents, as: UTF8.self).contains("&amp;"))
                XCTAssertTrue(try EPUB.read(output, scratch: scratch).string.contains("Editable café text"))
            }
        }
    }

    func testFFmpegWAVToFLACWhenAvailable() async throws {
        guard let ffmpeg = Tools().ffmpeg else { throw XCTSkip("FFmpeg is not installed") }
        let input = directory.appendingPathComponent("tone.wav")
        _ = try ProcessRunner.checked(ffmpeg, ["-v", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=0.1", input.path])
        let source = try SourceFile(url: input)
        guard ConversionEngine().targets(for: [source]).contains(.flac) else { throw XCTSkip("FLAC encoder is not available") }
        let output = try await ConversionEngine().convert(source, to: .flac, in: directory)[0]
        XCTAssertEqual(try SourceFile(url: output).format, .flac)
        _ = try ProcessRunner.checked(ffmpeg, ["-v", "error", "-i", output.path, "-f", "null", "-"])
    }

    func testNativeAudioBaselineWithoutExternalTools() async throws {
        let input = directory.appendingPathComponent("native.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410))
        buffer.frameLength = 4_410
        let samples = try XCTUnwrap(buffer.floatChannelData)[0]
        for index in 0..<4_410 { samples[index] = Float(sin(Double(index) * 440 * 2 * .pi / 44_100)) * 0.25 }
        do {
            let writer = try AVAudioFile(forWriting: input, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16])
            try writer.write(from: buffer)
        }
        let source = try SourceFile(url: input)
        for target: FileFormat in [.aiff, .m4a] {
            XCTAssertTrue(NativeMedia.supports(source, to: target))
            let output = directory.appendingPathComponent("native-baseline." + target.rawValue)
            do { try await NativeMedia.convert(source, to: target, output: output) }
            catch { XCTFail("WAV → \(target.label): \(error)"); throw error }
            XCTAssertEqual(try SourceFile(url: output).format, target)
            let decoded = try AVAudioFile(forReading: output)
            XCTAssertGreaterThan(decoded.length, 0)
            if target == .aiff {
                let wav = directory.appendingPathComponent("back.wav")
                do { try await NativeMedia.convert(SourceFile(url: output), to: .wav, output: wav) }
                catch { XCTFail("AIFF → WAV: \(error)"); throw error }
                XCTAssertEqual(try SourceFile(url: wav).format, .wav)
                XCTAssertEqual(try AVAudioFile(forReading: wav).length, 4_410)
            }
        }
        XCTAssertFalse(NativeMedia.supports(source, to: .mp4))
    }

    func testNativeVideoBaselineWithoutExternalTools() async throws {
        let inputURL = directory.appendingPathComponent("native-video.mov")
        let writer = try AVAssetWriter(outputURL: inputURL, fileType: .mov)
        let track = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 32, AVVideoHeightKey: 32])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: track, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: 32, kCVPixelBufferHeightKey as String: 32])
        writer.add(track)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        var pixel: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(nil, 32, 32, kCVPixelFormatType_32BGRA, nil, &pixel), kCVReturnSuccess)
        let buffer = try XCTUnwrap(pixel)
        CVPixelBufferLockBaseAddress(buffer, [])
        memset(try XCTUnwrap(CVPixelBufferGetBaseAddress(buffer)), 128, CVPixelBufferGetDataSize(buffer))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        let deadline = Date().addingTimeInterval(10)
        for frame in 0..<4 {
            while !track.isReadyForMoreMediaData {
                guard writer.status != .failed, Date() < deadline else { throw writer.error ?? ConversionError.failed("Native video fixture stalled") }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            XCTAssertTrue(adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 10)))
        }
        track.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in writer.finishWriting { continuation.resume() } }
        XCTAssertEqual(writer.status, .completed, writer.error?.localizedDescription ?? "")
        var source = try SourceFile(url: inputURL)
        for target: FileFormat in [.mp4, .mov] {
            XCTAssertTrue(NativeMedia.supports(source, to: target))
            let output = directory.appendingPathComponent("native-video-baseline." + target.rawValue)
            try await NativeMedia.convert(source, to: target, output: output)
            XCTAssertEqual(try SourceFile(url: output).format, target)
            let videoTracks = try await AVURLAsset(url: output).loadTracks(withMediaType: .video)
            XCTAssertFalse(videoTracks.isEmpty)
            source = try SourceFile(url: output)
        }
    }

    func testCompressFilesAndFolderWithoutOverwritingOrFollowingLinks() throws {
        let first = try file("first.txt", text: "first content")
        let second = try file("second.txt", text: "second content")
        let folder = directory.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let child = folder.appendingPathComponent("child.txt")
        try "child content".write(to: child, atomically: false, encoding: .utf8)
        let existing = try file("Archive.zip", text: "keep existing")
        let output = try FileOperations.compress([first, second, folder, child, first], in: directory)
        XCTAssertEqual(output.lastPathComponent, "Archive_yuzu.zip")
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "keep existing")
        let extracted = directory.appendingPathComponent("zip-result", isDirectory: true)
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: false)
        _ = try ArchiveReader(output).entries(extractingTo: extracted)
        XCTAssertEqual(try String(contentsOf: extracted.appendingPathComponent("first.txt"), encoding: .utf8), "first content")
        XCTAssertEqual(try String(contentsOf: extracted.appendingPathComponent("second.txt"), encoding: .utf8), "second content")
        XCTAssertEqual(try String(contentsOf: extracted.appendingPathComponent("folder/child.txt"), encoding: .utf8), "child content")
        XCTAssertEqual(try String(contentsOf: child, encoding: .utf8), "child content")
        try FileManager.default.createSymbolicLink(atPath: folder.appendingPathComponent("link").path, withDestinationPath: first.path)
        XCTAssertThrowsError(try FileOperations.compress([folder], in: directory))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("folder.zip").path))
        let another = directory.appendingPathComponent("another", isDirectory: true)
        try FileManager.default.createDirectory(at: another, withIntermediateDirectories: false)
        let duplicate = another.appendingPathComponent("first.txt")
        try "another source".write(to: duplicate, atomically: false, encoding: .utf8)
        XCTAssertThrowsError(try FileOperations.compress([first, duplicate], in: directory))
        XCTAssertEqual(try String(contentsOf: first, encoding: .utf8), "first content")
    }

    func testCompressCancellationCreatesNoArchive() async throws {
        let input = try file("cancel-compression.txt", text: "keep input")
        let target = directory!
        let gate = TestLatch()
        let task = Task.detached { await gate.wait(); return try FileOperations.compress([input], in: target) }
        task.cancel()
        await gate.release()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch is CancellationError { }
        XCTAssertEqual(try String(contentsOf: input, encoding: .utf8), "keep input")
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.appendingPathComponent("cancel-compression.txt.zip").path))
    }

    func testArchiveRejectsDuplicateCaseAndDirectoryAliasesWithoutTruncation() throws {
        let cases = [[("Report.txt", "first"), ("report.txt", "second")], [("Report.txt", "first"), ("Report.txt", "second")], [("folder", "first"), ("folder/file", "second")]]
        for (index, entries) in cases.enumerated() {
            let archive = directory.appendingPathComponent("collision-\(index).tar")
            let data = makeTar(entries)
            try data.write(to: archive)
            let extracted = directory.appendingPathComponent("collision-\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: false)
            XCTAssertThrowsError(try ArchiveReader(archive).entries(extractingTo: extracted))
            XCTAssertEqual(try String(contentsOf: extracted.appendingPathComponent(entries[0].0), encoding: .utf8), "first")
            XCTAssertEqual(try Data(contentsOf: archive), data)
        }
    }

    func testODSRepeatedCountsCannotOverflow() throws {
        let first = "<t:table-row><t:table-cell><text:p>first</text:p></t:table-cell></t:table-row>"
        let cases = ["<t:table-row><t:table-cell/><t:table-cell t:number-columns-repeated=\"\(Int.max)\"/></t:table-row>", first + "<t:table-row t:number-rows-repeated=\"\(Int.max)\"><t:table-cell/></t:table-row>"]
        for (index, rows) in cases.enumerated() {
            let ods = try makePackage("overflow-\(index).ods", files: ["mimetype": "application/vnd.oasis.opendocument.spreadsheet", "META-INF/manifest.xml": "<manifest/>", "content.xml": odsDocument(rows)])
            let scratch = try FileOperations.scratch(in: directory)
            defer { try? FileManager.default.removeItem(at: scratch) }
            XCTAssertThrowsError(try Spreadsheet.read(SourceFile(url: ods), scratch: scratch))
        }
    }

    func testPrefixedXLSXAndWrappedODSKeepRowsAndNamespaces() async throws {
        let rows = "<t:table-header-rows><t:table-row><t:table-cell><text:p>Header</text:p></t:table-cell></t:table-row></t:table-header-rows><t:table-row-group><t:table-rows><t:table-row><t:table-cell><text:p>Body</text:p></t:table-cell></t:table-row></t:table-rows></t:table-row-group>"
        let ods = try makePackage("wrapped.ods", files: ["mimetype": "application/vnd.oasis.opendocument.spreadsheet", "META-INF/manifest.xml": "<manifest/>", "content.xml": odsDocument(rows)])
        let odsScratch = try FileOperations.scratch(in: directory)
        defer { try? FileManager.default.removeItem(at: odsScratch) }
        XCTAssertEqual(try Spreadsheet.read(SourceFile(url: ods), scratch: odsScratch).first?.rows, [["Header"], ["Body"]])
        let ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
        let xlsx = try makePackage("prefixed.xlsx", files: [
            "[Content_Types].xml": "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"/>",
            "xl/workbook.xml": "<x:workbook xmlns:x=\"\(ns)\" xmlns:link=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><x:sheets><x:sheet name=\"Data\" sheetId=\"1\" link:id=\"r1\"/></x:sheets></x:workbook>",
            "xl/_rels/workbook.xml.rels": "<rel:Relationships xmlns:rel=\"http://schemas.openxmlformats.org/package/2006/relationships\"><rel:Relationship Id=\"r1\" Target=\"worksheets/sheet1.xml\"/></rel:Relationships>",
            "xl/worksheets/sheet1.xml": "<x:worksheet xmlns:x=\"\(ns)\"><x:sheetData><x:row r=\"1\"><x:c r=\"A1\" t=\"inlineStr\"><x:is><x:t>Prefixed value</x:t></x:is></x:c></x:row></x:sheetData></x:worksheet>"
        ])
        let xlsxScratch = try FileOperations.scratch(in: directory)
        defer { try? FileManager.default.removeItem(at: xlsxScratch) }
        XCTAssertEqual(try Spreadsheet.read(SourceFile(url: xlsx), scratch: xlsxScratch).first?.rows, [["Prefixed value"]])
        let output = try await ConversionEngine().convert(SourceFile(url: xlsx), to: .pdf, in: directory)[0]
        XCTAssertTrue(PDFDocument(url: output)?.string?.contains("Prefixed value") == true)
        let empty = try makePackage("empty-book.xlsx", files: ["xl/workbook.xml": "<x:workbook xmlns:x=\"\(ns)\"><x:sheets/></x:workbook>", "xl/_rels/workbook.xml.rels": "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"/>", "xl/worksheets/sheet1.xml": "<x:worksheet xmlns:x=\"\(ns)\"/>"])
        do { _ = try await ConversionEngine().convert(SourceFile(url: empty), to: .pdf, in: directory); XCTFail("Empty workbook must fail") } catch is ConversionError { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("empty-book.pdf").path))
    }

    func testRIFFByteOffsetsAndLargeQuotedCSVContentDetection() async throws {
        let windowsRows = [["Name", "Note"], ["record", "line one\r\nline two"]]
        XCTAssertEqual(try DelimitedText.parse(DelimitedText.write(windowsRows, separator: ","), separator: ","), windowsRows)
        let wav = directory.appendingPathComponent("chunk-size.bin")
        var wavData = Data([82, 73, 70, 70, 0xC2, 0xA0, 0, 0, 87, 65, 86, 69, 102, 109, 116, 32, 16, 0, 0, 0, 1, 0, 1, 0, 0x44, 0xAC, 0, 0, 0x88, 0x58, 1, 0, 2, 0, 16, 0, 100, 97, 116, 97, 0x9E, 0xA0, 0, 0])
        wavData.append(Data(repeating: 0, count: 41_118))
        try wavData.write(to: wav)
        XCTAssertEqual(try SourceFile(url: wav).format, .wav)
        XCTAssertEqual(try AVAudioFile(forReading: wav).length, 20_559)
        let values = [["Name", "Note"], ["record", String(repeating: "é", count: 40_000) + "\nsecond line"]]
        let csv = try file("large.data", text: DelimitedText.write(values, separator: ","))
        XCTAssertGreaterThan(try Data(contentsOf: csv).count, 65_536)
        let source = try SourceFile(url: csv)
        XCTAssertEqual(source.format, .csv)
        let output = try await ConversionEngine().convert(source, to: .tsv, in: directory)[0]
        XCTAssertEqual(try DelimitedText.parse(TextFile.read(output), separator: "\t"), values)
    }

    func testJPEGOrientationIsAppliedToPDFWithoutDownsampling() async throws {
        let input = directory.appendingPathComponent("portrait.jpg")
        let bitmap = try XCTUnwrap(CGContext(data: nil, width: 60, height: 40, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        bitmap.setFillColor(CGColor.black); bitmap.fill(CGRect(x: 0, y: 0, width: 60, height: 40))
        let writer = try XCTUnwrap(CGImageDestinationCreateWithURL(input as CFURL, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(writer, try XCTUnwrap(bitmap.makeImage()), [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(writer))
        let output = try await ConversionEngine().convert(SourceFile(url: input), to: .pdf, in: directory)[0]
        let page = try XCTUnwrap(CGPDFDocument(output as CFURL)?.page(at: 1))
        XCTAssertEqual(page.getBoxRect(.mediaBox).width, 40)
        XCTAssertEqual(page.getBoxRect(.mediaBox).height, 60)
    }

    private func odsDocument(_ rows: String) -> String {
        "<office:document-content xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\" xmlns:t=\"urn:oasis:names:tc:opendocument:xmlns:table:1.0\" xmlns:text=\"urn:oasis:names:tc:opendocument:xmlns:text:1.0\"><office:body><office:spreadsheet><t:table t:name=\"Data\">\(rows)</t:table></office:spreadsheet></office:body></office:document-content>"
    }

    private func makePackage(_ name: String, files: [String: String]) throws -> URL {
        let root = try FileOperations.scratch(in: directory)
        defer { try? FileManager.default.removeItem(at: root) }
        for (path, text) in files {
            let file = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: file, atomically: false, encoding: .utf8)
        }
        let output = directory.appendingPathComponent(name)
        if files["mimetype"] != nil {
            _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/zip"), ["-q", "-0", output.path, "mimetype"], directory: root)
            _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/zip"), ["-q", "-r", output.path, ".", "-x", "mimetype"], directory: root)
        } else { _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/zip"), ["-q", "-r", output.path, "."], directory: root) }
        return output
    }

    private func makeTar(_ entries: [(String, String)]) -> Data {
        var output = Data()
        for (name, text) in entries {
            let bytes = Data(text.utf8)
            var header = [UInt8](repeating: 0, count: 512)
            func put(_ value: String, at offset: Int) { for (index, byte) in value.utf8.enumerated() { header[offset + index] = byte } }
            put(name, at: 0); put("0000600\0", at: 100); put("0000000\0", at: 108); put("0000000\0", at: 116)
            put(String(format: "%011o", bytes.count) + "\0", at: 124); put("00000000000\0", at: 136)
            put("        ", at: 148); put("0", at: 156); put("ustar\0", at: 257); put("00", at: 263)
            put(String(format: "%06o", header.reduce(0) { $0 + Int($1) }) + "\0 ", at: 148)
            output.append(contentsOf: header); output.append(bytes)
            output.append(Data(repeating: 0, count: (512 - bytes.count % 512) % 512))
        }
        output.append(Data(repeating: 0, count: 1024))
        return output
    }

    private func makeImage(_ name: String) throws -> URL {
        let context = try XCTUnwrap(CGContext(data: nil, width: 16, height: 24, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.3, green: 0.6, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 24))
        let output = directory.appendingPathComponent(name)
        try NativeDocuments.writeImage(XCTUnwrap(context.makeImage()), to: .png, output: output)
        return output
    }
}

private actor TestLatch {
    private var opened = false
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        if opened { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func release() {
        opened = true
        continuation?.resume()
        continuation = nil
    }
}
