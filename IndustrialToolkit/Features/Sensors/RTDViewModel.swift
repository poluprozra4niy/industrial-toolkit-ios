import Foundation
import Observation

@MainActor
@Observable
final class RTDViewModel {
    enum Direction: String, CaseIterable, Identifiable {
        case toResistance
        case toTemperature

        var id: String { rawValue }

        var title: String {
            switch self {
            case .toResistance: "t → R"
            case .toTemperature: "R → t"
            }
        }
    }

    struct Reading: Equatable {
        let temperature: Double
        let resistance: Double
    }

    var curve: RTDCurve = .platinum385
    var nominal: Double = 100
    private(set) var direction: Direction = .toResistance
    var temperatureText = "100"
    var resistanceText = "138,51"
    var lineResistanceText = "2"

    var sensor: RTDSensor { RTDSensor(curve: curve, nominal: nominal) }

    private var inputTemperature: Double? { NumberParser.parse(temperatureText) }

    private var inputResistance: Double? {
        guard let value = NumberParser.parse(resistanceText), value > 0 else { return nil }
        return value
    }

    var reading: Reading? {
        let sensor = sensor
        switch direction {
        case .toResistance:
            guard let temperature = inputTemperature, let resistance = sensor.resistance(at: temperature) else { return nil }
            return Reading(temperature: temperature, resistance: resistance)
        case .toTemperature:
            guard let resistance = inputResistance, let temperature = sensor.temperature(for: resistance) else { return nil }
            return Reading(temperature: temperature, resistance: resistance)
        }
    }

    private var activeText: String { direction == .toResistance ? temperatureText : resistanceText }

    var isInputInvalid: Bool { !activeText.allSatisfy(\.isWhitespace) && reading == nil }

    var inputError: String? {
        guard isInputInvalid else { return nil }
        let range = curve.range
        let lower = Fmt.number(range.lowerBound, fractionDigits: 0)
        let upper = Fmt.number(range.upperBound, fractionDigits: 0)
        switch direction {
        case .toResistance:
            return inputTemperature == nil ? "Введите температуру числом" : "Диапазон \(sensor.name): \(lower)…\(upper) °C"
        case .toTemperature:
            let low = sensor.resistance(at: range.lowerBound) ?? 0
            let high = sensor.resistance(at: range.upperBound) ?? 0
            return "Диапазон \(sensor.name): \(Fmt.fixed(low, fractionDigits: 2))…\(Fmt.fixed(high, fractionDigits: 2)) Ом"
        }
    }

    /// Carries the reading over so switching t → R / R → t keeps the same point.
    func selectDirection(_ newDirection: Direction) {
        guard newDirection != direction else { return }
        if let reading {
            switch newDirection {
            case .toResistance: temperatureText = Fmt.number(reading.temperature, fractionDigits: 2)
            case .toTemperature: resistanceText = Fmt.number(reading.resistance, fractionDigits: 3)
            }
        }
        direction = newDirection
    }

    var lineResistance: Double? {
        guard let value = NumberParser.parse(lineResistanceText), value >= 0 else { return nil }
        return value
    }

    var isLineResistanceInvalid: Bool { lineResistance == nil }

    var twoWireError: Double? {
        guard let reading, let lineResistance else { return nil }
        return sensor.twoWireError(lineResistance: lineResistance, at: reading.temperature)
    }

    var noteTitle: String { "ТС \(sensor.name): \(activeText)" }

    var summary: String? {
        guard let reading else { return nil }
        var lines = [
            "Термосопротивление \(sensor.name) (\(curve.alphaTitle), \(curve.standard))",
            "t = \(Fmt.fixed(reading.temperature, fractionDigits: 2)) °C",
            "R = \(Fmt.fixed(reading.resistance, fractionDigits: 3)) Ом",
            "Чувствительность: \(Fmt.fixed(sensor.sensitivity(at: reading.temperature), fractionDigits: 4)) Ом/°C",
        ]
        if let twoWireError, let lineResistance, lineResistance > 0 {
            lines.append("2-проводная схема, Rлинии = \(lineResistanceText) Ом: погрешность +\(Fmt.fixed(twoWireError, fractionDigits: 2)) °C")
        }
        return lines.joined(separator: "\n")
    }
}
