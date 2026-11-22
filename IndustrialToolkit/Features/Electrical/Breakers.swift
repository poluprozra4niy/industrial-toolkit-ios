import Foundation

/// Circuit-breaker characteristics per ГОСТ IEC 60898-1-2020 (IEC 60898-1:2019).
enum BreakerCurve: String, CaseIterable, Identifiable {
    case b
    case c
    case d

    var id: String { rawValue }

    var title: String { rawValue.uppercased() }

    /// Instantaneous tripping range, multiples of In: above `lower` up to and including `upper` (табл. 2).
    var lowerMultiple: Double {
        switch self {
        case .b: 3
        case .c: 5
        case .d: 10
        }
    }

    var upperMultiple: Double {
        switch self {
        case .b: 5
        case .c: 10
        case .d: 20
        }
    }

    /// Typical application; the standard itself leaves the choice to installation rules (4.6, прим.).
    var typicalUse: String {
        switch self {
        case .b: "Активная нагрузка, длинные линии с малым током КЗ"
        case .c: "Общего назначения: освещение, розетки, смешанная нагрузка"
        case .d: "Большие пусковые токи: двигатели, трансформаторы"
        }
    }
}

enum InstantaneousTripVerdict: Equatable {
    /// Fault current at or above the upper limit: every breaker of this type trips without delay.
    case guaranteed
    /// Inside the band: depends on the individual breaker.
    case uncertain
    /// At or below the lower limit: thermal release only, trip may take seconds to hours.
    case thermalOnly
}

struct BreakerSelection: Equatable {
    static let preferredRatings: [Double] = [6, 8, 10, 13, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125]
    static let referenceTemperature = 30.0
    static let source = "ГОСТ IEC 60898-1-2020"

    let curve: BreakerCurve
    let rating: Double

    var name: String { "\(curve.title)\(Fmt.number(rating, fractionDigits: 0))" }

    var instantaneousLower: Double { curve.lowerMultiple * rating }
    var instantaneousUpper: Double { curve.upperMultiple * rating }

    /// 1,13·In — must not trip within the conventional time.
    var nonTrippingCurrent: Double { 1.13 * rating }
    /// 1,45·In — must trip within the conventional time.
    var trippingCurrent: Double { 1.45 * rating }
    /// 2,55·In from cold — must trip after 1 s and before the upper limit.
    var thermalTestCurrent: Double { 2.55 * rating }

    /// Conventional time for 1,13·In / 1,45·In: 1 h up to 63 A, 2 h above.
    var conventionalTime: String { rating <= 63 ? "1 ч" : "2 ч" }

    /// Upper time limit for 2,55·In: 60 s up to 32 A, 120 s above.
    var thermalTestWindow: String { rating <= 32 ? "1 с < t < 60 с" : "1 с < t < 120 с" }

    func verdict(faultCurrent: Double) -> InstantaneousTripVerdict {
        if faultCurrent >= instantaneousUpper { return .guaranteed }
        if faultCurrent > instantaneousLower { return .uncertain }
        return .thermalOnly
    }

    /// Largest loop impedance Zs = U0 / (k_upper·In) that still guarantees instantaneous tripping.
    func maximumLoopImpedance(phaseVoltage: Double) -> Double? {
        guard phaseVoltage > 0 else { return nil }
        return phaseVoltage / instantaneousUpper
    }

    static func faultCurrent(phaseVoltage: Double, loopImpedance: Double) -> Double? {
        guard phaseVoltage > 0, loopImpedance > 0 else { return nil }
        return phaseVoltage / loopImpedance
    }
}
