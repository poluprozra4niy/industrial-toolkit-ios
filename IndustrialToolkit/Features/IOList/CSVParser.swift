import Foundation

/// RFC 4180-style CSV reader for exports from Excel, LibreOffice and SCADA tools.
enum CSVParser {
    /// UTF-8 (with or without BOM) first, UTF-16 only with a BOM; otherwise Windows-1251,
    /// which Russian Excel uses for «CSV (разделители — запятые)».
    static func decodeText(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) {
            return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        }
        let bom = Array(data.prefix(2))
        if bom == [0xFF, 0xFE] || bom == [0xFE, 0xFF], let text = String(data: data, encoding: .utf16) {
            return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        }
        return String(data: data, encoding: .windowsCP1251)
    }

    /// The delimiter that occurs most often outside quotes in the first line; «;» on ties
    /// because comma doubles as the decimal separator in Russian locales.
    static func detectDelimiter(in text: String) -> Character {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        var counts: [Character: Int] = [";": 0, ",": 0, "\t": 0]
        var inQuotes = false
        for character in firstLine {
            if character == "\"" {
                inQuotes.toggle()
            } else if !inQuotes, counts[character] != nil {
                counts[character, default: 0] += 1
            }
        }
        let best = counts.max { lhs, rhs in
            lhs.value == rhs.value ? lhs.key != ";" && rhs.key == ";" : lhs.value < rhs.value
        }
        guard let best, best.value > 0 else { return ";" }
        return best.key
    }

    /// Splits into rows of fields; quoted fields may contain delimiters, newlines and "" escapes.
    /// Fully empty rows are dropped.
    static func parse(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = Array(text).makeIterator()
        var pending = iterator.next()
        while let character = pending {
            pending = iterator.next()
            if inQuotes {
                if character == "\"" {
                    if pending == "\"" {
                        field.append("\"")
                        pending = iterator.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
                continue
            }
            switch character {
            case "\"" where field.isEmpty:
                inQuotes = true
            case delimiter:
                row.append(field)
                field = ""
            case "\r\n", "\n", "\r":
                row.append(field)
                field = ""
                if row.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                    rows.append(row)
                }
                row = []
            default:
                field.append(character)
            }
        }
        row.append(field)
        if row.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            rows.append(row)
        }
        return rows
    }
}
