import Foundation

enum UnitCategory: String, CaseIterable, Identifiable {
    case pressure
    case temperature
    case flow
    case power

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pressure: "Давление"
        case .temperature: "Температура"
        case .flow: "Расход"
        case .power: "Мощность"
        }
    }

    var units: [MeasurementUnit] {
        switch self {
        case .pressure: MeasurementUnit.pressure
        case .temperature: MeasurementUnit.temperature
        case .flow: MeasurementUnit.flow
        case .power: MeasurementUnit.power
        }
    }

    var defaultUnit: MeasurementUnit { units[0] }
}

/// Linear unit: base = value · factor + offset. Flow units are split into volume and mass,
/// bridged by density.
struct MeasurementUnit: Identifiable, Hashable {
    enum Dimension {
        case pressure
        case temperature
        case volumeFlow
        case massFlow
        case power
    }

    let id: String
    let symbol: String
    let dimension: Dimension
    let factor: Double
    var offset: Double = 0

    func toBase(_ value: Double) -> Double { value * factor + offset }

    func fromBase(_ base: Double) -> Double { (base - offset) / factor }

    /// Standard gravity 9.80665 m/s² (ГОСТ 8.417-2002) defines the technical units below.
    static let pressure: [MeasurementUnit] = [
        MeasurementUnit(id: "bar", symbol: "бар", dimension: .pressure, factor: 1e5),
        MeasurementUnit(id: "mbar", symbol: "мбар", dimension: .pressure, factor: 100),
        MeasurementUnit(id: "Pa", symbol: "Па", dimension: .pressure, factor: 1),
        MeasurementUnit(id: "kPa", symbol: "кПа", dimension: .pressure, factor: 1e3),
        MeasurementUnit(id: "MPa", symbol: "МПа", dimension: .pressure, factor: 1e6),
        MeasurementUnit(id: "kgfcm2", symbol: "кгс/см²", dimension: .pressure, factor: 98_066.5),
        MeasurementUnit(id: "atm", symbol: "атм", dimension: .pressure, factor: 101_325),
        MeasurementUnit(id: "mmH2O", symbol: "мм вод. ст.", dimension: .pressure, factor: 9.806_65),
        MeasurementUnit(id: "mH2O", symbol: "м вод. ст.", dimension: .pressure, factor: 9_806.65),
        MeasurementUnit(id: "mmHg", symbol: "мм рт. ст.", dimension: .pressure, factor: 133.322_387_415),
        MeasurementUnit(id: "psi", symbol: "psi", dimension: .pressure, factor: 6_894.757_293_168),
    ]

    static let temperature: [MeasurementUnit] = [
        MeasurementUnit(id: "C", symbol: "°C", dimension: .temperature, factor: 1),
        MeasurementUnit(id: "K", symbol: "K", dimension: .temperature, factor: 1, offset: -273.15),
        MeasurementUnit(id: "F", symbol: "°F", dimension: .temperature, factor: 5.0 / 9.0, offset: -32.0 * 5.0 / 9.0),
    ]

    static let flow: [MeasurementUnit] = [
        MeasurementUnit(id: "m3h", symbol: "м³/ч", dimension: .volumeFlow, factor: 1.0 / 3_600),
        MeasurementUnit(id: "m3d", symbol: "м³/сут", dimension: .volumeFlow, factor: 1.0 / 86_400),
        MeasurementUnit(id: "m3s", symbol: "м³/с", dimension: .volumeFlow, factor: 1),
        MeasurementUnit(id: "ls", symbol: "л/с", dimension: .volumeFlow, factor: 1e-3),
        MeasurementUnit(id: "lmin", symbol: "л/мин", dimension: .volumeFlow, factor: 1e-3 / 60),
        MeasurementUnit(id: "th", symbol: "т/ч", dimension: .massFlow, factor: 1_000.0 / 3_600),
        MeasurementUnit(id: "kgh", symbol: "кг/ч", dimension: .massFlow, factor: 1.0 / 3_600),
        MeasurementUnit(id: "kgs", symbol: "кг/с", dimension: .massFlow, factor: 1),
    ]

    static let power: [MeasurementUnit] = [
        MeasurementUnit(id: "kW", symbol: "кВт", dimension: .power, factor: 1e3),
        MeasurementUnit(id: "W", symbol: "Вт", dimension: .power, factor: 1),
        MeasurementUnit(id: "MW", symbol: "МВт", dimension: .power, factor: 1e6),
        MeasurementUnit(id: "hpMetric", symbol: "л.с.", dimension: .power, factor: 735.498_75),
        MeasurementUnit(id: "hp", symbol: "hp", dimension: .power, factor: 745.699_871_582_27),
        MeasurementUnit(id: "kcalh", symbol: "ккал/ч", dimension: .power, factor: 1.163),
        MeasurementUnit(id: "Gcalh", symbol: "Гкал/ч", dimension: .power, factor: 1.163e6),
    ]
}

enum UnitConverter {
    static let absoluteZeroCelsius = -273.15

    /// Converts `value` from one unit to another; volume ↔ mass flow needs density in kg/m³.
    static func convert(_ value: Double, from source: MeasurementUnit, to target: MeasurementUnit, density: Double? = nil) -> Double? {
        guard value.isFinite else { return nil }
        let base = source.toBase(value)
        if source.dimension == .temperature && base < absoluteZeroCelsius - 1e-9 { return nil }
        switch (source.dimension, target.dimension) {
        case (.volumeFlow, .massFlow):
            guard let density, density > 0 else { return nil }
            return target.fromBase(base * density)
        case (.massFlow, .volumeFlow):
            guard let density, density > 0 else { return nil }
            return target.fromBase(base / density)
        default:
            guard source.dimension == target.dimension else { return nil }
            return target.fromBase(base)
        }
    }

    /// Up to 6 significant digits; scientific notation outside 1e-4…1e9.
    static func format(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let magnitude = abs(value)
        if magnitude != 0 && (magnitude < 1e-4 || magnitude >= 1e9) {
            return value.formatted(.number.notation(.scientific).precision(.significantDigits(1...6)))
        }
        return value.formatted(.number.precision(.significantDigits(1...6)).grouping(.never))
    }
}
