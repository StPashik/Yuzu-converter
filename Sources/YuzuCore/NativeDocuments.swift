import AppKit
import CoreText
import PDFKit
import ImageIO

enum NativeDocuments {
    static func image(_ source: URL, to target: FileFormat, output: URL) throws {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil), CGImageSourceGetCount(imageSource) > 0 else {
            if let image = NSImage(contentsOf: source), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                try writeImage(cgImage, to: target, output: output)
                return
            }
            throw ConversionError.invalid("Не удалось декодировать изображение.")
        }
        let count = CGImageSourceGetCount(imageSource)
        if target == .pdf {
            guard let context = CGContext(output as CFURL, mediaBox: nil, nil) else { throw ConversionError.failed("Не удалось создать PDF.") }
            defer { context.closePDF() }
            for index in 0..<count {
                try Task.checkCancellation()
                guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [String: Any],
                      let width = properties[kCGImagePropertyPixelWidth as String] as? NSNumber,
                      let height = properties[kCGImagePropertyPixelHeight as String] as? NSNumber else { throw ConversionError.invalid("Не удалось прочитать размер изображения.") }
                // ImageIO applies EXIF rotation while keeping the original pixel resolution.
                let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                               kCGImageSourceCreateThumbnailWithTransform: true,
                               kCGImageSourceThumbnailMaxPixelSize: max(width.intValue, height.intValue)] as CFDictionary
                guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, index, options) else { throw ConversionError.invalid("Повреждённая страница изображения.") }
                var bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
                let box = NSData(bytes: &bounds, length: MemoryLayout<CGRect>.size)
                context.beginPDFPage([kCGPDFContextMediaBox as String: box] as CFDictionary)
                context.draw(image, in: bounds)
                context.endPDFPage()
            }
            return
        }
        guard let identifier = target.imageType else { throw ConversionError.unsupported("Нет ImageIO writer для \(target.label).") }
        let frames = target == .tiff ? count : 1
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, identifier as CFString, frames, nil) else { throw ConversionError.failed("ImageIO не умеет записывать \(target.label).") }
        for index in 0..<frames {
            try Task.checkCancellation()
            CGImageDestinationAddImageFromSource(destination, imageSource, index, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else { throw ConversionError.failed("Не удалось записать изображение.") }
    }

    static func writeImage(_ image: CGImage, to target: FileFormat, output: URL, dpi: Double = 72) throws {
        if target == .pdf {
            var box = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            guard let context = CGContext(output as CFURL, mediaBox: &box, nil) else { throw ConversionError.failed("Не удалось создать PDF.") }
            context.beginPDFPage(nil); context.draw(image, in: box); context.endPDFPage(); context.closePDF()
            return
        }
        guard let identifier = target.imageType,
              let destination = CGImageDestinationCreateWithURL(output as CFURL, identifier as CFString, 1, nil) else { throw ConversionError.unsupported("Нет writer для \(target.label).") }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9, kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ConversionError.failed("Не удалось завершить запись изображения.") }
    }

    static func pdfPages(_ source: URL, to target: FileFormat, directory: URL) throws -> [URL] {
        guard let document = CGPDFDocument(source as CFURL), !document.isEncrypted || document.isUnlocked, document.numberOfPages > 0 else {
            throw ConversionError.invalid("PDF повреждён, пуст или защищён паролем.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        var outputs: [URL] = []
        for index in 1...document.numberOfPages {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { throw ConversionError.invalid("Не удалось прочитать страницу \(index).") }
            let bounds = page.getBoxRect(.mediaBox)
            let rotated = abs(page.rotationAngle) % 180 != 0
            let widthPoints = rotated ? bounds.height : bounds.width
            let heightPoints = rotated ? bounds.width : bounds.height
            let width = ceil(widthPoints * 300 / 72), height = ceil(heightPoints * 300 / 72)
            // Reject oversized pages instead of silently lowering the promised 300 DPI.
            guard width.isFinite, height.isFinite, width > 0, height > 0, width <= 32768, height <= 32768, width * height <= 64_000_000 else {
                throw ConversionError.unsupported("Страница \(index) слишком велика для безопасного рендера при 300 DPI.")
            }
            guard let space = CGColorSpace(name: CGColorSpace.sRGB), let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw ConversionError.failed("Недостаточно памяти для страницы \(index).")
            }
            let rect = CGRect(x: 0, y: 0, width: width, height: height)
            context.setFillColor(CGColor.white); context.fill(rect)
            context.concatenate(page.getDrawingTransform(.mediaBox, rect: rect, rotate: 0, preserveAspectRatio: true))
            context.drawPDFPage(page)
            guard let image = context.makeImage() else { throw ConversionError.failed("Не удалось отрисовать страницу \(index).") }
            let output = directory.appendingPathComponent(String(format: "Page %03d.%@", index, target.fileExtension))
            try writeImage(image, to: target, output: output, dpi: 300)
            outputs.append(output)
        }
        return outputs
    }

    static func readText(_ source: SourceFile, scratch: URL) throws -> NSAttributedString {
        if source.format == .txt || source.format == .md {
            let text = try TextFile.read(source.url)
            if source.format == .md { return NSAttributedString(try AttributedString(markdown: text)) }
            return NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 12)])
        }
        if source.format == .pdf {
            guard let pdf = PDFDocument(url: source.url), !pdf.isLocked, let text = pdf.string else { throw ConversionError.invalid("В PDF нет доступного текстового слоя.") }
            return NSAttributedString(string: text)
        }
        let output = scratch.appendingPathComponent("read.rtf")
        _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/textutil"), ["-noload", "-convert", "rtf", "-output", output.path, "-format", source.format.rawValue, source.url.path])
        guard let attributed = NSAttributedString(rtf: try Data(contentsOf: output), documentAttributes: nil) else { throw ConversionError.invalid("Не удалось прочитать документ.") }
        return attributed
    }

    static func writeText(_ text: NSAttributedString, to target: FileFormat, output: URL) throws {
        if target == .txt || target == .md {
            try text.string.write(to: output, atomically: false, encoding: .utf8)
            return
        }
        if target == .pdf { try writePDF(text, output: output); return }
        let type: NSAttributedString.DocumentType
        switch target {
        case .docx: type = .officeOpenXML
        case .rtf: type = .rtf
        case .html: type = .html
        default: throw ConversionError.unsupported("Нет writer для \(target.label).")
        }
        let data = try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: type])
        try data.write(to: output)
    }

    static func writePDF(_ text: NSAttributedString, output: URL) throws {
        let text = NSMutableAttributedString(attributedString: text)
        if text.length == 0 { text.append(NSAttributedString(string: " ")) }
        text.addAttribute(.foregroundColor, value: NSColor.black, range: NSRange(location: 0, length: text.length))
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let context = CGContext(output as CFURL, mediaBox: &box, nil) else { throw ConversionError.failed("Не удалось создать PDF.") }
        defer { context.closePDF() }
        let path = CGPath(rect: box.insetBy(dx: 40, dy: 40), transform: nil)
        var offset = 0
        while offset < text.length {
            try Task.checkCancellation()
            context.beginPDFPage(nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), path, nil)
            CTFrameDraw(frame, context)
            context.endPDFPage()
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 else { throw ConversionError.failed("Не удалось разместить текст на странице PDF.") }
            offset += visible.length
        }
    }

    static func xmlEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&apos;")
    }
}
