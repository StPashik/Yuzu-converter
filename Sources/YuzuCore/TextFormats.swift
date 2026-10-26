import Foundation

enum TextFile {
    static func read(_ url: URL) throws -> String {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 32 * 1024 * 1024 else { throw ConversionError.unsupported("Текстовый файл больше 32 MiB.") }
        let data = try Data(contentsOf: url)
        let utf16 = (data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF])) ? String(data: data, encoding: .utf16) : nil
        guard var text = String(data: data, encoding: .utf8) ?? utf16 else { throw ConversionError.invalid("Поддерживаются текстовые файлы UTF-8 и UTF-16 с BOM.") }
        if text.first == "\u{FEFF}" { text.removeFirst() }
        return text
    }
}

enum DelimitedText {
    static func parse(_ text: String, separator: Character) throws -> [[String]] {
        var rows: [[String]] = [], row: [String] = []
        var field = "", quoted = false, closed = false
        var iterator = text.makeIterator()
        var next = iterator.next()
        while let character = next {
            next = iterator.next()
            let newline = character == "\n" || character == "\r" || character == "\r\n"
            if quoted {
                if character == "\"" {
                    if next == "\"" { field.append("\""); next = iterator.next() }
                    else { quoted = false; closed = true }
                } else { field.append(character) }
            } else if character == separator || newline {
                row.append(field); field = ""; closed = false
                if newline { rows.append(row); row = [] }
            } else if character == "\"", field.isEmpty && !closed {
                quoted = true
            } else {
                guard !closed, character != "\"" else { throw ConversionError.invalid("Неправильные кавычки в таблице.") }
                field.append(character)
            }
            guard rows.count < 100_000, row.count < 16_384, field.utf8.count < 10_000_000 else {
                throw ConversionError.invalid("Таблица слишком велика.")
            }
        }
        guard !quoted else { throw ConversionError.invalid("Незакрытая кавычка в таблице.") }
        if !field.isEmpty || !row.isEmpty || closed { row.append(field); rows.append(row) }
        return rows
    }

    static func write(_ rows: [[String]], separator: Character) -> String {
        rows.map { row in
            row.map { value in
                value.contains(separator) || value.contains("\"") || value.rangeOfCharacter(from: .newlines) != nil
                    ? "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : value
            }.joined(separator: String(separator))
        }.joined(separator: "\r\n") + "\r\n"
    }
}

enum Subtitles {
    struct Cue: Equatable { let start: Int; let end: Int; let text: String }
    static func parse(_ text: String, format: FileFormat) throws -> [Cue] {
        let normalized = text.replacingOccurrences(of: "\u{FEFF}", with: "").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        var cues: [Cue] = []
        for block in blocks {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            guard let timeIndex = lines.firstIndex(where: { $0.contains("-->") }) else {
                let value = block.trimmingCharacters(in: .whitespacesAndNewlines)
                if value.isEmpty || (format == .vtt && (value.hasPrefix("WEBVTT") || value.hasPrefix("NOTE") || value.hasPrefix("STYLE") || value.hasPrefix("REGION"))) { continue }
                throw ConversionError.invalid("Блок субтитров не содержит таймкоды.")
            }
            let parts = lines[timeIndex].components(separatedBy: "-->")
            guard parts.count == 2 else { throw ConversionError.invalid("Неверный таймкод субтитров.") }
            let start = try timestamp(parts[0].trimmingCharacters(in: .whitespaces))
            let endString = parts[1].trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? ""
            let end = try timestamp(endString)
            var payloadLines = Array(lines.dropFirst(timeIndex + 1))
            while payloadLines.last?.isEmpty == true { payloadLines.removeLast() }
            let payload = payloadLines.joined(separator: "\n")
            guard end >= start, !payload.isEmpty else { throw ConversionError.invalid("Пустой текст или обратный интервал субтитров.") }
            cues.append(Cue(start: start, end: end, text: payload))
        }
        guard !cues.isEmpty else { throw ConversionError.invalid("В файле нет субтитров.") }
        return cues
    }
    private static func timestamp(_ raw: String) throws -> Int {
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        let parts = normalized.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3 else { throw ConversionError.invalid("Неверный таймкод: \(raw)") }
        let seconds = parts.last!.split(separator: ".", omittingEmptySubsequences: false)
        guard seconds.count == 2, seconds[1].count == 3,
              let second = Int(seconds[0]), let milliseconds = Int(seconds[1]),
              let minute = Int(parts[parts.count - 2]), second < 60, minute < 60, second >= 0, minute >= 0,
              let hour = parts.count == 3 ? Int(parts[0]) : 0, hour >= 0, hour < 100_000 else {
            throw ConversionError.invalid("Неверный таймкод: \(raw)")
        }
        return ((hour * 60 + minute) * 60 + second) * 1000 + milliseconds
    }
    static func write(_ cues: [Cue], format: FileFormat) -> String {
        if format == .txt {
            return cues.map { $0.text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">") }.joined(separator: "\n\n") + "\n"
        }
        func stamp(_ value: Int) -> String {
            String(format: "%02d:%02d:%02d%@%03d", value / 3_600_000, value / 60_000 % 60, value / 1000 % 60, format == .srt ? "," : ".", value % 1000)
        }
        return (format == .vtt ? "WEBVTT\n\n" : "") + cues.enumerated().map { index, cue in
            (format == .srt ? "\(index + 1)\n" : "") + stamp(cue.start) + " --> " + stamp(cue.end) + "\n" + cue.text
        }.joined(separator: "\n\n") + "\n"
    }
}
