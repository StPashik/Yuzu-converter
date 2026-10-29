import AppKit

struct TableMerge {
    let rows: ClosedRange<Int>
    let columns: ClosedRange<Int>
}

struct TableCellStyle {
    var font = NSFont.systemFont(ofSize: 10)
    var color = NSColor.black
    var fill: NSColor?
    var borders: [TableBorder?] = Array(repeating: nil, count: 4) // left, right, top, bottom
    var alignment: NSTextAlignment = .left
    var numberFormat = "General"
}

struct TableBorder {
    let color: NSColor
    let width: CGFloat
    let dashed: Bool
}

/// Print-only XLSX metadata: values-only CSV/XLSX/ODS exports keep their original semantics.
struct SpreadsheetStyles {
    private static let ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    let cells: [TableCellStyle]

    init(root: URL) throws {
        let url = root.appendingPathComponent("xl/styles.xml")
        guard FileManager.default.fileExists(atPath: url.path) else { cells = []; return }
        let xml = try XMLTree.read(url)
        let themeURL = root.appendingPathComponent("xl/theme/theme1.xml")
        let theme: [NSColor]
        if FileManager.default.fileExists(atPath: themeURL.path) {
            let tree = try XMLTree.read(themeURL)
            let colors = tree.descendants("clrScheme").first?.children ?? []
            let order = ["lt1", "dk1", "lt2", "dk2", "accent1", "accent2", "accent3", "accent4", "accent5", "accent6", "hlink", "folHlink"]
            theme = order.map { name in
                let node = colors.first { $0.name == name }?.children.first
                return Self.rgb(node?.attributes["lastClr"] ?? node?.attributes["val"] ?? "") ?? .black
            }
        } else { theme = [] }
        let indexed = xml.descendants("indexedColors", namespace: Self.ns).first?.children.compactMap { Self.rgb($0.attributes["rgb"] ?? "") } ?? []
        func color(_ node: XMLTree?) throws -> NSColor? {
            guard let node else { return nil }
            var result = Self.rgb(node.attributes["rgb"] ?? "")
            if let index = Int(node.attributes["theme"] ?? ""), theme.indices.contains(index) { result = theme[index] }
            if let index = Int(node.attributes["indexed"] ?? "") {
                let palette = indexed.isEmpty ? Self.palette : indexed
                if palette.indices.contains(index) { result = palette[index] }
            }
            guard let rgb = result?.usingColorSpace(.deviceRGB) else { return nil }
            let tint = Double(node.attributes["tint"] ?? "0") ?? 0
            guard tint.isFinite, (-1...1).contains(tint) else { throw ConversionError.invalid("Invalid XLSX color tint.") }
            func component(_ value: CGFloat) -> CGFloat { tint < 0 ? value * (1 + tint) : value * (1 - tint) + tint }
            return NSColor(deviceRed: component(rgb.redComponent), green: component(rgb.greenComponent), blue: component(rgb.blueComponent), alpha: 1)
        }
        func items(_ name: String) -> [XMLTree] { xml.descendants(name, namespace: Self.ns).first?.children ?? [] }
        let fonts = items("fonts"), fills = items("fills"), borders = items("borders")
        let formats = Dictionary(items("numFmts").compactMap { node -> (Int, String)? in
            guard let id = Int(node.attributes["numFmtId"] ?? ""), let code = node.attributes["formatCode"] else { return nil }
            return (id, code)
        }, uniquingKeysWith: { _, last in last })
        cells = try items("cellXfs").map { xf in
            var style = TableCellStyle()
            func item(_ list: [XMLTree], _ key: String) throws -> XMLTree? {
                guard let raw = xf.attributes[key] else { return nil }
                guard let id = Int(raw), list.indices.contains(id) else { throw ConversionError.invalid("Invalid XLSX style reference.") }
                return list[id]
            }
            if let font = try item(fonts, "fontId"), xf.attributes["applyFont"] != "0" {
                let size = Double(font.children.first { $0.name == "sz" }?.attributes["val"] ?? "10") ?? 10
                guard size.isFinite, (1...4096).contains(size) else { throw ConversionError.invalid("Invalid XLSX font size.") }
                let name = font.children.first { $0.name == "name" }?.attributes["val"] ?? ""
                var face = NSFont(name: name, size: min(72, size)) ?? .systemFont(ofSize: min(72, size))
                for (tag, trait) in [("b", NSFontTraitMask.boldFontMask), ("i", .italicFontMask)] {
                    if let node = font.children.first(where: { $0.name == tag }), node.attributes["val"] != "0", node.attributes["val"] != "false" {
                        face = NSFontManager.shared.convert(face, toHaveTrait: trait)
                    }
                }
                style.font = face
                style.color = try color(font.children.first { $0.name == "color" }) ?? .black
            }
            if let fill = try item(fills, "fillId"), xf.attributes["applyFill"] != "0",
               let pattern = fill.children.first(where: { $0.name == "patternFill" }), pattern.attributes["patternType"] == "solid" {
                style.fill = try color(pattern.children.first { $0.name == "fgColor" })
            }
            if let border = try item(borders, "borderId"), xf.attributes["applyBorder"] != "0" {
                style.borders = try ["left", "right", "top", "bottom"].map { edge in
                    guard let side = border.children.first(where: { $0.name == edge }), let kind = side.attributes["style"], kind != "none" else { return nil }
                    return TableBorder(color: try color(side.children.first { $0.name == "color" }) ?? .black,
                        width: kind == "thick" ? 2 : kind.hasPrefix("medium") || kind == "double" ? 1.3 : kind == "hair" ? 0.25 : 0.6,
                        dashed: kind.lowercased().contains("dash") || kind == "dotted")
                }
            }
            if let alignment = xf.children.first(where: { $0.name == "alignment" }), xf.attributes["applyAlignment"] != "0" {
                style.alignment = ["center": .center, "right": .right, "justify": .justified][alignment.attributes["horizontal"] ?? ""] ?? .left
            }
            if let id = Int(xf.attributes["numFmtId"] ?? "0"), xf.attributes["applyNumberFormat"] != "0" { style.numberFormat = formats[id] ?? ExcelNumberFormat.builtins[id] ?? "General" }
            return style
        }
    }

    private static func rgb(_ raw: String) -> NSColor? {
        let value = raw.count == 8 ? String(raw.suffix(6)) : raw
        guard value.count == 6, let hex = UInt32(value, radix: 16) else { return nil }
        return NSColor(deviceRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    private static let palette = ["000000","FFFFFF","FF0000","00FF00","0000FF","FFFF00","FF00FF","00FFFF","000000","FFFFFF","FF0000","00FF00","0000FF","FFFF00","FF00FF","00FFFF","800000","008000","000080","808000","800080","008080","C0C0C0","808080","9999FF","993366","FFFFCC","CCFFFF","660066","FF8080","0066CC","CCCCFF","000080","FF00FF","FFFF00","00FFFF","800080","800000","008080","0000FF","00CCFF","CCFFFF","CCFFCC","FFFF99","99CCFF","FF99CC","CC99FF","FFCC99","3366FF","33CCCC","99CC00","FFCC00","FF9900","FF6600","666699","969696","003366","339966","003300","333300","993300","993366","333399","333333"].compactMap(rgb)
}

/// A deliberately bounded subset of Excel display formats; unknown patterns retain the raw value.
/// shortcut: conditional/scientific/fraction formats stay raw; extend only with real workbook fixtures.
enum ExcelNumberFormat {
    static let builtins: [Int: String] = [0:"General",1:"0",2:"0.00",3:"#,##0",4:"#,##0.00",5:"$#,##0;($#,##0)",6:"$#,##0;[Red]($#,##0)",7:"$#,##0.00;($#,##0.00)",8:"$#,##0.00;[Red]($#,##0.00)",9:"0%",10:"0.00%",14:"mm-dd-yy",15:"d-mmm-yy",16:"d-mmm",17:"mmm-yy",18:"h:mm AM/PM",19:"h:mm:ss AM/PM",20:"h:mm",21:"h:mm:ss",22:"m/d/yy h:mm",37:"#,##0;(#,##0)",38:"#,##0;[Red](#,##0)",39:"#,##0.00;(#,##0.00)",40:"#,##0.00;[Red](#,##0.00)"]
    static func display(_ raw: String, format: String, date1904: Bool) -> String {
        guard format != "General", let number = Double(raw), number.isFinite, format.count <= 512 else { return raw }
        let sections = format.components(separatedBy: ";")
        var pattern = sections[min(number < 0 && sections.count > 1 ? 1 : number == 0 && sections.count > 2 ? 2 : 0, sections.count - 1)]
        // Color directives do not affect the numeric value; unsupported conditions must never change it.
        if pattern.range(of: #"\[[<>=]"#, options: .regularExpression) != nil { return raw }
        pattern = pattern.replacingOccurrences(of: #"\[(Black|Blue|Cyan|Green|Magenta|Red|White|Yellow)\]"#, with: "", options: [.regularExpression, .caseInsensitive])
        pattern = pattern.replacingOccurrences(of: #"\[\$([^\]-]*)-[^\]]*\]"#, with: #""$1""#, options: .regularExpression)
        if let date = date(raw: number, pattern: pattern, date1904: date1904) { return date }
        guard !pattern.contains("["), !pattern.contains("?"), !pattern.lowercased().contains("e+"), !pattern.lowercased().contains("e-"), pattern.contains("0") || pattern.contains("#") else { return raw }
        pattern = pattern.replacingOccurrences(of: #"_.|\*."#, with: "", options: .regularExpression)
        // ICU accepts the shared decimal/grouping/percent grammar; Excel quotes and backslashes become literals.
        pattern = pattern.replacingOccurrences(of: #"\\(.)"#, with: #""$1""#, options: .regularExpression)
        pattern = pattern.replacingOccurrences(of: "'", with: "''").replacingOccurrences(of: "\"", with: "'")
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.positiveFormat = pattern
        formatter.negativeFormat = sections.count > 1 && number < 0 ? pattern : "-" + pattern
        return formatter.string(from: NSDecimalNumber(string: raw, locale: Locale(identifier: "en_US_POSIX"))) ?? raw
    }

    private static func date(raw: Double, pattern: String, date1904: Bool) -> String? {
        let tokens = try! NSRegularExpression(pattern: #"\"[^\"]*\"|\\.|AM/PM|am/pm|[a-zA-Z]+|."#)
        let ns = pattern as NSString
        let parts = tokens.matches(in: pattern, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
        guard parts.contains(where: { ["y","yy","yyyy","d","dd","ddd","dddd","h","hh","s","ss"].contains($0.lowercased()) }), !pattern.contains("[") else { return nil }
        guard raw >= 0, raw < 2_958_466 else { return nil }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let base = calendar.date(from: DateComponents(year: date1904 ? 1904 : 1899, month: date1904 ? 1 : 12, day: date1904 ? 1 : 31))!
        // Excel's fictitious 1900-02-29 has no Foundation Date. Keep its serial visible rather than invent a date.
        if !date1904 && Int(raw) == 60 { return nil }
        let date = base.addingTimeInterval((raw - (!date1904 && raw >= 61 ? 1 : 0)) * 86400)
        let ampm = parts.contains { $0.uppercased() == "AM/PM" }
        var output = ""
        for (index, part) in parts.enumerated() {
            let token = part.lowercased()
            if part.hasPrefix("\"") { output += "'" + part.dropFirst().dropLast().replacingOccurrences(of: "'", with: "''") + "'" }
            else if part.hasPrefix("\\") { output += "'" + part.dropFirst() + "'" }
            else if token == "am/pm" { output += "a" }
            else if token.allSatisfy({ $0 == "m" }) {
                let before = parts[..<index].last { $0.first?.isLetter == true }?.lowercased() ?? ""
                let after = parts[(index + 1)...].first { $0.first?.isLetter == true }?.lowercased() ?? ""
                output += before.hasPrefix("h") || after.hasPrefix("s") ? token : token.uppercased()
            } else if token.allSatisfy({ $0 == "h" }) { output += ampm ? token : token.uppercased() }
            else if ["ddd", "dddd"].contains(token) { output += token == "ddd" ? "EEE" : "EEEE" }
            else if ["y","yy","yyyy","d","dd","s","ss"].contains(token) { output += token }
            else if part.first?.isLetter == true { return nil }
            else { output += part }
        }
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = output
        return formatter.string(from: date)
    }
}
