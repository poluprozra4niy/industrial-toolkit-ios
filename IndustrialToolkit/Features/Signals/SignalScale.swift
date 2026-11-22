import Foundation

enum SignalRange: String, CaseIterable, Identifiable {
    case mA4to20
    case mA0to20
    case v0to10
    case v2to10
    case v0to5
    case v1to5

    var id: String { rawValue }

    var lower: Double {
        switch self {
        case .mA4to20: 4
        case .mA0to20, .v0to10, .v0to5: 0
        case .v2to10: 2
        case .v1to5: 1
        }
    }

    var upper: Double {
        switch self {
        case .mA4to20, .mA0to20: 20
        case .v0to10, .v2to10: 10
        case .v0to5, .v1to5: 5
        }
    }

    var span: Double { upper - lower }

    var unit: String {
        switch self {
        case .mA4to20, .mA0to20: "мА"
        case .v0to10, .v2to10, .v0to5, .v1to5: "В"
        }
    }

    var title: String { "\(Fmt.number(lower, fractionDigits: 0))–\(Fmt.number(upper, fractionDigits: 0)) \(unit)" }

    /// Live zero (4 mA, 2 V, 1 V) lets the receiver tell "0 %" apart from a broken wire.
    var hasLiveZero: Bool { lower > 0 }
}

/// Raw analog-input counts as seen by the PLC program for 0 % … 100 % of the signal.
enum RawCountRange: String, CaseIterable, Identifiable {
    case siemensS7
    case signed15
    case unsigned16
    case adc12
    case decimal10k

    var id: String { rawValue }

    var lower: Double { 0 }

    var upper: Double {
        switch self {
        case .siemensS7: 27_648
        case .signed15: 32_767
        case .unsigned16: 65_535
        case .adc12: 4_095
        case .decimal10k: 10_000
        }
    }

    var span: Double { upper - lower }

    var title: String {
        switch self {
        case .siemensS7: "S7: 0…27648"
        case .signed15: "INT: 0…32767"
        case .unsigned16: "UINT: 0…65535"
        case .adc12: "12 бит: 0…4095"
        case .decimal10k: "0…10000"
        }
    }
}

enum SignalHealth: Equatable {
    case normal
    case underRange
    case overRange
    case failureLow
    case failureHigh

    /// NAMUR NE43 for 4–20 mA; a ±0.5 % span band and a 50 %-of-live-zero wire-break
    /// threshold for the other ranges.
    static func evaluate(_ value: Double, in range: SignalRange) -> SignalHealth {
        if range == .mA4to20 {
            if value <= 3.6 { return .failureLow }
            if value < 3.8 { return .underRange }
            if value >= 21.0 { return .failureHigh }
            if value > 20.5 { return .overRange }
            return .normal
        }
        let tolerance = range.span * 0.005
        if range.hasLiveZero, value < range.lower * 0.5 { return .failureLow }
        if value < range.lower - tolerance { return .underRange }
        if value > range.upper + tolerance { return .overRange }
        return .normal
    }

    var title: String {
        switch self {
        case .normal: "Норма"
        case .underRange: "Ниже диапазона"
        case .overRange: "Выше диапазона"
        case .failureLow: "Отказ: низкий уровень"
        case .failureHigh: "Отказ: высокий уровень"
        }
    }

    func detail(for range: SignalRange) -> String {
        let namur = range == .mA4to20
        switch self {
        case .normal:
            return namur ? "3,8–20,5 мА: достоверное измерение (NAMUR NE43)" : "Сигнал в рабочем диапазоне"
        case .underRange:
            return namur ? "3,6–3,8 мА: насыщение снизу, проверьте датчик" : "Сигнал ниже нижней границы шкалы"
        case .overRange:
            return namur ? "20,5–21 мА: насыщение сверху, проверьте шкалу" : "Сигнал выше верхней границы шкалы"
        case .failureLow:
            return namur
                ? "≤ 3,6 мА: обрыв линии или отказ датчика"
                : "Ниже 50 % живого нуля: вероятен обрыв линии"
        case .failureHigh:
            return "≥ 21 мА: КЗ линии или отказ датчика"
        }
    }
}

struct ScalingResult: Equatable {
    /// Fraction of the electrical signal span (0 … 1 inside range).
    let signalFraction: Double
    /// Fraction of the process-value span; differs from `signalFraction` only with square-root extraction.
    let processFraction: Double
    let signal: Double
    let processValue: Double
    let rawCounts: Double
    let health: SignalHealth
}

/// Linear (or square-root, for ΔP flow transmitters) mapping between an analog signal,
/// the engineering value and PLC raw counts. Everything is routed through the signal fraction.
struct SignalScale: Equatable {
    let signal: SignalRange
    let raw: RawCountRange
    let low: Double
    let high: Double
    let squareRoot: Bool

    init?(signal: SignalRange, raw: RawCountRange, low: Double, high: Double, squareRoot: Bool) {
        guard low.isFinite, high.isFinite, low != high else { return nil }
        self.signal = signal
        self.raw = raw
        self.low = low
        self.high = high
        self.squareRoot = squareRoot
    }

    func convert(signal value: Double) -> ScalingResult {
        convert(signalFraction: (value - signal.lower) / signal.span)
    }

    func convert(rawCounts value: Double) -> ScalingResult {
        convert(signalFraction: (value - raw.lower) / raw.span)
    }

    func convert(processValue value: Double) -> ScalingResult {
        let processFraction = (value - low) / (high - low)
        guard squareRoot else { return convert(signalFraction: processFraction) }
        return convert(signalFraction: processFraction > 0 ? processFraction * processFraction : 0)
    }

    func convert(signalFraction fraction: Double) -> ScalingResult {
        let processFraction = squareRoot ? (fraction > 0 ? fraction.squareRoot() : 0) : fraction
        let signalValue = signal.lower + fraction * signal.span
        return ScalingResult(
            signalFraction: fraction,
            processFraction: processFraction,
            signal: signalValue,
            processValue: low + processFraction * (high - low),
            rawCounts: raw.lower + fraction * raw.span,
            health: SignalHealth.evaluate(signalValue, in: signal)
        )
    }

    static let loopCheckFractions: [Double] = [0, 0.25, 0.5, 0.75, 1]

    var loopCheckTable: [ScalingResult] { Self.loopCheckFractions.map(convert(signalFraction:)) }
}
