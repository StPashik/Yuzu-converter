import XCTest
import AppKit
import CoreText
import PDFKit
import ImageIO
@testable import YuzuCore

final class OCRTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("yuzu-ocr-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    private func scan(_ name: String, text: String) throws -> URL {
        let context = try XCTUnwrap(CGContext(data: nil, width: 1600, height: 500, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor.white); context.fill(CGRect(x: 0, y: 0, width: 1600, height: 500))
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text,
            attributes: [.font: NSFont.systemFont(ofSize: 54), .foregroundColor: NSColor.black]))
        context.textPosition = CGPoint(x: 60, y: 220); CTLineDraw(line, context)
        let url = directory.appendingPathComponent(name)
        try NativeDocuments.writeImage(XCTUnwrap(context.makeImage()), to: .png, output: url)
        return url
    }

    func testRasterOCRAndExactFileSavePreserveSourceAndExistingDestination() async throws {
        let image = try scan("Invoice.png", text: "Yuzu invoice 12345 Total 42.00")
        let original = try Data(contentsOf: image)
        let engine = ConversionEngine()
        XCTAssertTrue(engine.targets(for: [try SourceFile(url: image)]).contains(.txt))
        let output = try await engine.convert(SourceFile(url: image), to: .txt, in: directory)[0]
        XCTAssertTrue(try String(contentsOf: output).contains("12345"))
        let exact = directory.appendingPathComponent("Chosen.txt")
        _ = try await engine.saveDroppedImage(image, to: .txt, destination: exact)
        let saved = try Data(contentsOf: exact)
        do { _ = try await engine.saveDroppedImage(image, to: .txt, destination: exact); XCTFail("Expected exclusive publication") } catch {}
        XCTAssertEqual(try Data(contentsOf: exact), saved)
        XCTAssertEqual(try Data(contentsOf: image), original)
    }

    func testMixedPDFUsesExistingTextAndOCRInPageOrder() async throws {
        let image = try scan("Scan.png", text: "Scanned second page 24680")
        let pdf = directory.appendingPathComponent("Mixed.pdf")
        let document = PDFDocument()
        let typedURL = directory.appendingPathComponent("Typed.pdf")
        try NativeDocuments.writePDF(NSAttributedString(string: "Selectable first page 13579",
            attributes: [.font: NSFont.systemFont(ofSize: 24)]), output: typedURL)
        document.insert(try XCTUnwrap(PDFDocument(url: typedURL)?.page(at: 0)), at: 0)
        document.insert(try XCTUnwrap(PDFPage(image: XCTUnwrap(NSImage(contentsOf: image)))), at: 1)
        XCTAssertTrue(document.write(to: pdf))
        let output = try await ConversionEngine().convert(SourceFile(url: pdf), to: .txt, in: directory)[0]
        let text = try String(contentsOf: output)
        let first = try XCTUnwrap(text.range(of: "13579")), second = try XCTUnwrap(text.range(of: "24680"))
        XCTAssertLessThan(first.lowerBound, second.lowerBound)
    }

    func testMultipageTIFFAppliesOrientationAndRetainsPageOrder() async throws {
        let first = try scan("First.png", text: "First scan 13579"), second = try scan("Second.png", text: "Second scan 24680")
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(XCTUnwrap(CGImageSourceCreateWithURL(first as CFURL, nil)), 0, nil))
        let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.translateBy(x: CGFloat(image.width), y: CGFloat(image.height)); context.rotate(by: .pi)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let output = directory.appendingPathComponent("Pages.tiff")
        let writer = try XCTUnwrap(CGImageDestinationCreateWithURL(output as CFURL, "public.tiff" as CFString, 2, nil))
        CGImageDestinationAddImage(writer, try XCTUnwrap(context.makeImage()), [kCGImagePropertyOrientation: 3] as CFDictionary)
        CGImageDestinationAddImageFromSource(writer, try XCTUnwrap(CGImageSourceCreateWithURL(second as CFURL, nil)), 0, nil)
        XCTAssertTrue(CGImageDestinationFinalize(writer))
        let text = try await TextRecognition.image(output)
        XCTAssertLessThan(try XCTUnwrap(text.range(of: "13579")).lowerBound, try XCTUnwrap(text.range(of: "24680")).lowerBound)
    }

    func testFiveLanguagesBlankImageAndCancellation() async throws {
        for (name, text, word) in [("en", "Hello wonderful world", "Hello"), ("ru", "Привет большой мир", "Привет"),
            ("de", "Schöne Grüße aus Berlin", "Berlin"), ("fr", "Bonjour à toute la famille", "Bonjour"),
            ("es", "Buenos días desde Madrid", "Madrid")] {
            let result = try await TextRecognition.image(scan(name + ".png", text: text))
            XCTAssertTrue(result.localizedCaseInsensitiveContains(word), "\(name): \(result)")
        }
        let blank = try scan("Blank.png", text: "")
        do { _ = try await ConversionEngine().convert(SourceFile(url: blank), to: .txt, in: directory); XCTFail("Expected no-text error") }
        catch { XCTAssertTrue(error.localizedDescription.contains("No readable text")) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Blank.txt").path))
        let cancelled = Task.detached { try await TextRecognition.image(blank) }
        cancelled.cancel()
        do { _ = try await cancelled.value; XCTFail("Expected cancellation") } catch is CancellationError {}
    }
}
