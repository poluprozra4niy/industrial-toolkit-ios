import Foundation
import Observation

@MainActor
@Observable
final class LoopBudgetViewModel {
    struct CurrentOption: Identifiable, Hashable {
        let milliamps: Double
        let caption: String

        var id: Double { milliamps }
    }

    /// The loop must hold up at the alarm current, not only at 20 mA (NAMUR NE43: failure ≥ 21 mA).
    static let currentOptions = [
        CurrentOption(milliamps: 20, caption: "номинал"),
        CurrentOption(milliamps: 20.5, caption: "насыщение"),
        CurrentOption(milliamps: 21, caption: "порог отказа"),
        CurrentOption(milliamps: 22, caption: "аварийный"),
    ]

    var supplyText = "24"
    var transmitterMinimumText = "12"
    var currentMilliamps = 22.0
    var loadText = "250"
    var lengthText = "200"
    var sectionText = "0.75"
    var material: ConductorMaterial = .copper
    var barrierResistanceText = "0"
    var barrierDropText = "0"
    var checksHART = false

    private func parse(_ text: String) -> Double? {
        guard let value = NumberParser.parse(text), value >= 0 else { return nil }
        return value
    }

    func isInvalid(_ text: String) -> Bool { parse(text) == nil }

    var section: Double? { parse(sectionText).flatMap { $0 > 0 ? $0 : nil } }

    var lineResistance: Double? {
        guard let length = parse(lengthText), let section else { return nil }
        return LoopBudget.lineResistance(length: length, section: section, material: material)
    }

    var budget: LoopBudget? {
        guard let supply = parse(supplyText),
              let minimum = parse(transmitterMinimumText),
              let load = parse(loadText),
              let line = lineResistance,
              let barrierResistance = parse(barrierResistanceText),
              let barrierDrop = parse(barrierDropText)
        else { return nil }
        return LoopBudget(
            supplyVoltage: supply,
            transmitterMinimumVoltage: minimum,
            current: currentMilliamps / 1_000,
            loadResistance: load,
            lineResistance: line,
            barrierResistance: barrierResistance,
            barrierDrop: barrierDrop
        )
    }

    var maximumLineLength: Double? {
        guard let budget, let section else { return nil }
        return budget.maximumLineLength(section: section, material: material)
    }

    var noteTitle: String { "Контур 4–20 мА: \(supplyText) В, \(loadText) Ом" }

    var summary: String? {
        guard let budget else { return nil }
        var lines = [
            "Питание \(Fmt.number(budget.supplyVoltage, fractionDigits: 2)) В, ток \(Fmt.number(currentMilliamps, fractionDigits: 2)) мА",
            "Сопротивления: нагрузка \(Fmt.number(budget.loadResistance, fractionDigits: 1)) Ом, линия \(Fmt.number(budget.lineResistance, fractionDigits: 1)) Ом, барьер \(Fmt.number(budget.barrierResistance, fractionDigits: 1)) Ом + \(Fmt.number(budget.barrierDrop, fractionDigits: 2)) В",
            "Напряжение на датчике: \(Fmt.number(budget.terminalVoltage, fractionDigits: 2)) В (мин. \(Fmt.number(budget.transmitterMinimumVoltage, fractionDigits: 2)) В)",
            "Запас: \(Fmt.number(budget.margin, fractionDigits: 2)) В — \(budget.isSufficient ? "питания хватает" : "питания НЕ хватает")",
            "Допустимое сопротивление контура: \(Fmt.number(budget.maximumResistance, fractionDigits: 0)) Ом",
        ]
        if let length = maximumLineLength {
            lines.append("Максимальная длина линии: \(Fmt.number(length, fractionDigits: 0)) м")
        }
        if checksHART {
            lines.append("HART: \(budget.meetsHART ? "сопротивление достаточно" : "нужно ≥ 230 Ом в контуре")")
        }
        return lines.joined(separator: "\n")
    }
}
