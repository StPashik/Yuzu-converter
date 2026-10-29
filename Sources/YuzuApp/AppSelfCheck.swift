import Foundation
import CoreGraphics
import ImageIO
import YuzuCore
import PDFKit

/// Exercises child-process grants inside the signed app using only its own temporary files.
enum AppSelfCheck {
    static func run() async throws {
        print("Sandbox self-check: localization and temporary files")
        for language in AppLanguage.allCases {
            guard L10n.resourceBundle(for: language) != nil else { throw CocoaError(.fileReadNoSuchFile) }
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("yuzu-check-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = ConversionEngine()
        print("Sandbox self-check: bundled media")
        try await MediaSelfCheck.run(in: root)
        print("Sandbox self-check: image metadata")
        // Exercise a real output profile inside the signed Sandbox, including descriptive metadata removal.
        let tagged = root.appendingPathComponent("tagged.tiff")
        guard let pixels = CGContext(data: nil, width: 8, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                                     space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let destination = CGImageDestinationCreateWithURL(tagged as CFURL, "public.tiff" as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        pixels.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        pixels.fill(CGRect(x: 0, y: 0, width: 8, height: 4))
        guard let image = pixels.makeImage() else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyGPSDictionary: [
            kCGImagePropertyGPSLatitude: 51.5, kCGImagePropertyGPSLatitudeRef: "N"
        ]] as CFDictionary)
        guard CGImageDestinationFinalize(destination),
              let taggedSource = CGImageSourceCreateWithURL(tagged as CFURL, nil),
              let taggedProperties = CGImageSourceCopyPropertiesAtIndex(taggedSource, 0, nil) as? [String: Any],
              taggedProperties[kCGImagePropertyGPSDictionary as String] != nil else { throw CocoaError(.fileReadCorruptFile) }
        let original = try Data(contentsOf: tagged)
        let jpeg = try await engine.convert(SourceFile(url: tagged), to: .jpg, in: root,
                                            options: .init(quality: .compact, preserveMetadata: false))[0]
        guard let clean = CGImageSourceCreateWithURL(jpeg as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(clean, 0, nil) as? [String: Any],
              properties[kCGImagePropertyGPSDictionary as String] == nil,
              try Data(contentsOf: tagged) == original else { throw CocoaError(.fileReadCorruptFile) }
        print("Sandbox self-check: image batch and exact-file save")
        let combined = try engine.combineImages([SourceFile(url: tagged), SourceFile(url: jpeg)], in: root)
        guard PDFDocument(url: combined)?.pageCount == 2 else { throw CocoaError(.fileReadCorruptFile) }
        let selected = root.appendingPathComponent("Chosen.png")
        _ = try engine.saveDroppedImage(jpeg, to: .png, destination: selected)
        let selectedBytes = try Data(contentsOf: selected)
        do {
            _ = try engine.saveDroppedImage(jpeg, to: .png, destination: selected)
            throw CocoaError(.fileWriteUnknown)
        } catch let error as POSIXError { guard error.code == .EEXIST else { throw error } }
        guard try Data(contentsOf: selected) == selectedBytes else { throw CocoaError(.fileReadCorruptFile) }
        print("Sandbox self-check: documents")
        let text = root.appendingPathComponent("sample.txt")
        try "Yuzu sandbox check".write(to: text, atomically: true, encoding: .utf8)
        let docx = try await engine.convert(SourceFile(url: text), to: .docx, in: root)[0]
        let restored = try await engine.convert(SourceFile(url: docx), to: .txt, in: root)[0]
        guard try String(contentsOf: restored, encoding: .utf8).contains("Yuzu sandbox check") else {
            throw CocoaError(.fileReadCorruptFile)
        }
        print("Sandbox self-check: spreadsheets")
        let csv = root.appendingPathComponent("values.csv")
        try "name,value\nYuzu,42\n".write(to: csv, atomically: true, encoding: .utf8)
        let xlsx = try await engine.convert(SourceFile(url: csv), to: .xlsx, in: root)[0]
        _ = try await engine.convert(SourceFile(url: xlsx), to: .csv, in: root)
        let tablePDF = try await engine.convert(SourceFile(url: xlsx), to: .pdf, in: root)[0]
        guard PDFDocument(url: tablePDF)?.string?.contains("42") == true else { throw CocoaError(.fileReadCorruptFile) }

        print("Sandbox self-check: archives")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        let zip = root.appendingPathComponent("sample.zip")
        process.arguments = ["-q", zip.path, text.lastPathComponent]
        process.currentDirectoryURL = root
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.executableRuntimeMismatch) }
        let tar = try await engine.convert(SourceFile(url: zip), to: .tar, in: root)[0]
        _ = try await engine.convert(SourceFile(url: tar), to: .zip, in: root)
        _ = try FileOperations.compress([text, csv], in: root, compression: .maximum)
    }
}
