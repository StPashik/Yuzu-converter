import AppKit
import CoreText
import PDFKit
import ImageIO

/// System image, PDF, and attributed-text converters. Callers own staging and publication.
/// Text/PDF exports preserve readable content rather than reconstructing the source application's layout.
enum NativeDocuments {
    /// Writes all readable image frames to PDF/TIFF; other raster outputs use the first frame.
    /// PDF creation applies EXIF orientation at full pixel resolution before choosing its page bounds.
    static func image(_ source: URL, to target: FileFormat, output: URL, options: ConversionOptions = .init()) throws {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil), CGImageSourceGetCount(imageSource) > 0 else {
            if let image = NSImage(contentsOf: source), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                try writeImage(cgImage, to: target, output: output, options: options)
                return
            }
            throw ConversionError.invalid("Could not decode the image.")
        }
        let count = CGImageSourceGetCount(imageSource)
        if target == .pdf {
            guard let context = CGContext(output as CFURL, mediaBox: nil, nil) else { throw ConversionError.failed("Could not create the PDF.") }
            defer { context.closePDF() }
            for index in 0..<count {
                try Task.checkCancellation()
                let image = try orientedImage(imageSource, at: index)
                var bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
                let box = NSData(bytes: &bounds, length: MemoryLayout<CGRect>.size)
                context.beginPDFPage([kCGPDFContextMediaBox as String: box] as CFDictionary)
                context.draw(image, in: bounds)
                context.endPDFPage()
            }
            return
        }
        guard let identifier = target.imageType else { throw ConversionError.unsupported("No ImageIO writer is available for \(target.label).") }
        let frames = target == .tiff ? count : 1
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, identifier as CFString, frames, nil) else { throw ConversionError.failed("ImageIO cannot write \(target.label).") }
        for index in 0..<frames {
            try Task.checkCancellation()
            if options.preserveMetadata {
                CGImageDestinationAddImageFromSource(destination, imageSource, index,
                                                    [kCGImageDestinationLossyCompressionQuality: options.quality.imageQuality] as CFDictionary)
            } else {
                // Re-encode pixels, not source properties: drop EXIF/GPS/IPTC while retaining color and displayed orientation.
                let image = try orientedImage(imageSource, at: index)
                CGImageDestinationAddImage(destination, image,
                                           [kCGImageDestinationLossyCompressionQuality: options.quality.imageQuality] as CFDictionary)
            }
        }
        guard CGImageDestinationFinalize(destination) else { throw ConversionError.failed("Could not write the image.") }
    }

    /// Encodes one decoded image. Raster DPI is metadata; the supplied pixel dimensions are not resampled here.
    static func writeImage(_ image: CGImage, to target: FileFormat, output: URL, dpi: Double = 72,
                           options: ConversionOptions = .init()) throws {
        if target == .pdf {
            var box = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            guard let context = CGContext(output as CFURL, mediaBox: &box, nil) else { throw ConversionError.failed("Could not create the PDF.") }
            context.beginPDFPage(nil); context.draw(image, in: box); context.endPDFPage(); context.closePDF()
            return
        }
        guard let identifier = target.imageType,
              let destination = CGImageDestinationCreateWithURL(output as CFURL, identifier as CFString, 1, nil) else { throw ConversionError.unsupported("No writer is available for \(target.label).") }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: options.quality.imageQuality, kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ConversionError.failed("Could not finish writing the image.") }
    }

    /// Renders every PDF page at 300 DPI into a new staging folder and returns its ordered file URLs.
    /// Page size/rotation controls pixel dimensions. Oversized pages fail instead of silently reducing DPI;
    /// the caller discards the whole staging folder if a later page fails or cancellation is requested.
    static func pdfPages(_ source: URL, to target: FileFormat, directory: URL,
                         options: ConversionOptions = .init()) throws -> [URL] {
        guard let document = CGPDFDocument(source as CFURL), !document.isEncrypted || document.isUnlocked, document.numberOfPages > 0 else {
            throw ConversionError.invalid("The PDF is corrupted, empty, or password protected.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        var outputs: [URL] = []
        for index in 1...document.numberOfPages {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { throw ConversionError.invalid("Could not read page \(index).") }
            // Match the visible page in Preview; MediaBox may include a much larger printing canvas.
            let bounds = page.getBoxRect(.cropBox).intersection(page.getBoxRect(.mediaBox))
            let rotated = abs(page.rotationAngle) % 180 != 0
            let widthPoints = rotated ? bounds.height : bounds.width
            let heightPoints = rotated ? bounds.width : bounds.height
            let width = ceil(widthPoints * 300 / 72), height = ceil(heightPoints * 300 / 72)
            // Reject oversized pages instead of silently lowering the promised 300 DPI.
            guard width.isFinite, height.isFinite, width > 0, height > 0, width <= 32768, height <= 32768, width * height <= 64_000_000 else {
                throw ConversionError.unsupported("Page \(index) is too large to render safely at 300 DPI.")
            }
            guard let space = CGColorSpace(name: CGColorSpace.sRGB), let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw ConversionError.failed("Not enough memory for page \(index).")
            }
            let rect = CGRect(x: 0, y: 0, width: width, height: height)
            context.setFillColor(CGColor.white); context.fill(rect)
            // getDrawingTransform only scales down: establish 300-DPI units before placing the page in points.
            let scale: CGFloat = 300 / 72
            context.scaleBy(x: scale, y: scale)
            let pageRect = CGRect(x: 0, y: 0, width: width / scale, height: height / scale)
            context.concatenate(page.getDrawingTransform(.cropBox, rect: pageRect, rotate: 0, preserveAspectRatio: true))
            context.drawPDFPage(page)
            guard let image = context.makeImage() else { throw ConversionError.failed("Could not render page \(index).") }
            let output = directory.appendingPathComponent(String(format: "Page %03d.%@", index, target.fileExtension))
            try writeImage(image, to: target, output: output, dpi: 300, options: options)
            outputs.append(output)
        }
        return outputs
    }

    private static func orientedImage(_ source: CGImageSource, at index: Int) throws -> CGImage {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight as String] as? NSNumber else {
            throw ConversionError.invalid("Could not read the image dimensions.")
        }
        // Applying the transform at full resolution also works for formats that cannot store EXIF orientation.
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceThumbnailMaxPixelSize: max(width.intValue, height.intValue)] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, options) else {
            throw ConversionError.invalid("The image page is corrupted.")
        }
        return image
    }

    /// Reads text/basic formatting, parses Markdown, or extracts an existing PDF text layer without OCR.
    /// Rich documents pass through system textutil; this is content conversion, not a full layout-preserving import.
    static func readText(_ source: SourceFile, scratch: URL) throws -> NSAttributedString {
        if source.format == .txt || source.format == .md {
            let text = try TextFile.read(source.url)
            if source.format == .md { return NSAttributedString(try AttributedString(markdown: text)) }
            return NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 12)])
        }
        if source.format == .pdf {
            // Export the existing text layer; scanned pages require an OCR engine.
            guard let pdf = PDFDocument(url: source.url), !pdf.isLocked, let text = pdf.string else { throw ConversionError.invalid("The PDF has no accessible text layer.") }
            return NSAttributedString(string: text)
        }
        let output = scratch.appendingPathComponent("read.rtf")
        // HTML must not fetch external resources while a local document is being converted.
        _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/textutil"), ["-noload", "-convert", "rtf", "-output", output.path, "-format", source.format.rawValue, source.url.path])
        guard let attributed = NSAttributedString(rtf: try Data(contentsOf: output), documentAttributes: nil) else { throw ConversionError.invalid("Could not read the document.") }
        return attributed
    }

    /// Writes supported attributed-text formats. TXT/MD exports contain plain text; they do not recover markup.
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
        default: throw ConversionError.unsupported("No writer is available for \(target.label).")
        }
        let data = try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: type])
        try data.write(to: output)
    }

    /// Flows attributed text onto A4 pages with CoreText; original document pagination is not reproduced.
    /// Each page must advance the visible range, preventing an infinite loop on unplaceable content.
    static func writePDF(_ text: NSAttributedString, output: URL) throws {
        let text = NSMutableAttributedString(attributedString: text)
        if text.length == 0 { text.append(NSAttributedString(string: " ")) }
        text.addAttribute(.foregroundColor, value: NSColor.black, range: NSRange(location: 0, length: text.length))
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let context = CGContext(output as CFURL, mediaBox: &box, nil) else { throw ConversionError.failed("Could not create the PDF.") }
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
            guard visible.length > 0 else { throw ConversionError.failed("Could not fit the text on a PDF page.") }
            offset += visible.length
        }
    }

    static func xmlEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&apos;")
    }
}
