import AppKit
import CoreText

extension Spreadsheet {
    /// Print cached values with source cell styling; this remains a table renderer, not an Excel calculation engine.
    static func writePDF(_ sheets: [TableSheet], output: URL) throws {
        var page = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let context = CGContext(output as CFURL, mediaBox: &page, nil) else { throw ConversionError.failed("Could not create the table PDF.") }
        defer { context.closePDF() }
        let usableWidth: CGFloat = 523, top: CGFloat = 776, bottom: CGFloat = 36
        func text(_ value: String, style: TableCellStyle = .init()) -> CTFramesetter {
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = style.alignment
            return CTFramesetterCreateWithAttributedString(NSAttributedString(string: value,
                attributes: [.font: style.font, .foregroundColor: style.color, .paragraphStyle: paragraph]))
        }
        func draw(_ setter: CTFramesetter, offset: Int = 0, in rect: CGRect) -> Int {
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: offset, length: 0), CGPath(rect: rect, transform: nil), nil)
            CTFrameDraw(frame, context)
            return CTFrameGetVisibleStringRange(frame).length
        }
        func background(_ rect: CGRect, _ style: TableCellStyle?) {
            if let fill = style?.fill { context.setFillColor(fill.cgColor); context.fill(rect) }
            // Plain tables retain a readable grid; explicit XLSX borders replace that fallback.
            if let style {
                let edges = [(CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX, y: rect.maxY)),
                    (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY)),
                    (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)),
                    (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY))]
                for (index, edge) in edges.enumerated() {
                    guard let border = style.borders[index] else { continue }
                    context.setStrokeColor(border.color.cgColor); context.setLineWidth(border.width)
                    context.setLineDash(phase: 0, lengths: border.dashed ? [2, 2] : [])
                    context.move(to: edge.0); context.addLine(to: edge.1); context.strokePath()
                }
                context.setLineDash(phase: 0, lengths: [])
            } else {
                context.setStrokeColor(CGColor(gray: 0.55, alpha: 1)); context.setLineWidth(0.4); context.stroke(rect)
            }
        }
        var pageCount = 0
        func beginPage(_ title: String) throws {
            guard pageCount < 10_000 else { throw ConversionError.unsupported("The table exceeds 10,000 PDF pages.") }
            pageCount += 1; context.beginPDFPage(nil)
            context.setFillColor(CGColor.white); context.fill(page)
            var style = TableCellStyle(); style.font = .systemFont(ofSize: 13, weight: .semibold)
            _ = draw(text(title, style: style), in: CGRect(x: 36, y: 790, width: usableWidth, height: 22))
        }
        for sheet in sheets {
            try Task.checkCancellation()
            let count = max(sheet.rows.map(\.count).max() ?? 0, (sheet.merges.map { $0.columns.upperBound }.max() ?? -1) + 1)
            let rowCount = max(sheet.rows.count, (sheet.merges.map { $0.rows.upperBound }.max() ?? -1) + 1)
            if count == 0 { try beginPage(sheet.name); context.endPDFPage(); continue }
            guard rowCount <= 1_000_000 / count else { throw ConversionError.unsupported("The sparse table is too large to print safely.") }
            func value(_ row: Int, _ col: Int) -> String {
                let value = sheet.displayValues[row]?[col] ?? (row < sheet.rows.count && col < sheet.rows[row].count ? sheet.rows[row][col] : "")
                return value.isEmpty ? sheet.uncachedFormulas[row]?[col].map { "=" + $0 } ?? "" : value
            }
            let widths: [CGFloat] = (0..<count).map { col in
                if let width = sheet.columnWidths[col] { return min(usableWidth, max(36, width)) }
                let length = (0..<min(rowCount, 200)).map { min(80, value($0, col).count) }.max() ?? 0
                return min(180, max(60, CGFloat(length) * 5.5 + 12))
            }
            var bands: [Range<Int>] = [], start = 0
            var width: CGFloat = 0
            for col in 0..<count {
                if width + widths[col] > usableWidth, col > start { bands.append(start..<col); start = col; width = 0 }
                width += widths[col]
            }
            bands.append(start..<count)
            var x: [CGFloat] = [0]
            for width in widths { x.append(x.last! + width) }
            var merges: [Int: TableMerge] = [:]
            for merge in sheet.merges { for row in merge.rows { for col in merge.columns { merges[row * count + col] = merge } } }
            var heights = (0..<rowCount).map { max(22, sheet.rowHeights[$0] ?? 0) }
            // Measure anchors once. Extra merged-cell height belongs to its final row, preserving following rows.
            for row in 0..<rowCount {
                try Task.checkCancellation()
                for col in 0..<count {
                    let merge = merges[row * count + col]
                    if let merge, row != merge.rows.lowerBound || col != merge.columns.lowerBound { continue }
                    let lastCol = merge?.columns.upperBound ?? col, lastRow = merge?.rows.upperBound ?? row
                    let setter = text(value(row, col), style: sheet.printStyles[row]?[col] ?? .init())
                    let needed = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(), nil,
                        CGSize(width: x[lastCol + 1] - x[col] - 10, height: .greatestFiniteMagnitude), nil).height + 10
                    heights[lastRow] += max(0, needed - heights[row...lastRow].reduce(0, +))
                }
            }
            // Keep vertically connected merges together when they fit; oversized blocks continue by clipping
            // the same geometry on successive pages, so no covered cell or text is silently discarded.
            var blocks: [Range<Int>] = [], row = 0
            var mergeEnds: [Int: Int] = [:]
            for merge in sheet.merges { mergeEnds[merge.rows.lowerBound] = max(mergeEnds[merge.rows.lowerBound] ?? 0, merge.rows.upperBound) }
            while row < rowCount {
                var end = row
                var next = row
                while next <= end { end = max(end, mergeEnds[next] ?? next); next += 1 }
                blocks.append(row..<(end + 1)); row = end + 1
            }
            for band in bands {
                var y = top
                let title = bands.count == 1 ? sheet.name : sheet.name + " — Columns \(band.lowerBound + 1)–\(band.upperBound)"
                try beginPage(title)
                for block in blocks {
                    try Task.checkCancellation()
                    let height = heights[block].reduce(0, +)
                    if y - min(height, top - bottom) < bottom { context.endPDFPage(); try beginPage(title); y = top }
                    var consumed: CGFloat = 0
                    repeat {
                        let slice = min(height - consumed, y - bottom)
                        context.saveGState()
                        context.clip(to: CGRect(x: 35.5, y: y - slice, width: min(usableWidth, x[band.upperBound] - x[band.lowerBound]) + 1, height: slice))
                        var cellY = y + consumed
                        for row in block {
                            for col in 0..<count {
                                let merge = merges[row * count + col]
                                if let merge, row != merge.rows.lowerBound || col != merge.columns.lowerBound { continue }
                                let lastCol = merge?.columns.upperBound ?? col, lastRow = merge?.rows.upperBound ?? row
                                guard col < band.upperBound, lastCol >= band.lowerBound else { continue }
                                let cellHeight = heights[row...lastRow].reduce(0, +)
                                let rect = CGRect(x: 36 + x[col] - x[band.lowerBound], y: cellY - cellHeight,
                                    width: x[lastCol + 1] - x[col], height: cellHeight)
                                let style = sheet.printStyles[row]?[col]
                                background(rect, style)
                                _ = draw(text(value(row, col), style: style ?? .init()), in: rect.insetBy(dx: 5, dy: 5))
                            }
                            cellY -= heights[row]
                        }
                        context.restoreGState()
                        y -= slice; consumed += slice
                        if consumed < height { try Task.checkCancellation(); context.endPDFPage(); try beginPage(title); y = top }
                    } while consumed < height
                }
                context.endPDFPage()
            }
        }
    }
}
