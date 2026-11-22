import Foundation

enum ToolCategory: String, CaseIterable, Identifiable, Hashable {
    case electrical
    case automation
    case design
    case field

    var id: String { rawValue }

    var title: String {
        switch self {
        case .electrical: "Электрика и кабели"
        case .automation: "АСУ ТП и сигналы"
        case .design: "Проектирование и настройка"
        case .field: "Чек-листы и заметки"
        }
    }

    var subtitle: String {
        switch self {
        case .electrical: "Сечение, ΔU, мощность, автоматы"
        case .automation: "4–20 мА, IEEE 754, Modbus, датчики"
        case .design: "ПИД, IP-коды, подсети"
        case .field: "ПНР, loop check, блокнот"
        }
    }

    var symbol: String {
        switch self {
        case .electrical: "bolt.fill"
        case .automation: "waveform.path.ecg"
        case .design: "slider.horizontal.3"
        case .field: "checklist"
        }
    }

    var tools: [Tool] { Tool.allCases.filter { $0.category == self } }
}

enum Tool: String, CaseIterable, Identifiable, Hashable {
    case cableSizing
    case voltageDrop
    case ohmsLaw
    case wireColors
    case breakers
    case signalScaling
    case ieee754
    case modbusRegisters
    case rtd
    case thermocouples
    case pidTuning
    case ipRating
    case networkCalc
    case commissioningChecklist
    case notebook

    var id: String { rawValue }

    var category: ToolCategory {
        switch self {
        case .cableSizing, .voltageDrop, .ohmsLaw, .wireColors, .breakers: .electrical
        case .signalScaling, .ieee754, .modbusRegisters, .rtd, .thermocouples: .automation
        case .pidTuning, .ipRating, .networkCalc: .design
        case .commissioningChecklist, .notebook: .field
        }
    }

    /// Tools used daily on site, shown on the dashboard without opening a category.
    static let quickAccess: [Tool] = [.signalScaling, .modbusRegisters, .cableSizing, .voltageDrop, .commissioningChecklist, .notebook]

    var title: String {
        switch self {
        case .cableSizing: "Сечение кабеля"
        case .voltageDrop: "Падение напряжения"
        case .ohmsLaw: "Закон Ома и мощность"
        case .wireColors: "Маркировка проводов"
        case .breakers: "Автоматы B / C / D"
        case .signalScaling: "Конвертер сигналов"
        case .ieee754: "IEEE 754 / Float"
        case .modbusRegisters: "Регистры Modbus"
        case .rtd: "Термосопротивления"
        case .thermocouples: "Термопары"
        case .pidTuning: "Настройка ПИД"
        case .ipRating: "Степень защиты IP"
        case .networkCalc: "IP-калькулятор сетей"
        case .commissioningChecklist: "Чек-лист ПНР"
        case .notebook: "Блокнот инженера"
        }
    }

    var subtitle: String {
        switch self {
        case .cableSizing: "По допустимому току, ПУЭ табл. 1.3.4–1.3.7"
        case .voltageDrop: "ΔU по длине, току и сечению"
        case .ohmsLaw: "U, I, R, P; P, Q, S, cos φ; КРМ"
        case .wireColors: "PE, N, PEN, L1–L3, DC — цвета и обозначения"
        case .breakers: "Кратности расцепления, петля фаза–ноль"
        case .signalScaling: "4–20 мА, 0–10 В ↔ величина ↔ код АЦП"
        case .ieee754: "Float ↔ HEX ↔ регистры, порядок байт"
        case .modbusRegisters: "INT16…FLOAT64, порядок слов, адресация 4xxxx"
        case .rtd: "Pt100, Pt1000, 100П, 50М: R ↔ t, таблицы"
        case .thermocouples: "ТХА (K): мВ ↔ °C, холодный спай"
        case .pidTuning: "Циглер–Николс, Коэн–Кун, SIMC, Тайреус–Люйбен"
        case .ipRating: "Расшифровка IPxx, ГОСТ 14254-2015"
        case .networkCalc: "Подсети, проверка ПЛК ↔ панель, порты протоколов"
        case .commissioningChecklist: "Loop check, DI/AI, изоляция"
        case .notebook: "Результаты и заметки, экспорт"
        }
    }

    var symbol: String {
        switch self {
        case .cableSizing: "cable.connector"
        case .voltageDrop: "chart.line.downtrend.xyaxis"
        case .ohmsLaw: "function"
        case .wireColors: "paintpalette"
        case .breakers: "switch.2"
        case .signalScaling: "gauge.with.dots.needle.50percent"
        case .ieee754: "memorychip"
        case .modbusRegisters: "square.grid.3x2"
        case .rtd: "thermometer.medium"
        case .thermocouples: "flame"
        case .pidTuning: "point.topleft.down.to.point.bottomright.curvepath"
        case .ipRating: "shield.lefthalf.filled"
        case .networkCalc: "network"
        case .commissioningChecklist: "checklist"
        case .notebook: "note.text"
        }
    }

    private var keywords: [String] {
        switch self {
        case .signalScaling: ["4-20", "ма", "ацп", "шкала", "namur", "аналог", "s7", "27648"]
        case .ieee754: ["float", "hex", "modbus", "плк", "плавающ", "abcd", "cdab", "endian"]
        case .modbusRegisters: ["int", "word", "dword", "endian", "40001", "holding", "адрес", "uint64", "double"]
        case .rtd: ["pt100", "pt1000", "100п", "50м", "термосопротивлен", "температур", "тс"]
        case .thermocouples: ["термопар", "тха", "тхк", "мв", "температур"]
        case .cableSizing: ["кабель", "медь", "алюмин", "пуэ", "сечени", "допустим", "провод"]
        case .wireColors: ["цвет", "pe", "pen", "нейтрал", "фаз", "маркировк", "желто"]
        case .breakers: ["автомат", "кривая", "петля", "кз", "расцеплен", "c16", "b10"]
        case .ipRating: ["ip", "оболочк", "пыл", "влаг", "ip65", "ip67"]
        case .voltageDrop: ["кабель", "медь", "алюмин", "потери", "линия", "du", "24 в"]
        case .networkCalc: ["маска", "ethernet", "profinet", "tcp", "подсет", "ip", "шлюз", "порт", "502", "cidr"]
        case .pidTuning: ["пид", "pid", "регулятор", "циглер", "kp", "ti", "td", "разгон", "xp"]
        case .ohmsLaw: ["ом", "мощност", "cos", "квар", "крм", "реактив", "напряжен"]
        case .commissioningChecklist: ["пнр", "loop", "изоляц", "мегаомметр", "di", "do", "протокол"]
        default: []
        }
    }

    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return true }
        return ([title, subtitle] + keywords).contains { $0.localizedCaseInsensitiveContains(needle) }
    }
}

enum Route: Hashable {
    case category(ToolCategory)
    case tool(Tool)
}
