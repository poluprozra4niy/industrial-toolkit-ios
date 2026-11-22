import Foundation

/// Type K (ТХА) thermocouple from the NIST ITS-90 inverse functions T(E), E in mV, T in °C.
/// The reference function E(T) is obtained by inverting T(E) numerically, so both directions share
/// the stated approximation error of the inverse polynomials (−0,05…+0,06 °C).
enum ThermocoupleTypeK {
    static let source = "NIST ITS-90 (its90.nist.gov), обратные функции, тип K"
    static let maximumError = "−0,05…+0,06 °C"

    private struct Segment {
        let emfRange: ClosedRange<Double>
        let coefficients: [Double]
    }

    private static let segments: [Segment] = [
        Segment(emfRange: -5.891...0, coefficients: [
            0.0000000E+00, 2.5173462E+01, -1.1662878E+00, -1.0833638E+00, -8.9773540E-01,
            -3.7342377E-01, -8.6632643E-02, -1.0450598E-02, -5.1920577E-04, 0.0000000E+00,
        ]),
        Segment(emfRange: 0...20.644, coefficients: [
            0.000000E+00, 2.508355E+01, 7.860106E-02, -2.503131E-01, 8.315270E-02,
            -1.228034E-02, 9.804036E-04, -4.413030E-05, 1.057734E-06, -1.052755E-08,
        ]),
        Segment(emfRange: 20.644...54.886, coefficients: [
            -1.318058E+02, 4.830222E+01, -1.646031E+00, 5.464731E-02, -9.650715E-04,
            8.802193E-06, -3.110810E-08, 0.000000E+00, 0.000000E+00, 0.000000E+00,
        ]),
    ]

    static let emfRange: ClosedRange<Double> = -5.891...54.886
    static let temperatureRange: ClosedRange<Double> = -200...1372

    /// Temperature for an emf referenced to a 0 °C cold junction.
    static func temperature(millivolts emf: Double) -> Double? {
        guard emfRange.contains(emf), let segment = segments.first(where: { $0.emfRange.contains(emf) }) else { return nil }
        // Horner evaluation of Σ dᵢ·Eⁱ.
        return segment.coefficients.reversed().reduce(0) { $0 * emf + $1 }
    }

    /// Emf (0 °C reference) for a temperature, by bisection of the monotonic inverse function.
    static func millivolts(temperature: Double) -> Double? {
        guard temperatureRange.contains(temperature) else { return nil }
        var low = emfRange.lowerBound
        var high = emfRange.upperBound
        for _ in 0..<100 where high - low > 1e-9 {
            let middle = (low + high) / 2
            guard let value = self.temperature(millivolts: middle) else { return nil }
            if value < temperature {
                low = middle
            } else {
                high = middle
            }
        }
        return (low + high) / 2
    }

    /// Seebeck coefficient dE/dT, µV/°C, by central difference.
    static func sensitivity(temperature: Double) -> Double? {
        let step = 0.5
        let lower = max(temperature - step, temperatureRange.lowerBound)
        let upper = min(temperature + step, temperatureRange.upperBound)
        guard upper > lower,
              let emfLow = millivolts(temperature: lower),
              let emfHigh = millivolts(temperature: upper)
        else { return nil }
        return (emfHigh - emfLow) / (upper - lower) * 1000
    }

    /// Hot-junction temperature from the emf a meter reads with its terminals at `coldJunction` °C.
    static func temperature(measuredMillivolts: Double, coldJunction: Double) -> Double? {
        guard let coldEmf = millivolts(temperature: coldJunction) else { return nil }
        return temperature(millivolts: measuredMillivolts + coldEmf)
    }

    /// Emf a meter reads for a hot junction at `temperature` with its terminals at `coldJunction` °C.
    static func measuredMillivolts(temperature: Double, coldJunction: Double) -> Double? {
        guard let hot = millivolts(temperature: temperature), let cold = millivolts(temperature: coldJunction) else { return nil }
        return hot - cold
    }
}
