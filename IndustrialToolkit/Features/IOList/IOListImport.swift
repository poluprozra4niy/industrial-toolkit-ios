import Foundation

enum IOSignalKind: String, CaseIterable, Identifiable, Codable {
    case ai = "AI"
    case ao = "AO"
    case di = "DI"
    case dout = "DO"

    var id: String { rawValue }

    var isAnalog: Bool { self == .ai || self == .ao }

    var sectionTitle: String {
        switch self {
        case .ai: "Аналоговые входы (AI)"
        case .ao: "Аналоговые выходы (AO)"
        case .di: "Дискретные входы (DI)"
        case .dout: "Дискретные выходы (DO)"
        }
    }

    /// Accepts «AI», «ai», «AI-01», Cyrillic look-alikes («АI», «ДВ»/«ДО» are not guessed).
    static func parse(_ text: String) -> IOSignalKind? {
        let latin = text.uppercased()
            .replacingOccurrences(of: "А", with: "A")
            .replacingOccurrences(of: "О", with: "O")
            .replacingOccurrences(of: "І", with: "I")
            .trimmingCharacters(in: .whitespaces)
        return allCases.first { latin == $0.rawValue || latin.hasPrefix($0.rawValue + " ") || latin.hasPrefix($0.rawValue + "-") }
    }
}

enum IOPointStatus: String, CaseIterable, Codable {
    case pending
    case passed
    case failed

    var reportStatus: ReportStatus {
        switch self {
        case .pending: .pending
        case .passed: .passed
        case .failed: .failed
        }
    }

    var title: String {
        switch self {
        case .pending: "Не проверен"
        case .passed: "Норма"
        case .failed: "Замечание"
        }
    }
}

/// One row of the signal list, independent of storage.
struct IOSignalRecord: Equatable, Codable {
    var tag: String
    var details: String
    var kind: IOSignalKind
    var signal: SignalRange?
    var low: Double?
    var high: Double?
    var unit: String
    var address: String

    var scale: SignalScale? {
        guard kind.isAnalog, let signal, let low, let high else { return nil }
        return SignalScale(signal: signal, raw: .siemensS7, low: low, high: high, squareRoot: false)
    }

    var rangeDescription: String? {
        var parts: [String] = []
        if let signal { parts.append(signal.title) }
        if let low, let high {
            let unitSuffix = unit.isEmpty ? "" : " \(unit)"
            parts.append("\(Fmt.number(low, fractionDigits: 3))…\(Fmt.number(high, fractionDigits: 3))\(unitSuffix)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

enum IORangeParser {
    /// Numbers in «-50…150», «4-20 мА», «0,5 ÷ 2,5»: a minus is a sign only at the start of a
    /// token (not right after a digit), so «4-20» stays two positive numbers.
    static func numbers(in text: String) -> [Double] {
        let characters = Array(text.replacingOccurrences(of: "\u{2212}", with: "-"))
        var result: [Double] = []
        var index = 0
        while index < characters.count {
            let character = characters[index]
            let previousIsDigit = index > 0 && characters[index - 1].isASCIIDigit
            let startsSigned = character == "-" && !previousIsDigit
                && index + 1 < characters.count && characters[index + 1].isASCIIDigit
            guard character.isASCIIDigit || startsSigned else {
                index += 1
                continue
            }
            var token = String(character)
            index += 1
            while index < characters.count {
                let next = characters[index]
                let isDecimalMark = (next == "," || next == ".") && index + 1 < characters.count && characters[index + 1].isASCIIDigit
                guard next.isASCIIDigit || isDecimalMark else { break }
                token.append(next == "," ? "." : next)
                index += 1
            }
            if let value = Double(token) { result.append(value) }
        }
        return result
    }

    /// «4-20 мА», «4…20mA», «0-10 В», «2-10V», «1-5». Without a unit the pair itself decides.
    static func signalRange(_ text: String) -> SignalRange? {
        let lower = text.lowercased()
        let values = numbers(in: lower)
        guard values.count >= 2 else { return nil }
        let pair = (values[0], values[1])
        let saysMilliamps = lower.contains("ма") || lower.contains("ma")
        let saysVolts = !saysMilliamps && (lower.contains("в") || lower.contains("v"))
        let candidates = SignalRange.allCases.filter { $0.lower == pair.0 && $0.upper == pair.1 }
        if saysMilliamps { return candidates.first { $0.unit == "мА" } }
        if saysVolts { return candidates.first { $0.unit == "В" } }
        return candidates.first
    }

    /// «0…10 бар», «-50 - 150 °C» → low, high and the remaining unit text.
    static func scale(_ text: String) -> (low: Double, high: Double, unit: String)? {
        let values = numbers(in: text)
        guard values.count >= 2 else { return nil }
        // The unit follows the last number: «0…100 м³/ч» keeps its superscript.
        let unit = text.lastIndex(where: { $0.isASCII && $0.isNumber })
            .map { String(text[text.index(after: $0)...]) } ?? ""
        return (values[0], values[1], unit.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",;"))))
    }
}

extension SignalRange: Codable {}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}

enum IOListImportError: Error, Equatable {
    case unreadable
    case empty
    case noTagColumn

    var message: String {
        switch self {
        case .unreadable: "Не удалось прочитать файл как текст (поддерживаются UTF-8 и Windows-1251)."
        case .empty: "В файле нет строк с данными."
        case .noTagColumn: "Не найдена колонка с тегами: назовите её «Тег», «Позиция» или «Tag»."
        }
    }
}

enum IOListImporter {
    enum Column: String, CaseIterable {
        case tag
        case details
        case kind
        case signal
        case low
        case high
        case unit
        case address
        case scale

        var title: String {
            switch self {
            case .tag: "Тег"
            case .details: "Описание"
            case .kind: "Тип"
            case .signal: "Сигнал"
            case .low: "НПИ"
            case .high: "ВПИ"
            case .unit: "Ед. изм."
            case .address: "Адрес"
            case .scale: "Шкала"
            }
        }

        /// Word prefixes matched against header words; order of `allCases` resolves overlaps.
        var keywords: [String] {
            switch self {
            case .tag: ["тег", "tag", "поз", "kks", "обознач"]
            case .details: ["опис", "наимен", "descr", "назв", "name"]
            case .kind: ["тип", "type"]
            case .signal: ["сигнал", "signal"]
            case .low: ["нпи", "min", "мин", "low", "нижн", "lrv"]
            case .high: ["впи", "max", "макс", "high", "верх", "urv"]
            case .unit: ["ед", "unit", "eu"]
            case .address: ["адрес", "addr", "канал", "chan"]
            case .scale: ["шкал", "range", "диапазон"]
            }
        }
    }

    struct Outcome: Equatable {
        let records: [IOSignalRecord]
        let columns: [Column]
        let skippedRows: Int
    }

    static let templateCSV = """
    Тег;Описание;Тип;Сигнал;НПИ;ВПИ;Ед. изм.;Адрес
    PT-101;Давление на выходе насоса Н-1;AI;4-20 мА;0;10;бар;%IW64
    TT-102;Температура подшипника;AI;4-20 мА;-50;150;°C;%IW66
    FV-103;Регулирующий клапан;AO;4-20 мА;0;100;%;%QW80
    LS-104;Аварийный уровень;DI;;;;;%I0.0
    M-105;Пуск насоса Н-1;DO;;;;;%Q0.0
    """

    static func headerMap(_ header: [String]) -> [Column: Int] {
        var map: [Column: Int] = [:]
        for (index, title) in header.enumerated() {
            let words = title.lowercased()
                .components(separatedBy: CharacterSet.letters.inverted)
                .filter { !$0.isEmpty }
            guard let column = Column.allCases.first(where: { column in
                map[column] == nil && column.keywords.contains { keyword in words.contains { $0.hasPrefix(keyword) } }
            }) else { continue }
            map[column] = index
        }
        return map
    }

    static func importCSV(_ text: String) -> Result<Outcome, IOListImportError> {
        let rows = CSVParser.parse(text, delimiter: CSVParser.detectDelimiter(in: text))
        guard let header = rows.first, rows.count > 1 else { return .failure(.empty) }
        let map = headerMap(header)
        guard let tagIndex = map[.tag] else { return .failure(.noTagColumn) }

        var records: [IOSignalRecord] = []
        var skipped = 0
        for row in rows.dropFirst() {
            func cell(_ column: Column) -> String {
                guard let index = map[column], index < row.count else { return "" }
                return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let tag = tagIndex < row.count ? row[tagIndex].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            guard !tag.isEmpty else {
                skipped += 1
                continue
            }
            records.append(record(tag: tag, cell: cell))
        }
        guard !records.isEmpty else { return .failure(.empty) }
        let columns = Column.allCases.filter { map[$0] != nil }
        return .success(Outcome(records: records, columns: columns, skippedRows: skipped))
    }

    private static func record(tag: String, cell: (Column) -> String) -> IOSignalRecord {
        var signal = IORangeParser.signalRange(cell(.signal))
        var kind = IOSignalKind.parse(cell(.kind))
        // «Тип сигнала» columns often hold «4-20 мА» instead of AI/DI.
        if kind == nil, let fromKindColumn = IORangeParser.signalRange(cell(.kind)) {
            signal = signal ?? fromKindColumn
            kind = .ai
        }
        var low = NumberParser.parse(cell(.low))
        var high = NumberParser.parse(cell(.high))
        var unit = cell(.unit)
        if low == nil || high == nil, let scale = IORangeParser.scale(cell(.scale)) {
            low = scale.low
            high = scale.high
            if unit.isEmpty { unit = scale.unit }
        }
        let resolvedKind = kind ?? (signal != nil || (low != nil && high != nil) ? .ai : .di)
        return IOSignalRecord(
            tag: tag,
            details: cell(.details),
            kind: resolvedKind,
            signal: resolvedKind.isAnalog ? (signal ?? .mA4to20) : nil,
            low: resolvedKind.isAnalog ? low : nil,
            high: resolvedKind.isAnalog ? high : nil,
            unit: resolvedKind.isAnalog ? unit : "",
            address: cell(.address)
        )
    }
}

/// Snapshot of a checked signal for reports.
struct IOPointSnapshot: Equatable {
    let record: IOSignalRecord
    let status: IOPointStatus
    let remark: String
    let checkedAt: Date?
}

enum IOListReport {
    static func progress(of points: [IOPointSnapshot]) -> ChecklistProgress {
        ChecklistProgress(done: points.filter { $0.status != .pending }.count, total: points.count)
    }

    static func document(name: String, points: [IOPointSnapshot], signers: ReportSigners, issuedAt: Date) -> ReportDocument {
        let sections = IOSignalKind.allCases.compactMap { kind -> ReportSection? in
            let rows = points.filter { $0.record.kind == kind }.map { point -> ReportRow in
                var details: [String] = []
                if let range = point.record.rangeDescription { details.append(range) }
                if !point.record.address.isEmpty { details.append("Адрес: \(point.record.address)") }
                if let checkedAt = point.checkedAt {
                    details.append("Проверено: \(checkedAt.formatted(date: .numeric, time: .shortened))")
                }
                let remark = point.remark.trimmingCharacters(in: .whitespacesAndNewlines)
                if !remark.isEmpty { details.append("Замечание: \(remark)") }
                let text = point.record.details.isEmpty ? point.record.tag : "\(point.record.tag) — \(point.record.details)"
                return ReportRow(status: point.status.reportStatus, text: text, details: details, images: [])
            }
            return rows.isEmpty ? nil : ReportSection(title: kind.sectionTitle, rows: rows)
        }
        let passed = points.filter { $0.status == .passed }.count
        let failed = points.filter { $0.status == .failed }.count
        var header = [
            "Список сигналов: \(name)",
            "Каналов: \(points.count)",
            "Протокол сформирован: \(issuedAt.formatted(date: .numeric, time: .shortened))",
        ]
        if let organization = signers.organizationLine { header.append(organization) }
        return ReportDocument(
            title: "Протокол проверки каналов (loop check)",
            headerLines: header,
            sections: sections,
            summaryLines: [
                "Норма: \(passed)",
                "С замечаниями: \(failed)",
                "Не проверено: \(points.count - passed - failed)",
            ],
            signatures: signers.signatures
        )
    }
}
