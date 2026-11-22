import Foundation
import Observation

@MainActor
@Observable
final class VoltageDropViewModel {
    enum LoadInput: String, CaseIterable, Identifiable {
        case current
        case power

        var id: String { rawValue }

        var title: String {
            switch self {
            case .current: "Ток, А"
            case .power: "Мощность, кВт"
            }
        }
    }

    struct SectionRow: Identifiable {
        let section: Double
        let drop: Double
        let dropPercent: Double
        let isWithinLimit: Bool

        var id: Double { section }
    }

    private(set) var system: PowerSystem = .threePhase
    var material: ConductorMaterial = .copper
    var temperature: ConductorTemperature = .pvc
    var voltageText = "400"
    var loadInput: LoadInput = .current
    var loadText = "32"
    var powerFactorText = "0,9"
    var lengthText = "80"
    var section: Double = 10
    var reactanceText = "0,08"
    var allowedText = "5"

    // MARK: Parsed inputs

    private var voltage: Double? { positive(voltageText) }
    private var load: Double? { positive(loadText) }
    private var length: Double? { positive(lengthText) }

    private var powerFactor: Double? {
        guard system.isAC else { return 1 }
        guard let value = NumberParser.parse(powerFactorText), value > 0, value <= 1 else { return nil }
        return value
    }

    private var reactancePerKm: Double? {
        guard system.isAC else { return 0 }
        guard let value = NumberParser.parse(reactanceText), value >= 0 else { return nil }
        return value
    }

    private var allowedPercent: Double? {
        guard let value = NumberParser.parse(allowedText), value > 0, value < 100 else { return nil }
        return value
    }

    var isVoltageInvalid: Bool { voltage == nil }
    var isLoadInvalid: Bool { load == nil }
    var isPowerFactorInvalid: Bool { powerFactor == nil }
    var isLengthInvalid: Bool { length == nil }
    var isReactanceInvalid: Bool { reactancePerKm == nil }
    var isAllowedInvalid: Bool { allowedPercent == nil }

    var validationMessage: String? {
        if isVoltageInvalid || isLoadInvalid || isLengthInvalid { return "Напряжение, нагрузка и длина должны быть больше нуля" }
        if isPowerFactorInvalid { return "cos φ должен быть в диапазоне 0…1" }
        if isReactanceInvalid { return "Сопротивление x не может быть отрицательным" }
        if isAllowedInvalid { return "Допустимое ΔU: от 0 до 100 %" }
        return nil
    }

    // MARK: Results

    var calculation: VoltageDropCalculation? {
        guard let voltage, let powerFactor, let length, let reactancePerKm, let allowedPercent else { return nil }
        return VoltageDropCalculation(
            system: system,
            material: material,
            conductorTemperature: temperature.rawValue,
            voltage: voltage,
            powerFactor: powerFactor,
            length: length,
            section: section,
            reactancePerKm: reactancePerKm,
            allowedDropPercent: allowedPercent
        )
    }

    var current: Double? {
        guard let load, let calculation else { return nil }
        switch loadInput {
        case .current:
            return load
        case .power:
            return system.current(fromPower: load * 1000, voltage: calculation.voltage, powerFactor: calculation.powerFactor)
        }
    }

    var result: VoltageDropResult? {
        guard let calculation, let current else { return nil }
        return calculation.result(current: current)
    }

    var sectionRows: [SectionRow] {
        guard let calculation, let current else { return [] }
        return CableSections.standard.map { section in
            let percent = calculation.dropPercent(current: current, section: section)
            return SectionRow(
                section: section,
                drop: calculation.drop(current: current, section: section),
                dropPercent: percent,
                isWithinLimit: percent <= calculation.allowedDropPercent
            )
        }
    }

    // MARK: Intents

    func selectSystem(_ newSystem: PowerSystem) {
        guard newSystem != system else { return }
        system = newSystem
        voltageText = Fmt.number(newSystem.defaultVoltage, fractionDigits: 0)
    }

    /// Carries the load over in the other unit so switching I ↔ P keeps the same operating point.
    func selectLoadInput(_ input: LoadInput) {
        guard input != loadInput else { return }
        if let current, let calculation {
            switch input {
            case .current:
                loadText = Fmt.number(current, fractionDigits: 2)
            case .power:
                let watts = current * calculation.voltage * calculation.powerFactor
                    * (system == .threePhase ? 3.squareRoot() : 1)
                loadText = Fmt.number(watts / 1000, fractionDigits: 3)
            }
        }
        loadInput = input
    }

    // MARK: Export

    var noteTitle: String {
        "ΔU: \(system.title) \(voltageText) В, \(CableSections.title(section)) мм², \(lengthText) м"
    }

    var summary: String? {
        guard let calculation, let result else { return nil }
        var lines = [
            "Падение напряжения",
            "Сеть: \(system.title) (\(system.subtitle.lowercased())), U = \(Fmt.number(calculation.voltage, fractionDigits: 1)) В",
            "Проводник: \(material.title), \(CableSections.title(section)) мм², t = \(temperature.title)",
            "Длина трассы: \(Fmt.number(calculation.length, fractionDigits: 1)) м",
            "Ток: \(Fmt.number(result.current, fractionDigits: 2)) А",
        ]
        if system.isAC {
            lines.append("cos φ = \(Fmt.number(calculation.powerFactor, fractionDigits: 3)), x = \(reactanceText) Ом/км")
        }
        lines += [
            "ΔU = \(Fmt.fixed(result.drop, fractionDigits: 2)) В (\(Fmt.fixed(result.dropPercent, fractionDigits: 2)) %), допустимо \(allowedText) %",
            "U на нагрузке: \(Fmt.fixed(result.loadVoltage, fractionDigits: 1)) В",
            "Потери в линии: \(Self.formatPower(result.powerLoss))",
            "Мин. сечение по ΔU: \(result.recommendedSection.map { "\(CableSections.title($0)) мм²" } ?? "нет подходящего ≤ 300 мм²")",
            "Итог: \(result.isWithinLimit ? "в норме" : "превышение допустимого ΔU")",
        ]
        return lines.joined(separator: "\n")
    }

    /// Headroom to the allowed drop, percentage points; negative when exceeded.
    var marginPercent: Double? {
        guard let calculation, let result else { return nil }
        return calculation.allowedDropPercent - result.dropPercent
    }

    static func powerReading(_ watts: Double) -> (value: String, unit: String) {
        watts >= 1000
            ? (Fmt.number(watts / 1000, fractionDigits: 2), "кВт")
            : (Fmt.number(watts, fractionDigits: 1), "Вт")
    }

    static func formatPower(_ watts: Double) -> String {
        let reading = powerReading(watts)
        return "\(reading.value) \(reading.unit)"
    }

    private func positive(_ text: String) -> Double? {
        guard let value = NumberParser.parse(text), value > 0 else { return nil }
        return value
    }
}
