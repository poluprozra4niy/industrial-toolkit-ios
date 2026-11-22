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
        case .electrical: "Сечение, ΔU, мощность, автоматы, двигатели"
        case .automation: "4–20 мА, контур, Modbus, датчики, единицы"
        case .design: "ПИД, IP-коды, подсети"
        case .field: "ПНР, I/O list, PDF-протоколы, блокнот"
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
    case motor
    case signalScaling
    case loopBudget
    case ieee754
    case modbusRegisters
    case modbusAddresses
    case modbusResponse
    case rtd
    case thermocouples
    case unitConverter
    case pidTuning
    case ipRating
    case networkCalc
    case commissioningChecklist
    case ioList
    case notebook

    var id: String { rawValue }

    var category: ToolCategory {
        switch self {
        case .cableSizing, .voltageDrop, .ohmsLaw, .wireColors, .breakers, .motor: .electrical
        case .signalScaling, .loopBudget, .ieee754, .modbusRegisters, .modbusAddresses, .modbusResponse, .rtd, .thermocouples, .unitConverter: .automation
        case .pidTuning, .ipRating, .networkCalc: .design
        case .commissioningChecklist, .ioList, .notebook: .field
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
        case .motor: "Двигатель и частотник"
        case .signalScaling: "Конвертер сигналов"
        case .loopBudget: "Нагрузка контура 4–20 мА"
        case .ieee754: "IEEE 754 / Float"
        case .modbusRegisters: "Регистры Modbus"
        case .modbusAddresses: "Адреса Modbus"
        case .modbusResponse: "Разбор кадра Modbus"
        case .rtd: "Термосопротивления"
        case .thermocouples: "Термопары"
        case .unitConverter: "Конвертер единиц"
        case .pidTuning: "Настройка ПИД"
        case .ipRating: "Степень защиты IP"
        case .networkCalc: "IP-калькулятор сетей"
        case .commissioningChecklist: "Чек-лист ПНР"
        case .ioList: "Список сигналов (I/O)"
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
        case .motor: "Iн, пусковой ток, автомат, обороты от частоты"
        case .signalScaling: "4–20 мА, 0–10 В ↔ величина ↔ код АЦП"
        case .loopBudget: "Хватит ли питания: БП, линия, барьер, HART"
        case .ieee754: "Float ↔ HEX ↔ регистры, порядок байт"
        case .modbusRegisters: "INT16…FLOAT64, порядок слов, адресация 4xxxx"
        case .modbusAddresses: "4xxxx ↔ DEC ↔ HEX ↔ %MW, кадр RTU/TCP с CRC"
        case .modbusResponse: "HEX-кадр RTU/TCP → CRC, коды ошибок, значения"
        case .rtd: "Pt100, Pt1000, 100П, 50М: R ↔ t, таблицы"
        case .thermocouples: "ТХА (K): мВ ↔ °C, холодный спай"
        case .unitConverter: "Давление, температура, расход, мощность"
        case .pidTuning: "Циглер–Николс, Коэн–Кун, SIMC, Тайреус–Люйбен"
        case .ipRating: "Расшифровка IPxx, ГОСТ 14254-2015"
        case .networkCalc: "Подсети, проверка ПЛК ↔ панель, порты протоколов"
        case .commissioningChecklist: "Loop check, DI/AI, изоляция, фото, PDF"
        case .ioList: "Импорт CSV, loop check по тегам, PDF-протокол"
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
        case .motor: "fanblades"
        case .signalScaling: "gauge.with.dots.needle.50percent"
        case .loopBudget: "powerplug"
        case .ieee754: "memorychip"
        case .modbusRegisters: "square.grid.3x2"
        case .modbusAddresses: "number.square"
        case .modbusResponse: "text.magnifyingglass"
        case .rtd: "thermometer.medium"
        case .thermocouples: "flame"
        case .unitConverter: "arrow.left.arrow.right"
        case .pidTuning: "point.topleft.down.to.point.bottomright.curvepath"
        case .ipRating: "shield.lefthalf.filled"
        case .networkCalc: "network"
        case .commissioningChecklist: "checklist"
        case .ioList: "list.bullet.rectangle"
        case .notebook: "note.text"
        }
    }

    private var keywords: [String] {
        switch self {
        case .signalScaling: ["4-20", "ма", "ацп", "шкала", "namur", "аналог", "s7", "27648"]
        case .ieee754: ["float", "hex", "modbus", "плк", "плавающ", "abcd", "cdab", "endian"]
        case .modbusRegisters: ["int", "word", "dword", "endian", "40001", "holding", "адрес", "uint64", "double"]
        case .modbusAddresses: ["40001", "hex", "адрес", "смещен", "offset", "%mw", "crc", "rtu", "tcp", "coil", "holding", "регистр"]
        case .modbusResponse: ["ответ", "кадр", "crc", "ошибк", "exception", "rtu", "tcp", "сниффер", "hex", "лог"]
        case .rtd: ["pt100", "pt1000", "100п", "50м", "термосопротивлен", "температур", "тс"]
        case .thermocouples: ["термопар", "тха", "тхк", "мв", "температур"]
        case .cableSizing: ["кабель", "медь", "алюмин", "пуэ", "сечени", "допустим", "провод"]
        case .wireColors: ["цвет", "pe", "pen", "нейтрал", "фаз", "маркировк", "желто"]
        case .breakers: ["автомат", "кривая", "петля", "кз", "расцеплен", "c16", "b10"]
        case .ipRating: ["ip", "оболочк", "пыл", "влаг", "ip65", "ip67"]
        case .voltageDrop: ["кабель", "медь", "алюмин", "потери", "линия", "du", "24 в"]
        case .networkCalc: ["маска", "ethernet", "profinet", "tcp", "подсет", "ip", "шлюз", "порт", "502", "cidr"]
        case .pidTuning: ["пид", "pid", "регулятор", "циглер", "kp", "ti", "td", "разгон", "xp", "ступеньк", "секундомер"]
        case .ohmsLaw: ["ом", "мощност", "cos", "квар", "крм", "реактив", "напряжен"]
        case .motor: ["двигател", "мотор", "чрп", "частотник", "пусков", "обороты", "квт", "насос"]
        case .loopBudget: ["контур", "питани", "барьер", "hart", "нагрузк", "шунт", "250", "24 в"]
        case .unitConverter: ["бар", "мпа", "кгс", "psi", "расход", "м3", "единиц", "давлен", "квт", "л.с."]
        case .ioList: ["i/o", "io list", "сигнал", "тег", "csv", "excel", "спецификац", "loop", "перечень"]
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
