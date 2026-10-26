import AppKit

enum EPUB {
    static func read(_ source: URL, scratch: URL) throws -> NSAttributedString {
        let root = scratch.appendingPathComponent("epub", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        _ = try ArchiveReader(source).entries(extractingTo: root)
        let container = try XMLTree.read(root.appendingPathComponent("META-INF/container.xml"))
        guard let path = container.descendants("rootfile").first?.attributes["full-path"], !path.hasPrefix("/"), !path.contains(".."), !path.contains(":") else { throw ConversionError.invalid("В EPUB нет корректного package document.") }
        let packageURL = root.appendingPathComponent(path)
        let package = try XMLTree.read(packageURL)
        let result = NSMutableAttributedString(string: "")
        for item in package.descendants("itemref") {
            try Task.checkCancellation()
            guard let entry = package.descendants("item").first(where: { $0.attributes["id"] == item.attributes["idref"] }),
                  let href = entry.attributes["href"]?.removingPercentEncoding, !href.contains(":"), !href.hasPrefix("/") else { throw ConversionError.invalid("Неверный spine EPUB.") }
            let file = packageURL.deletingLastPathComponent().appendingPathComponent(href).standardizedFileURL
            guard file.path.hasPrefix(root.path + "/") else { throw ConversionError.invalid("Путь главы EPUB выходит за пакет.") }
            let rtf = scratch.appendingPathComponent("epub-read.rtf")
            _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/textutil"), ["-noload", "-convert", "rtf", "-format", "html", "-output", rtf.path, file.path])
            guard let chapter = NSAttributedString(rtf: try Data(contentsOf: rtf), documentAttributes: nil) else { throw ConversionError.invalid("Нечитаемая глава EPUB.") }
            result.append(chapter); result.append(NSAttributedString(string: "\n"))
        }
        guard result.length > 0 else { throw ConversionError.invalid("EPUB не содержит глав.") }
        return result
    }

    static func write(_ text: NSAttributedString, title: String, output: URL, scratch: URL) throws {
        let root = scratch.appendingPathComponent("new-epub", isDirectory: true)
        let meta = root.appendingPathComponent("META-INF", isDirectory: true)
        let content = root.appendingPathComponent("OEBPS", isDirectory: true)
        try FileManager.default.createDirectory(at: meta, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: content, withIntermediateDirectories: false)
        func put(_ value: String, _ path: String) throws { try value.write(to: root.appendingPathComponent(path), atomically: false, encoding: .utf8) }
        let title = NativeDocuments.xmlEscape(title)
        let identifier = UUID().uuidString
        try put("application/epub+zip", "mimetype")
        try put("<?xml version=\"1.0\"?><container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"><rootfiles><rootfile full-path=\"OEBPS/content.opf\" media-type=\"application/oebps-package+xml\"/></rootfiles></container>", "META-INF/container.xml")
        let paragraphs = text.string.components(separatedBy: "\n").map { "<p>\(NativeDocuments.xmlEscape($0))</p>" }.joined(separator: "\n")
        try put("<?xml version=\"1.0\" encoding=\"UTF-8\"?><html xmlns=\"http://www.w3.org/1999/xhtml\"><head><title>\(title)</title></head><body>\(paragraphs)</body></html>", "OEBPS/chapter.xhtml")
        try put("<?xml version=\"1.0\"?><ncx xmlns=\"http://www.daisy.org/z3986/2005/ncx/\" version=\"2005-1\"><head><meta name=\"dtb:uid\" content=\"urn:uuid:\(identifier)\"/></head><docTitle><text>\(title)</text></docTitle><navMap><navPoint id=\"chapter\" playOrder=\"1\"><navLabel><text>\(title)</text></navLabel><content src=\"chapter.xhtml\"/></navPoint></navMap></ncx>", "OEBPS/toc.ncx")
        try put("<?xml version=\"1.0\" encoding=\"UTF-8\"?><package xmlns=\"http://www.idpf.org/2007/opf\" version=\"2.0\" unique-identifier=\"book-id\"><metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:identifier id=\"book-id\">urn:uuid:\(identifier)</dc:identifier><dc:title>\(title)</dc:title><dc:language>und</dc:language></metadata><manifest><item id=\"chapter\" href=\"chapter.xhtml\" media-type=\"application/xhtml+xml\"/><item id=\"ncx\" href=\"toc.ncx\" media-type=\"application/x-dtbncx+xml\"/></manifest><spine toc=\"ncx\"><itemref idref=\"chapter\"/></spine></package>", "OEBPS/content.opf")
        _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/zip"), ["-q", "-0", output.path, "mimetype"], directory: root)
        _ = try ProcessRunner.checked(URL(fileURLWithPath: "/usr/bin/zip"), ["-q", "-r", output.path, "META-INF", "OEBPS"], directory: root)
    }
}
