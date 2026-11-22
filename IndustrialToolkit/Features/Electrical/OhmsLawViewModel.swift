import Foundation
import Observation

@MainActor
@Observable
final class OhmsLawViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case dc
        case ac

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dc: "Закон Ома"
            case .ac: "Мощность AC"
            }
        }
    }

    var mode: Mode = .dc

    // MARK: DC — Ohm's law

    private(set) var pair: OhmPair = .voltageCurrent
    private var texts: [OhmQuantity: String] = [.voltage: "24", .current: "0,5", .resistance: "48", .power: "12"]
    private var units: [OhmQuantity: EngineeringUnit] = Dictionary(
        uniqueKeysWithValues: OhmQuantity.allCases.map { ($0, $0.defaultUnit) }
    )

    func text(for quantity: OhmQuantity) -> String { texts[quantity] ?? "" }

    func setText(_ text: String, for quantity: OhmQuantity) { texts[quantity] = text }

    func unit(for quantity: OhmQuantity) -> EngineeringUnit { units[quantity] ?? quantity.defaultUnit }

    func setUnit(_ unit: EngineeringUnit, for quantity: OhmQuantity) { units[quantity] = unit }

    func isInvalid(_ quantity: OhmQuantity) -> Bool {
        !text(for: quantity).allSatisfy(\.isWhitespace) && value(of: quantity) == nil
    }

    var solution: OhmsLawSolution? {
        let (first, second) = pair.quantities
        guard let a = value(of: first), let b = value(of: second) else { return nil }
        return OhmsLaw.solve(pair, first: a, second: b)
    }

    /// Writes the current solution into the newly known fields so switching the pair keeps the operating point.
    func selectPair(_ newPair: OhmPair) {
        guard newPair != pair else { return }
        if let solution {
            for quantity in [newPair.quantities.first, newPair.quantities.second] where !pair.contains(quantity) {
                let scaled = solution.value(of: quantity) / unit(for: quantity).factor
                texts[quantity] = Fmt.number(scaled, fractionDigits: 4)
            }
        }
        pair = newPair
    }

    private func value(of quantity: OhmQuantity) -> Double? {
        guard let parsed = NumberParser.parse(text(for: quantity)), parsed > 0 else { return nil }
        return parsed * unit(for: quantity).factor
    }

    // MARK: AC — power triangle

    private(set) var system: PowerSystem = .threePhase
    var acInput: ACPowerInput = .voltageCurrent
    var voltageText = "400"
    var currentText = "10"
    var powerFactorText = "0,85"
    var activeKWText = "5,5"
    var reactiveKvarText = "3"
    var targetPowerFactorText = "0,95"

    func selectSystem(_ newSystem: PowerSystem) {
        guard newSystem != system, newSystem.isAC else { return }
        system = newSystem
        voltageText = Fmt.number(newSystem.defaultVoltage, fractionDigits: 0)
    }

    private var voltage: Double? { positive(voltageText) }
    private var current: Double? { positive(currentText) }
    private var powerFactor: Double? { Self.powerFactor(powerFactorText) }
    private var activePower: Double? { positive(activeKWText).map { $0 * 1000 } }

    private var reactivePower: Double? {
        guard let value = NumberParser.parse(reactiveKvarText), value >= 0 else { return nil }
        return value * 1000
    }

    var targetPowerFactor: Double? { Self.powerFactor(targetPowerFactorText) }

    var isVoltageInvalid: Bool { voltage == nil }
    var isCurrentInvalid: Bool { current == nil }
    var isPowerFactorInvalid: Bool { powerFactor == nil }
    var isActiveInvalid: Bool { activePower == nil }
    var isReactiveInvalid: Bool { reactivePower == nil }
    var isTargetInvalid: Bool { !targetPowerFactorText.allSatisfy(\.isWhitespace) && targetPowerFactor == nil }

    var acResult: ACPowerResult? {
        guard let voltage else { return nil }
        switch acInput {
        case .voltageCurrent:
            guard let current, let powerFactor else { return nil }
            return ACPower.fromVoltageCurrent(system: system, voltage: voltage, current: current, powerFactor: powerFactor)
        case .activePower:
            guard let activePower, let powerFactor else { return nil }
            return ACPower.fromActivePower(system: system, activePower: activePower, voltage: voltage, powerFactor: powerFactor)
        case .activeReactive:
            guard let activePower, let reactivePower else { return nil }
            return ACPower.fromActiveReactive(system: system, activePower: activePower, reactivePower: reactivePower, voltage: voltage)
        }
    }

    /// Capacitor bank size in вар to reach the target cos φ.
    var compensation: Double? {
        guard let acResult, let targetPowerFactor else { return nil }
        return ACPower.compensation(activePower: acResult.active, from: acResult.powerFactor, to: targetPowerFactor)
    }

    private func positive(_ text: String) -> Double? {
        guard let value = NumberParser.parse(text), value > 0 else { return nil }
        return value
    }

    private static func powerFactor(_ text: String) -> Double? {
        guard let value = NumberParser.parse(text), value > 0, value <= 1 else { return nil }
        return value
    }

    // MARK: Export

    var noteTitle: String {
        switch mode {
        case .dc: "Закон Ома: \(pair.title)"
        case .ac: "Мощность \(system.title) \(voltageText) В"
        }
    }

    var summary: String? {
        switch mode {
        case .dc: dcSummary
        case .ac: acSummary
        }
    }

    private var dcSummary: String? {
        guard let solution else { return nil }
        let lines = OhmQuantity.allCases.map { quantity in
            let reading = EngineeringNotation.format(solution.value(of: quantity), unit: quantity.baseUnit)
            let marker = pair.contains(quantity) ? " (дано)" : ""
            return "\(quantity.symbol) = \(reading.value) \(reading.unit)\(marker)"
        }
        return (["Закон Ома, известно \(pair.title)"] + lines + pair.formulas).joined(separator: "\n")
    }

    private var acSummary: String? {
        guard let result = acResult else { return nil }
        var lines = [
            "Мощность \(system.title) (\(system.subtitle.lowercased())), U = \(voltageText) В",
            "S = \(Self.reading(result.apparent, "В·А"))",
            "P = \(Self.reading(result.active, "Вт"))",
            "Q = \(Self.reading(result.reactive, "вар"))",
            "I = \(Fmt.number(result.current, fractionDigits: 2)) А",
            "cos φ = \(Fmt.fixed(result.powerFactor, fractionDigits: 3)), φ = \(Fmt.number(result.phiDegrees, fractionDigits: 1))°",
        ]
        if let compensation, let targetPowerFactor {
            lines.append("КРМ до cos φ = \(Fmt.number(targetPowerFactor, fractionDigits: 3)): \(Self.reading(compensation, "вар"))")
        }
        return lines.joined(separator: "\n")
    }

    static func reading(_ value: Double, _ unit: String) -> String {
        let formatted = EngineeringNotation.format(value, unit: unit)
        return "\(formatted.value) \(formatted.unit)"
    }
}
