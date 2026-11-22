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
    case sensorTables
    case pidTuning
    case ipRating
    case networkCalc
    case commissioningChecklist
    case notebook

    var id: String { rawValue }

    var category: ToolCategory {
        switch self {
        case .cableSizing, .voltageDrop, .ohmsLaw, .wireColors, .breakers: .electrical
        case .signalScaling, .ieee754, .modbusRegisters, .sensorTables: .automation
        case .pidTuning, .ipRating, .networkCalc: .design
        case .commissioningChecklist, .notebook: .field
        }
    }

    /// Must match the implemented branches in `ToolDestination`.
    var isAvailable: Bool {
        switch self {
        case .voltageDrop, .ohmsLaw, .signalScaling, .ieee754, .modbusRegisters, .commissioningChecklist, .notebook: true
        default: false
        }
    }

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
        case .sensorTables: "Термопары и ТС"
        case .pidTuning: "Настройка ПИД"
        case .ipRating: "Степень защиты IP"
        case .networkCalc: "IP-калькулятор сетей"
        case .commissioningChecklist: "Чек-лист ПНР"
        case .notebook: "Блокнот инженера"
        }
    }

    var subtitle: String {
        switch self {
        case .cableSizing: "По длительно допустимому току, Cu / Al"
        case .voltageDrop: "ΔU по длине, току и сечению"
        case .ohmsLaw: "U, I, R, P; P, Q, S, cos φ; КРМ"
        case .wireColors: "Цвета жил, PE / N / L"
        case .breakers: "Номиналы и времятоковые кривые"
        case .signalScaling: "4–20 мА, 0–10 В ↔ величина ↔ код АЦП"
        case .ieee754: "Float ↔ HEX ↔ регистры, порядок байт"
        case .modbusRegisters: "INT16…FLOAT64, порядок слов, адресация 4xxxx"
        case .sensorTables: "ТХА, ТХК, Pt100, Pt1000"
        case .pidTuning: "Метод Циглера–Николса"
        case .ipRating: "Расшифровка IPxx"
        case .networkCalc: "Маски, подсети, Profinet / Modbus TCP"
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
        case .sensorTables: "thermometer.medium"
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
        case .sensorTables: ["pt100", "pt1000", "термопар", "температур"]
        case .cableSizing: ["кабель", "медь", "алюмин"]
        case .voltageDrop: ["кабель", "медь", "алюмин", "потери", "линия", "du", "24 в"]
        case .networkCalc: ["маска", "ethernet", "profinet", "tcp"]
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
