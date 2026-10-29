import XCTest
import AppKit
import PDFKit
import ImageIO
@testable import YuzuCore

final class BatchAndTableTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    private func image(_ name: String, color: CGColor) throws -> URL {
        let context = try XCTUnwrap(CGContext(data: nil, width: 16, height: 24, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(color); context.fill(CGRect(x: 0, y: 0, width: 16, height: 24))
        let url = directory.appendingPathComponent(name)
        try NativeDocuments.writeImage(XCTUnwrap(context.makeImage()), to: name.hasSuffix("jpg") ? .jpg : .png, output: url)
        return url
    }

    func testImagesBecomeOnePDFInDropOrderAndNeverReplaceExistingFiles() async throws {
        let red = try image("First.png", color: CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        let blue = try image("Second.jpg", color: CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        let existing = directory.appendingPathComponent("First.pdf")
        try Data("Keep existing".utf8).write(to: existing)
        let sources = try [red, blue].map { try SourceFile(url: $0) }
        let engine = ConversionEngine()
        XCTAssertTrue(engine.targets(for: sources).contains(.pdf))
        XCTAssertFalse(engine.targets(for: sources).contains(.jpg))
        let pdf = try engine.combineImages(sources, in: directory)
        XCTAssertEqual(pdf.lastPathComponent, "First_yuzu.pdf")
        XCTAssertEqual(PDFDocument(url: pdf)?.pageCount, 2)
        let pages = try await engine.convert(SourceFile(url: pdf), to: .png, in: directory)
        for (index, url) in pages.enumerated() {
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: url)))
            let color = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.deviceRGB))
            XCTAssertGreaterThan(index == 0 ? color.redComponent : color.blueComponent, 0.9)
        }
        XCTAssertEqual(try String(contentsOf: existing), "Keep existing")
        XCTAssertTrue(FileManager.default.fileExists(atPath: red.path))
        try Data("Damaged".utf8).write(to: blue)
        XCTAssertThrowsError(try engine.combineImages(sources, in: directory))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("First_yuzu_2.pdf").path))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasPrefix(".yuzu-") })
    }

    func testVirtualImageSameFormatSaveIsExclusiveAndCancellable() async throws {
        let input = try image("image.png", color: CGColor.black)
        let destination = directory.appendingPathComponent("Chosen.png")
        let engine = ConversionEngine()
        XCTAssertTrue(ConversionEngine.imageDropTargets.contains(.png))
        XCTAssertEqual(try engine.saveDroppedImage(input, to: .png, destination: destination), destination)
        let original = try Data(contentsOf: destination)
        XCTAssertThrowsError(try engine.saveDroppedImage(input, to: .png, destination: destination))
        XCTAssertEqual(try Data(contentsOf: destination), original)
        let missing = directory.appendingPathComponent("Cancelled.png")
        let task = Task.detached {
            try await Task.sleep(for: .milliseconds(20))
            return try engine.saveDroppedImage(input, to: .png, destination: missing)
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch is CancellationError {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
    }

    func testTablePDFHasGridWidthsWrappedValuesAndEverySheetAndPage() throws {
        var first = TableSheet(name: "First worksheet", rows: [["Name", "Value"], ["Wrapped text that must remain readable", "42"]])
        first.columnWidths = [0: 145, 1: 85]
        first.rowHeights = [0: 28]
        let second = TableSheet(name: "Second worksheet", rows: (1...100).map { ["Row \($0)", "Value \($0)"] })
        let output = directory.appendingPathComponent("Table.pdf")
        try Spreadsheet.writePDF([first, second], output: output)
        let document = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertGreaterThanOrEqual(document.pageCount, 4)
        let text = document.string ?? ""
        for value in ["First worksheet", "Second worksheet", "42", "Row 100", "Value 100"] { XCTAssertTrue(text.contains(value), value) }
        let page = try XCTUnwrap(document.page(at: 0))
        let preview = page.thumbnail(of: NSSize(width: 1190, height: 1684), for: .mediaBox)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(preview.tiffRepresentation)))
        // The first boundary uses the XLSX width (145 pt), not a plain-text/tab layout.
        let color = try XCTUnwrap(bitmap.colorAt(x: 362, y: 150)?.usingColorSpace(.deviceRGB))
        XCTAssertLessThan(color.redComponent, 0.85)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: root.appendingPathComponent(".build/table-pdf-preview.png"))
    }
    func testXLSXColumnGeometryAndCachedFormulaValuesReachPDF() async throws {
        let original = directory.appendingPathComponent("Original.xlsx")
        try Spreadsheet.write([TableSheet(name: "Workbook", rows: [["Initial"]])], to: .xlsx, output: original, scratch: directory)
        let unpacked = directory.appendingPathComponent("Package")
        try FileManager.default.createDirectory(at: unpacked, withIntermediateDirectories: false)
        _ = try ArchiveReader(original).entries(extractingTo: unpacked)
        let sheet = unpacked.appendingPathComponent("xl/worksheets/sheet1.xml")
        let xml = #"""
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><cols><col min="1" max="1" width="20"/><col min="2" max="2" style="1"/><col min="3" max="3" width="0" hidden="1"/></cols><sheetData><row r="1" ht="28"><c r="A1" t="inlineStr"><is><t>Totals</t></is></c><c r="B1"><f>20+22</f><v>42</v></c></row><row r="2" ht="0"><c r="A2"><f>SUM(1,2)</f></c></row></sheetData></worksheet>
"""#
        try xml.write(to: sheet, atomically: false, encoding: .utf8)
        let input = directory.appendingPathComponent("Geometry.xlsx")
        _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/zip"), ["-q", "-r", input.path, "."], directory: unpacked)
        let scratch = try FileOperations.scratch(in: directory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let tables = try Spreadsheet.read(SourceFile(url: input), scratch: scratch)
        XCTAssertEqual(tables[0].columnWidths[0], 145)
        XCTAssertNil(tables[0].columnWidths[1])
        XCTAssertEqual(tables[0].columnWidths[2], 5)
        XCTAssertEqual(tables[0].rowHeights[0], 28)
        XCTAssertEqual(tables[0].rowHeights[1], 0)
        XCTAssertEqual(tables[0].rows, [["Totals", "42"], [""]])
        XCTAssertEqual(tables[0].uncachedFormulas[1]?[0], "SUM(1,2)")
        let pdf = try await ConversionEngine().convert(SourceFile(url: input), to: .pdf, in: directory)[0]
        let text = PDFDocument(url: pdf)?.string ?? ""
        XCTAssertTrue(text.contains("Totals")); XCTAssertTrue(text.contains("42")); XCTAssertTrue(text.contains("SUM"))
    }

    func testEmptySheetsPrintAndHugeSparseLayoutsFailWithoutExpandingBillionsOfCells() throws {
        let empty = directory.appendingPathComponent("Empty.pdf")
        try Spreadsheet.writePDF([TableSheet(name: "Empty worksheet", rows: [])], output: empty)
        XCTAssertEqual(PDFDocument(url: empty)?.pageCount, 1)
        let sparse = TableSheet(name: "Huge sparse sheet", rows: [Array(repeating: "", count: 16_384)] + Array(repeating: ["Last value"], count: 100))
        XCTAssertThrowsError(try Spreadsheet.writePDF([sparse], output: directory.appendingPathComponent("Sparse.pdf")))
    }

}
