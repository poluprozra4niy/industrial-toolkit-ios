import Foundation

/// IP code per ГОСТ 14254-2015 (IEC 60529:2013).
struct IPDigitInfo: Identifiable, Equatable {
    let code: String
    let title: String
    let detail: String

    var id: String { code }
}

enum IPRating {
    static let source = "ГОСТ 14254-2015 (IEC 60529:2013)"

    /// First numeral: access to hazardous parts + solid foreign objects (табл. 1 и 2).
    static let solids: [IPDigitInfo] = [
        IPDigitInfo(code: "0", title: "Нет защиты", detail: "Защита не нормируется"),
        IPDigitInfo(code: "1", title: "Тыльная сторона руки; предметы ≥ 50 мм", detail: "Сфера Ø 50 мм не проходит полностью и не касается опасных частей"),
        IPDigitInfo(code: "2", title: "Палец; предметы ≥ 12,5 мм", detail: "Шарнирный палец Ø 12 мм, длина 80 мм; сфера Ø 12,5 мм не проходит полностью"),
        IPDigitInfo(code: "3", title: "Инструмент; предметы ≥ 2,5 мм", detail: "Щуп Ø 2,5 мм не проникает в оболочку"),
        IPDigitInfo(code: "4", title: "Проволока; предметы ≥ 1,0 мм", detail: "Щуп Ø 1,0 мм не проникает в оболочку"),
        IPDigitInfo(code: "5", title: "Пылезащищено", detail: "Пыль может проникать, но не в количестве, нарушающем работу и безопасность; доступ — проволока Ø 1,0 мм"),
        IPDigitInfo(code: "6", title: "Пыленепроницаемо", detail: "Пыль не проникает; доступ — проволока Ø 1,0 мм"),
    ]

    /// Second numeral: water (табл. 3, условия испытаний — раздел 14).
    static let water: [IPDigitInfo] = [
        IPDigitInfo(code: "0", title: "Нет защиты", detail: "Защита не нормируется"),
        IPDigitInfo(code: "1", title: "Вертикально падающие капли", detail: "Капельное устройство, оболочка на поворотном столе, 10 мин"),
        IPDigitInfo(code: "2", title: "Капли при наклоне до 15°", detail: "Четыре положения с наклоном 15°, по 2,5 мин"),
        IPDigitInfo(code: "3", title: "Дождевание", detail: "Брызги под углом до 60° от вертикали; дождевальная трубка или разбрызгиватель 10 л/мин"),
        IPDigitInfo(code: "4", title: "Сплошное обрызгивание", detail: "Брызги с любого направления"),
        IPDigitInfo(code: "5", title: "Струи воды", detail: "Сопло Ø 6,3 мм, 12,5 л/мин, 2,5–3 м, 1 мин/м², не менее 3 мин"),
        IPDigitInfo(code: "6", title: "Сильные струи воды", detail: "Сопло Ø 12,5 мм, 100 л/мин, 2,5–3 м, 1 мин/м², не менее 3 мин"),
        IPDigitInfo(code: "7", title: "Временное погружение", detail: "Погружение до 1 м (нижняя точка ≤ 1 м, верхняя ≥ 0,15 м под водой), 30 мин"),
        IPDigitInfo(code: "8", title: "Длительное погружение", detail: "Условия согласуют изготовитель и потребитель; жёстче, чем для 7"),
        IPDigitInfo(code: "9", title: "Горячие струи под высоким давлением", detail: "Добавлено в IEC 60529:2013; параметры испытаний — по IEC 60529"),
    ]

    /// Additional letters (табл. 4): protection of persons when higher than the first numeral states.
    static let additionalLetters: [IPDigitInfo] = [
        IPDigitInfo(code: "A", title: "Тыльная сторона руки", detail: "Сфера Ø 50 мм, усилие 50 Н"),
        IPDigitInfo(code: "B", title: "Палец", detail: "Шарнирный палец Ø 12 мм × 80 мм, усилие 10 Н"),
        IPDigitInfo(code: "C", title: "Инструмент", detail: "Щуп Ø 2,5 мм × 100 мм, усилие 3 Н"),
        IPDigitInfo(code: "D", title: "Проволока", detail: "Щуп Ø 1,0 мм × 100 мм, усилие 1 Н"),
    ]

    /// Supplementary letters (раздел 8).
    static let supplementaryLetters: [IPDigitInfo] = [
        IPDigitInfo(code: "H", title: "Высоковольтная аппаратура", detail: ""),
        IPDigitInfo(code: "M", title: "Испытано на воду с движущимися частями в работе", detail: ""),
        IPDigitInfo(code: "S", title: "Испытано на воду с неподвижными движущимися частями", detail: ""),
    ]

    static let commonCodes = ["IP20", "IP31", "IP44", "IP54", "IP65", "IP66", "IP67", "IP68", "IPX9", "IP66/IP67"]

    struct Code: Equatable {
        /// nil means "X" — characteristic not required.
        let first: Int?
        let second: Int?
        let additional: Character?
        let supplementary: [Character]
    }

    private enum Numeral {
        case digit(Int)
        case omitted

        var value: Int? {
            switch self {
            case .digit(let digit): digit
            case .omitted: nil
            }
        }
    }

    /// Parses "IP65", "IPX7", "IP2XC", "IP54M"; dual marking "IPX6/IPX7" yields two codes.
    static func parse(_ text: String) -> [Code]? {
        let parts = text.uppercased().filter { !$0.isWhitespace }.split(separator: "/", omittingEmptySubsequences: false)
        let codes = parts.compactMap { parseSingle(String($0)) }
        guard !codes.isEmpty, codes.count == parts.count else { return nil }
        return codes
    }

    private static func parseSingle(_ text: String) -> Code? {
        guard text.hasPrefix("IP") else { return nil }
        let body = Array(text.dropFirst(2))
        guard body.count >= 2,
              let first = numeral(body[0], max: 6),
              let second = numeral(body[1], max: 9)
        else { return nil }
        var rest = body.dropFirst(2)
        var additional: Character?
        if let letter = rest.first, "ABCD".contains(letter) {
            additional = letter
            rest = rest.dropFirst()
        }
        let supplementary = Array(rest)
        guard supplementary.allSatisfy({ "HMS".contains($0) }), Set(supplementary).count == supplementary.count else { return nil }
        return Code(first: first.value, second: second.value, additional: additional, supplementary: supplementary)
    }

    private static func numeral(_ character: Character, max: Int) -> Numeral? {
        if character == "X" { return .omitted }
        guard let digit = character.wholeNumberValue, (0...max).contains(digit) else { return nil }
        return .digit(digit)
    }

    /// Notes from ГОСТ 14254-2015 раздел 6 on immersion-only and jet ratings.
    static func waterNotes(for codes: [Code]) -> [String] {
        let seconds = Set(codes.compactMap(\.second))
        let hasJets = !seconds.isDisjoint(with: [5, 6, 9])
        let hasImmersion = !seconds.isDisjoint(with: [7, 8])
        var notes: [String] = []
        if hasImmersion && !hasJets {
            notes.append("Только 7 или 8 — защита при погружении, но не от струй (5, 6, 9). Для мойки струёй нужна двойная маркировка, например IPX6/IPX7.")
        }
        if seconds.contains(9) && seconds.isDisjoint(with: [5, 6, 7, 8]) {
            notes.append("IPX9 не подразумевает защиту 5–8: её указывают отдельно (IPX6/IPX9, IPX6/IPX7/IPX9).")
        }
        if hasJets && hasImmersion {
            notes.append("Двойная маркировка: оболочка выдерживает и струи, и погружение.")
        }
        return notes
    }

    static func solid(_ numeral: Int?) -> IPDigitInfo? {
        numeral.flatMap { value in solids.first { $0.code == String(value) } }
    }

    static func waterInfo(_ numeral: Int?) -> IPDigitInfo? {
        numeral.flatMap { value in water.first { $0.code == String(value) } }
    }

    static func letter(_ character: Character?, in list: [IPDigitInfo]) -> IPDigitInfo? {
        character.flatMap { value in list.first { $0.code == String(value) } }
    }
}
