import Foundation
import Vision
import ImageIO
import PDFKit

/// Local OCR only: Vision receives decoded pixels and never a remote URL.
enum TextRecognition {
    static func image(_ url: URL) async throws -> String {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            throw ConversionError.invalid("The image cannot be decoded for text recognition.")
        }
        var pages: [String] = []
        for index in 0..<CGImageSourceGetCount(source) {
            try Task.checkCancellation()
            // Bound working memory and apply EXIF orientation before recognition, including multipage TIFF.
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 4096
            ] as CFDictionary) else { throw ConversionError.invalid("An image page cannot be decoded for text recognition.") }
            pages.append(try await recognize(image))
        }
        return try joined(pages)
    }

    static func pdf(_ url: URL) async throws -> String {
        guard let document = PDFDocument(url: url), !document.isLocked, document.pageCount > 0 else {
            throw ConversionError.invalid("The PDF is corrupted, empty, or password protected.")
        }
        var pages: [String] = []
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { throw ConversionError.invalid("Could not read a PDF page.") }
            let text = page.string ?? ""
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { pages.append(text); continue }
            let bounds = page.bounds(for: .cropBox)
            guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else {
                throw ConversionError.invalid("The PDF page dimensions are invalid.")
            }
            // A 4096-pixel longest edge bounds scan memory; OCR does not change the original PDF.
            let scale = min(300 / 72, 4096 / max(bounds.width, bounds.height))
            let preview = page.thumbnail(of: NSSize(width: bounds.width * scale, height: bounds.height * scale), for: .cropBox)
            guard let image = preview.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw ConversionError.failed("Could not render the scanned PDF page for text recognition.")
            }
            pages.append(try await recognize(image))
        }
        return try joined(pages)
    }

    private static func joined(_ pages: [String]) throws -> String {
        let text = pages.joined(separator: "\n\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConversionError.invalid("No readable text was found. Try a clearer scan or a higher-resolution image.")
        }
        return text
    }

    private static func recognize(_ image: CGImage) async throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        // These match the app's five languages; the installed OS decides which models are available.
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["en-US", "ru-RU", "de-DE", "fr-FR", "es-ES"].filter { supported.contains($0) }
        let operation = RecognitionRequest(request)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            do { try VNImageRequestHandler(cgImage: image, options: [:]).perform([request]) }
            catch { try Task.checkCancellation(); throw error }
            try Task.checkCancellation()
            // Vision supplies observations in reading order; do not globally sort multi-column text by height.
            return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        } onCancel: { operation.cancel() }
    }
}

/// Vision explicitly allows cancelling a running request; other request mutation stays on the worker task.
private final class RecognitionRequest: @unchecked Sendable {
    let request: VNRequest
    init(_ request: VNRequest) { self.request = request }
    func cancel() { request.cancel() }
}
