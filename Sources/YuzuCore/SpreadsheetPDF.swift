import AppKit
import CoreText

extension Spreadsheet {
    /// Print a readable table, including cached formula values; this is not an Excel calculation/layout engine.
    static func writePDF(_ sheets: [TableSheet], output: URL) throws {
        var page = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let context = CGContext(output as CFURL, mediaBox: &page, nil) else {
            throw ConversionError.failed("Could not create the table PDF.")
        }
        defer { context.closePDF() }
        let font = NSFont.systemFont(ofSize: 10)
        let usableWidth: CGFloat = 523
        let top: CGFloat = 776, bottom: CGFloat = 36
        func text(_ value: String, font: NSFont) -> CTFramesetter {
            CTFramesetterCreateWithAttributedString(NSAttributedString(string: value,
                attributes: [.font: font, .foregroundColor: NSColor.black]))
        }
        func draw(_ setter: CTFramesetter, offset: Int = 0, in rect: CGRect) -> Int {
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: offset, length: 0),
                                                CGPath(rect: rect, transform: nil), nil)
            CTFrameDraw(frame, context)
            return CTFrameGetVisibleStringRange(frame).length
        }
        var pageCount = 0
        func beginPage(_ title: String) throws {
            guard pageCount < 10_000 else { throw ConversionError.unsupported("The table exceeds 10,000 PDF pages.") }
            pageCount += 1
            context.beginPDFPage(nil)
            context.setFillColor(CGColor.white); context.fill(page)
            _ = draw(text(title, font: .systemFont(ofSize: 13, weight: .semibold)),
                     in: CGRect(x: 36, y: 790, width: usableWidth, height: 22))
        }
        for sheet in sheets {
            try Task.checkCancellation()
            let count = sheet.rows.map(\.count).max() ?? 0
            if count == 0 { try beginPage(sheet.name); context.endPDFPage(); continue }
            guard sheet.rows.count <= 1_000_000 / count else {
                throw ConversionError.unsupported("The sparse table is too large to print safely.")
            }
            // Wide sheets continue in column bands instead of shrinking text into an unreadable single page.
            let widths: [CGFloat] = (0..<count).map { col in
                if let width = sheet.columnWidths[col] { return min(usableWidth, max(36, width)) }
                let length = sheet.rows.prefix(200).map { col < $0.count ? min(80, $0[col].count) : 0 }.max() ?? 0
                return min(180, max(60, CGFloat(length) * 5.5 + 12))
            }
            var bands: [Range<Int>] = []
            var start = 0, width: CGFloat = 0
            for col in 0..<count {
                if width + widths[col] > usableWidth, col > start {
                    bands.append(start..<col); start = col; width = 0
                }
                width += widths[col]
            }
            bands.append(start..<count)
            for band in bands {
                var y = top
                let title = bands.count == 1 ? sheet.name : sheet.name + " — Columns \(band.lowerBound + 1)–\(band.upperBound)"
                func newPage() throws { try beginPage(title); y = top }
                try newPage()
                for (index, row) in sheet.rows.enumerated() {
                    try Task.checkCancellation()
                    if y - 22 < bottom { context.endPDFPage(); try newPage() }
                    let values = band.map { col -> String in
                        let value = col < row.count ? row[col] : ""
                        if value.isEmpty, let formula = sheet.uncachedFormulas[index]?[col] { return "=" + formula }
                        return value
                    }
                    let setters = values.map { text($0, font: font) }
                    let heights = band.enumerated().map { offset, col in
                        CTFramesetterSuggestFrameSizeWithConstraints(setters[offset], CFRange(), nil,
                            CGSize(width: widths[col] - 10, height: .greatestFiniteMagnitude), nil).height + 10
                    }
                    var height = max(22, max(sheet.rowHeights[index] ?? 0, heights.max() ?? 0))
                    if height <= top - bottom, y - height < bottom {
                        context.endPDFPage(); try newPage()
                    }
                    var offsets = Array(repeating: 0, count: values.count)
                    repeat {
                        try Task.checkCancellation()
                        let slice = min(height, y - bottom)
                        var x: CGFloat = 36
                        var unfinished = false
                        for (offset, col) in band.enumerated() {
                            let rect = CGRect(x: x, y: y - slice, width: widths[col], height: slice)
                            context.setStrokeColor(CGColor(gray: 0.55, alpha: 1)); context.setLineWidth(0.4)
                            context.stroke(rect)
                            let length = (values[offset] as NSString).length
                            if offsets[offset] < length {
                                let visible = draw(setters[offset], offset: offsets[offset], in: rect.insetBy(dx: 5, dy: 5))
                                guard visible > 0 else { throw ConversionError.failed("Could not fit a table cell on the PDF page.") }
                                offsets[offset] += visible
                                unfinished = unfinished || offsets[offset] < length
                            }
                            x += widths[col]
                        }
                        y -= slice
                        if unfinished {
                            context.endPDFPage(); try newPage()
                            height = top - bottom
                        } else { break }
                    } while true
                }
                context.endPDFPage()
            }
        }
    }
}
