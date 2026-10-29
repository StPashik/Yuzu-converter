import XCTest
import AppKit
import PDFKit
@testable import YuzuCore

final class SpreadsheetStyleTests: XCTestCase {
    func testCommonExcelNumberFormatsAndBothDateSystems() {
        let cases = [("40729", "yyyy-mm-dd", false, "2011-07-05"), ("39267", "yyyy-mm-dd", true, "2011-07-05"),
            ("1", "mm-dd-yy", false, "01-01-00"), ("61", "yyyy-mm-dd", false, "1900-03-01"),
            ("60", "yyyy-mm-dd", false, "60"), ("1234.5", "$#,##0.00", false, "$1,234.50"),
            ("9007199254740993", "0.00", false, "9007199254740993.00"),
            ("-1234.5", "#,##0.00;[Red](#,##0.00)", false, "(1,234.50)"),
            ("0.125", "0.0%", false, "12.5%"), ("0.5", "h:mm AM/PM", false, "12:00 PM"),
            ("1234.5", "[$€-407]#,##0.00", false, "€1,234.50"),
            ("3", "[>4]0;0", false, "3"), ("1.5", "# ?/?", false, "1.5")]
        for (raw, format, system, expected) in cases {
            XCTAssertEqual(ExcelNumberFormat.display(raw, format: format, date1904: system), expected, format)
        }
    }

    func testMergedRowsAndColumnBandsRetainLaterContent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("yuzu-merged-pages-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        var table = TableSheet(name: "Merged pages", rows: (0..<70).map { ["Row \($0)", "Value \($0)", "More \($0)", "Last \($0)"] })
        table.columnWidths = [0: 145, 1: 145, 2: 145, 3: 145]
        table.merges = [TableMerge(rows: 0...1, columns: 0...1)]
        table.rowHeights = [0: 450, 1: 450]
        let output = directory.appendingPathComponent("Merged.pdf")
        try Spreadsheet.writePDF([table], output: output)
        let document = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertGreaterThan(document.pageCount, 3)
        for value in ["Row 0", "Row 69", "Value 69", "More 69", "Last 69"] {
            XCTAssertTrue(document.string?.contains(value) == true, value)
        }
    }

    func testXLSXStylesMergedCellsAndFormattedValuesReachPDFWithoutChangingRawRows() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("yuzu-style-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("Base.xlsx")
        try Spreadsheet.write([TableSheet(name: "Invoice", rows: [["Base"]])], to: .xlsx, output: first, scratch: directory)
        let root = directory.appendingPathComponent("Unpacked")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        _ = try ArchiveReader(first).entries(extractingTo: root)
        let ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
        let styles = """
        <styleSheet xmlns="\(ns)"><numFmts><numFmt numFmtId="164" formatCode="yyyy-mm-dd"/><numFmt numFmtId="165" formatCode="$#,##0.00"/><numFmt numFmtId="166" formatCode="0.0%"/></numFmts><fonts><font><sz val="10"/></font><font><b/><sz val="18"/><color rgb="FFFFFFFF"/></font></fonts><fills><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF1F4E78"/></patternFill></fill></fills><borders><border/><border><left style="thin"><color rgb="FFFF0000"/></left><right style="thin"/><top style="thin"/><bottom style="thin"/></border></borders><cellXfs><xf fontId="0" fillId="0" borderId="0"/><xf fontId="1" fillId="1" borderId="0"><alignment horizontal="center"/></xf><xf fontId="0" fillId="0" borderId="1" numFmtId="164"/><xf fontId="0" fillId="0" borderId="1" numFmtId="165"/><xf fontId="0" fillId="0" borderId="1" numFmtId="166"/></cellXfs></styleSheet>
        """
        try styles.write(to: root.appendingPathComponent("xl/styles.xml"), atomically: false, encoding: .utf8)
        let xml = """
        <worksheet xmlns="\(ns)"><cols><col min="1" max="3" width="20" style="4"/></cols><sheetData><row r="1" ht="40"><c r="A1" t="inlineStr" s="1"><is><t>Invoice summary</t></is></c></row><row r="2" ht="30" s="3"><c r="A2" s="2"><v>40729</v></c><c r="B2"><v>1234.5</v></c><c r="C2" s="4"><v>0.125</v></c></row><row r="3"><c r="C3"><v>0.25</v></c></row></sheetData><mergeCells><mergeCell ref="A1:C1"/></mergeCells></worksheet>
        """
        let sheetURL = root.appendingPathComponent("xl/worksheets/sheet1.xml")
        try xml.write(to: sheetURL, atomically: false, encoding: .utf8)
        let input = directory.appendingPathComponent("Styled.xlsx")
        _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/zip"), ["-q", "-r", input.path, "."], directory: root)
        let scratch = try FileOperations.scratch(in: directory)
        let table = try XCTUnwrap(Spreadsheet.read(SourceFile(url: input), scratch: scratch).first)
        XCTAssertEqual(table.rows[1], ["40729", "1234.5", "0.125"])
        XCTAssertEqual(table.displayValues[1]?[0], "2011-07-05")
        XCTAssertEqual(table.merges.count, 1)
        XCTAssertEqual(table.displayValues[2]?[2], "25.0%")
        let pdf = try await ConversionEngine().convert(SourceFile(url: input), to: .pdf, in: directory)[0]
        let document = try XCTUnwrap(PDFDocument(url: pdf))
        for value in ["Invoice summary", "2011-07-05", "$1,234.50", "12.5%"] { XCTAssertTrue(document.string?.contains(value) == true, value) }
        let preview = try XCTUnwrap(document.page(at: 0)).thumbnail(of: NSSize(width: 1190, height: 1684), for: .mediaBox)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(preview.tiffRepresentation)))
        let blue = try XCTUnwrap(bitmap.colorAt(x: 362, y: 150)?.usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(blue.blueComponent, blue.redComponent + 0.2, "The merged header must retain its fill across the old cell boundary")
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: project.appendingPathComponent(".build/styled-table-preview.png"))
        // Reject malformed merges instead of hiding values under overlapping anchors.
        try xml.replacingOccurrences(of: "</mergeCells>", with: "<mergeCell ref=\"B1:C2\"/></mergeCells>").write(to: sheetURL, atomically: false, encoding: .utf8)
        let bad = directory.appendingPathComponent("Overlap.xlsx")
        _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/zip"), ["-q", "-r", bad.path, "."], directory: root)
        let badScratch = try FileOperations.scratch(in: directory)
        XCTAssertThrowsError(try Spreadsheet.read(SourceFile(url: bad), scratch: badScratch))
    }
}
