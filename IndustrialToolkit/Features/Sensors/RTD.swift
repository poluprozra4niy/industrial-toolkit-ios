import Foundation

/// Resistance–temperature characteristics of RTDs per IEC 60751 / ГОСТ 6651-2009.
enum RTDCurve: String, CaseIterable, Identifiable {
    case platinum385
    case platinum391
    case copper428

    var id: String { rawValue }

    var title: String {
        switch self {
        case .platinum385: "Pt"
        case .platinum391: "П"
        case .copper428: "М"
        }
    }

    var alphaTitle: String {
        switch self {
        case .platinum385: "α = 0,00385"
        case .platinum391: "α = 0,00391"
        case .copper428: "α = 0,00428"
        }
    }

    var standard: String {
        switch self {
        case .platinum385: "IEC 60751, ГОСТ 6651"
        case .platinum391: "ГОСТ 6651, платина"
        case .copper428: "ГОСТ 6651, медь"
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .platinum385, .platinum391: -200...850
        case .copper428: -180...200
        }
    }

    private var coefficients: (a: Double, b: Double, c: Double) {
        switch self {
        case .platinum385: (3.9083e-3, -5.775e-7, -4.183e-12)
        case .platinum391: (3.9690e-3, -5.841e-7, -4.330e-12)
        case .copper428: (4.28e-3, -6.2032e-7, 8.5154e-10)
        }
    }

    /// W(t) = R(t) / R0.
    func ratio(at t: Double) -> Double {
        let (a, b, c) = coefficients
        switch self {
        case .platinum385, .platinum391:
            // Callendar–Van Dusen; the C term applies only below 0 °C.
            let base = 1 + a * t + b * t * t
            return t < 0 ? base + c * (t - 100) * t * t * t : base
        case .copper428:
            return t < 0 ? 1 + a * t + b * t * (t + 6.7) + c * t * t * t : 1 + a * t
        }
    }

    /// dW/dt, 1/°C.
    func ratioDerivative(at t: Double) -> Double {
        let (a, b, c) = coefficients
        switch self {
        case .platinum385, .platinum391:
            let base = a + 2 * b * t
            return t < 0 ? base + c * (4 * t * t * t - 300 * t * t) : base
        case .copper428:
            return t < 0 ? a + b * (2 * t + 6.7) + 3 * c * t * t : a
        }
    }
}

struct RTDSensor: Equatable {
    static let nominalOptions: [Double] = [50, 100, 500, 1000]

    let curve: RTDCurve
    let nominal: Double

    /// Pt100, 100П, 50М — the marking used on nameplates.
    var name: String {
        let value = Fmt.number(nominal, fractionDigits: 0)
        return curve == .platinum385 ? "Pt\(value)" : "\(value)\(curve.title)"
    }

    func resistance(at temperature: Double) -> Double? {
        guard curve.range.contains(temperature) else { return nil }
        return nominal * curve.ratio(at: temperature)
    }

    /// Inverse of `resistance(at:)` by bisection — the characteristic is monotonic over the rated range.
    func temperature(for resistance: Double) -> Double? {
        var low = curve.range.lowerBound
        var high = curve.range.upperBound
        guard resistance >= nominal * curve.ratio(at: low), resistance <= nominal * curve.ratio(at: high) else { return nil }
        for _ in 0..<200 where high - low > 1e-10 {
            let middle = (low + high) / 2
            if nominal * curve.ratio(at: middle) < resistance {
                low = middle
            } else {
                high = middle
            }
        }
        return (low + high) / 2
    }

    /// dR/dt, Ω/°C.
    func sensitivity(at temperature: Double) -> Double {
        nominal * curve.ratioDerivative(at: temperature)
    }

    /// W100 = R(100 °C) / R0, the value used to identify the sensor class.
    var w100: Double { curve.ratio(at: 100) }

    /// Reading error of a 2-wire connection: line resistance adds directly to the sensor resistance.
    func twoWireError(lineResistance: Double, at temperature: Double) -> Double? {
        guard lineResistance >= 0, let measured = resistance(at: temperature),
              let shown = self.temperature(for: measured + lineResistance)
        else { return nil }
        return shown - temperature
    }

    func table(step: Double) -> [RTDTableRow] {
        guard step > 0 else { return [] }
        let start = (curve.range.lowerBound / step).rounded(.up) * step
        return stride(from: start, through: curve.range.upperBound, by: step).compactMap { t in
            resistance(at: t).map { RTDTableRow(temperature: t, resistance: $0) }
        }
    }
}

struct RTDTableRow: Identifiable, Equatable {
    let temperature: Double
    let resistance: Double

    var id: Double { temperature }
}
