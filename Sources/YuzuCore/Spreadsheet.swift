import Foundation

/// A values-only sheet model: formula results are cached text, not formulas that can be recalculated.
struct TableSheet { let name: String; let rows: [[String]] }

/// Reads/writes CSV, TSV, and minimal editable XLSX/ODS packages without an Office runtime.
/// All sheets are retained, but styles, charts, formulas, and document layout are outside this model.
enum Spreadsheet {
    private static let tableNamespace = "urn:oasis:names:tc:opendocument:xmlns:table:1.0"
    private static let officeNamespace = "urn:oasis:names:tc:opendocument:xmlns:office:1.0"
    private static let textNamespace = "urn:oasis:names:tc:opendocument:xmlns:text:1.0"
    private static let spreadsheetNamespace = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    private static let relationshipsNamespace = "http://schemas.openxmlformats.org/package/2006/relationships"
    private static let documentRelationshipsNamespace = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    /// Extracts into private staging and returns sheets in document order, rejecting empty/unsupported workbooks.
    static func read(_ source: SourceFile, scratch: URL) throws -> [TableSheet] {
        if source.format == .csv || source.format == .tsv {
            return [TableSheet(name: "Sheet 1", rows: try DelimitedText.parse(TextFile.read(source.url), separator: source.format == .csv ? "," : "\t"))]
        }
        let root = scratch.appendingPathComponent("workbook", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        _ = try ArchiveReader(source.url).entries(extractingTo: root)
        if source.format == .ods {
            let xml = try XMLTree.read(root.appendingPathComponent("content.xml"))
            guard let book = xml.descendants("spreadsheet", namespace: officeNamespace).first else { throw ConversionError.invalid("The ODS file has no spreadsheet document.") }
            // ODS wraps rows in header/group containers; reading only direct children would silently lose them.
            func containedRows(_ node: XMLTree) -> [XMLTree] {
                node.children.flatMap { child -> [XMLTree] in
                    guard child.namespace == tableNamespace else { return [] }
                    if child.name == "table-row" { return [child] }
                    return ["table-header-rows", "table-row-group", "table-rows"].contains(child.name) ? containedRows(child) : []
                }
            }
            let tables = book.children.filter { $0.name == "table" && $0.namespace == tableNamespace }
            guard !tables.isEmpty else { throw ConversionError.invalid("The ODS workbook has no sheets.") }
            return try tables.map { table in
                var rows: [[String]] = []
                var cellCount = 0
                for row in containedRows(table) {
                    var cells: [String] = []
                    for cell in row.children.filter({ $0.namespace == tableNamespace && ($0.name == "table-cell" || $0.name == "covered-table-cell") }) {
                        let repeats = Int(cell.attribute("number-columns-repeated", namespace: tableNamespace) ?? "1") ?? 0
                        // Check remaining capacity before addition: attacker-controlled repeat counts can overflow Int.
                        guard repeats > 0, repeats <= 16_384 - cells.count else { throw ConversionError.invalid("The ODS file has too many columns.") }
                        let value = cell.descendants("p", namespace: textNamespace).map(\.textContent).joined(separator: "\n")
                        cells.append(contentsOf: repeatElement(value.isEmpty ? (cell.attribute("value", namespace: officeNamespace) ?? "") : value, count: repeats))
                    }
                    let repeats = Int(row.attribute("number-rows-repeated", namespace: tableNamespace) ?? "1") ?? 0
                    guard repeats > 0, repeats <= 100_000 - rows.count,
                          cells.isEmpty || repeats <= (1_000_000 - cellCount) / cells.count else { throw ConversionError.invalid("The ODS file has too many cells.") }
                    cellCount += repeats * cells.count
                    rows.append(contentsOf: repeatElement(cells, count: repeats))
                }
                return TableSheet(name: table.attribute("name", namespace: tableNamespace) ?? "Sheet", rows: rows)
            }
        }
        let sharedURL = root.appendingPathComponent("xl/sharedStrings.xml")
        let shared: [String] = FileManager.default.fileExists(atPath: sharedURL.path) ? try XMLTree.read(sharedURL).descendants("si", namespace: spreadsheetNamespace).map(\.textContent) : []
        let workbook = try XMLTree.read(root.appendingPathComponent("xl/workbook.xml"))
        let relationships = try XMLTree.read(root.appendingPathComponent("xl/_rels/workbook.xml.rels"))
        let sheets = workbook.descendants("sheet", namespace: spreadsheetNamespace)
        guard !sheets.isEmpty else { throw ConversionError.invalid("The XLSX file has no sheets or uses an unsupported XML namespace.") }
        return try sheets.map { sheet in
            guard let relation = relationships.descendants("Relationship", namespace: relationshipsNamespace).first(where: { $0.attributes["Id"] == sheet.attribute("id", namespace: documentRelationshipsNamespace) }),
                  let path = relation.attributes["Target"], !path.contains(".."), !path.contains(":") else { throw ConversionError.invalid("Invalid XLSX sheet path.") }
            let sheetURL = path.hasPrefix("/") ? root.appendingPathComponent(String(path.dropFirst())) : root.appendingPathComponent("xl/" + path)
            let xml = try XMLTree.read(sheetURL)
            var rows: [[String]] = []
            for row in xml.descendants("row", namespace: spreadsheetNamespace) {
                let number = Int(row.attributes["r"] ?? "\(rows.count + 1)") ?? 0
                guard number > 0, number <= 100_000 else { throw ConversionError.invalid("Invalid XLSX row number.") }
                while rows.count < number { rows.append([]) }
                for cell in row.children.filter({ $0.name == "c" && $0.namespace == spreadsheetNamespace }) {
                    // XLSX omits empty cells; use its A1 coordinates rather than treating XML order as dense data.
                    let letters = (cell.attributes["r"] ?? "A").prefix { $0.isLetter }
                    var column = 0
                    for byte in letters.uppercased().utf8 {
                        guard byte >= 65, byte <= 90, column < 16_384 else { throw ConversionError.invalid("Invalid XLSX column.") }
                        column = column * 26 + Int(byte - 64)
                    }
                    guard column > 0, column <= 16_384, number * column <= 1_000_000 else { throw ConversionError.invalid("The XLSX spreadsheet is too large.") }
                    while rows[number - 1].count < column { rows[number - 1].append("") }
                    let value = cell.children.first(where: { $0.name == "v" && $0.namespace == spreadsheetNamespace })?.textContent ?? ""
                    if cell.attributes["t"] == "s" {
                        guard let index = Int(value), shared.indices.contains(index) else { throw ConversionError.invalid("Invalid XLSX shared string reference.") }
                        rows[number - 1][column - 1] = shared[index]
                    } else if cell.attributes["t"] == "inlineStr" { rows[number - 1][column - 1] = cell.descendants("t", namespace: spreadsheetNamespace).map(\.textContent).joined() }
                    else { rows[number - 1][column - 1] = value }
                }
            }
            return TableSheet(name: sheet.attributes["name"] ?? "Sheet", rows: rows)
        }
    }

    /// Writes cells as editable strings into a new package; this does not preserve source workbook semantics.
    /// The caller owns cleanup/publication of output and scratch when writing or compression fails.
    static func write(_ sheets: [TableSheet], to format: FileFormat, output: URL, scratch: URL) throws {
        guard !sheets.isEmpty else { throw ConversionError.invalid("The workbook has no sheets.") }
        let root = scratch.appendingPathComponent("new-workbook", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        func put(_ path: String, _ text: String) throws {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: false, encoding: .utf8)
        }
        let escaped = NativeDocuments.xmlEscape
        if format == .ods {
            try put("mimetype", "application/vnd.oasis.opendocument.spreadsheet")
            try put("META-INF/manifest.xml", "<?xml version=\"1.0\"?><manifest:manifest xmlns:manifest=\"urn:oasis:names:tc:opendocument:xmlns:manifest:1.0\" manifest:version=\"1.2\"><manifest:file-entry manifest:full-path=\"/\" manifest:media-type=\"application/vnd.oasis.opendocument.spreadsheet\"/><manifest:file-entry manifest:full-path=\"content.xml\" manifest:media-type=\"text/xml\"/></manifest:manifest>")
            let tables = sheets.map { sheet in
                "<table:table table:name=\"\(escaped(sheet.name))\">" + sheet.rows.map { row in "<table:table-row>" + row.map { "<table:table-cell office:value-type=\"string\"><text:p>\(escaped($0))</text:p></table:table-cell>" }.joined() + "</table:table-row>" }.joined() + "</table:table>"
            }.joined()
            try put("content.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><office:document-content xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\" xmlns:table=\"urn:oasis:names:tc:opendocument:xmlns:table:1.0\" xmlns:text=\"urn:oasis:names:tc:opendocument:xmlns:text:1.0\" office:version=\"1.2\"><office:body><office:spreadsheet>\(tables)</office:spreadsheet></office:body></office:document-content>")
            // ODF requires the MIME entry first and uncompressed; add the remaining XML in a second pass.
            _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/zip"), ["-q", "-0", output.path, "mimetype"], directory: root)
            _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/zip"), ["-q", "-r", output.path, "content.xml", "META-INF"], directory: root)
            return
        }
        let ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
        let sheetsXML = sheets.enumerated().map { "<sheet name=\"\(escaped($0.element.name))\" sheetId=\"\($0.offset + 1)\" r:id=\"rId\($0.offset + 1)\"/>" }.joined()
        try put("xl/workbook.xml", "<?xml version=\"1.0\"?><workbook xmlns=\"\(ns)\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets>\(sheetsXML)</sheets></workbook>")
        let relations = sheets.indices.map { "<Relationship Id=\"rId\($0 + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\($0 + 1).xml\"/>" }.joined()
        try put("xl/_rels/workbook.xml.rels", "<?xml version=\"1.0\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\(relations)</Relationships>")
        try put("_rels/.rels", "<?xml version=\"1.0\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>")
        let overrides = sheets.indices.map { "<Override PartName=\"/xl/worksheets/sheet\($0 + 1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" }.joined()
        try put("[Content_Types].xml", "<?xml version=\"1.0\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>\(overrides)</Types>")
        for (sheetIndex, sheet) in sheets.enumerated() {
            let rows = sheet.rows.enumerated().map { rowIndex, values in
                "<row r=\"\(rowIndex + 1)\">" + values.enumerated().map { column, value in
                    "<c r=\"\(columnName(column + 1))\(rowIndex + 1)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escaped(value))</t></is></c>"
                }.joined() + "</row>"
            }.joined()
            try put("xl/worksheets/sheet\(sheetIndex + 1).xml", "<?xml version=\"1.0\"?><worksheet xmlns=\"\(ns)\"><sheetData>\(rows)</sheetData></worksheet>")
        }
        _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/zip"), ["-q", "-r", output.path, "."], directory: root)
    }
    private static func columnName(_ value: Int) -> String {
        var result = "", value = value
        while value > 0 { value -= 1; result = String(UnicodeScalar(65 + value % 26)!) + result; value /= 26 }
        return result
    }
}

/// A small namespace-aware tree for package XML, with declaration prechecks and explicit size/depth/node limits.
/// External entity loading stays disabled; this is a document helper rather than a general XML resolver.
final class XMLTree: NSObject, XMLParserDelegate {
    let name: String
    let namespace: String?
    let attributes: [String: String]
    var children: [XMLTree] = []
    // Ordered fragments preserve mixed text/markup without duplicating every descendant's text in its ancestors.
    private enum Part { case text(String), child(XMLTree) }
    private var parts: [Part] = []
    private var stack: [XMLTree] = []
    private var count = 0
    // Prefixes can be rebound inside nested elements, so each prefix needs a stack rather than one global value.
    private var namespaceMappings = ["xml": ["http://www.w3.org/XML/1998/namespace"]]
    init(name: String = "", namespace: String? = nil, attributes: [String: String] = [:]) { self.name = name; self.namespace = namespace; self.attributes = attributes }
    var textContent: String {
        parts.map { part in
            switch part {
            case .text(let text): return text
            case .child(let child): return child.textContent
            }
        }.joined()
    }
    /// Qualified attributes are addressed by URI/local name, independent of an author's chosen prefix.
    func attribute(_ name: String, namespace: String? = nil) -> String? { attributes[namespace.map { "{\($0)}" + name } ?? name] }
    func descendants(_ name: String, namespace: String? = nil) -> [XMLTree] {
        children.flatMap { ($0.name == name && (namespace == nil || $0.namespace == namespace) ? [$0] : []) + $0.descendants(name, namespace: namespace) }
    }
    static func read(_ url: URL) throws -> XMLTree {
        let data = try Data(contentsOf: url)
        guard data.count <= 32 * 1024 * 1024,
              String(decoding: data, as: UTF8.self).range(of: "<!DOCTYPE|<!ENTITY", options: [.regularExpression, .caseInsensitive]) == nil else { throw ConversionError.invalid("The XML is unsafe or too large.") }
        let root = XMLTree()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        parser.delegate = root
        root.stack = [root]
        guard parser.parse() else { throw ConversionError.invalid("Invalid XML: \(url.lastPathComponent)") }
        return root
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        count += 1
        guard count <= 1_000_000, stack.count < 64 else { parser.abortParsing(); return }
        var attributes = attributeDict
        for (name, value) in attributeDict where name.contains(":") && !name.hasPrefix("xmlns:") {
            let pieces = name.split(separator: ":", maxSplits: 1)
            guard pieces.count == 2, let namespace = namespaceMappings[String(pieces[0])]?.last else { parser.abortParsing(); return }
            attributes["{\(namespace)}\(pieces[1])"] = value
        }
        let child = XMLTree(name: elementName, namespace: namespaceURI, attributes: attributes)
        stack.last?.children.append(child)
        stack.last?.parts.append(.child(child))
        stack.append(child)
    }
    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String) { namespaceMappings[prefix, default: []].append(namespaceURI) }
    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) { _ = namespaceMappings[prefix]?.popLast() }
    func parser(_ parser: XMLParser, foundCharacters string: String) { stack.last?.parts.append(.text(string)) }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let text = String(data: CDATABlock, encoding: .utf8) else { parser.abortParsing(); return }
        stack.last?.parts.append(.text(text))
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) { if stack.count > 1 { stack.removeLast() } }
}
