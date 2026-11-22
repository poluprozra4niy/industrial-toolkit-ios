import Foundation
import Observation

@MainActor
@Observable
final class PIDTuningViewModel {
    enum Method: String, CaseIterable, Identifiable {
        case closedLoop
        case openLoop

        var id: String { rawValue }

        var title: String {
            switch self {
            case .closedLoop: "По Ku и Tu"
            case .openLoop: "По разгону"
            }
        }
    }

    enum ModelInput: String, CaseIterable, Identifiable {
        case direct
        case stepTest

        var id: String { rawValue }

        var title: String {
            switch self {
            case .direct: "K, L, T"
            case .stepTest: "Тест ступенькой"
            }
        }
    }

    struct RuleResult: Identifiable {
        let id: String
        let title: String
        let note: String
        let parameters: PIDParameters
    }

    var method: Method = .closedLoop
    var controllerType: ControllerType = .pid

    var ultimateGainText = "2"
    var ultimatePeriodText = "30"

    var modelInput: ModelInput = .direct
    var gainText = "1,5"
    var deadTimeText = "5"
    var timeConstantText = "40"
    var outputStepText = "10"
    var processChangeText = "15"
    var t28Text = "18"
    var t63Text = "32"

    // MARK: Closed loop

    private var ultimateGain: Double? { Self.positive(ultimateGainText) }
    private var ultimatePeriod: Double? { Self.positive(ultimatePeriodText) }

    var isUltimateGainInvalid: Bool { ultimateGain == nil }
    var isUltimatePeriodInvalid: Bool { ultimatePeriod == nil }

    // MARK: Open loop

    var processModel: ProcessModel? {
        switch modelInput {
        case .direct:
            guard let gain = NumberParser.parse(gainText),
                  let deadTime = Self.positive(deadTimeText),
                  let timeConstant = Self.positive(timeConstantText)
            else { return nil }
            return ProcessModel(gain: gain, deadTime: deadTime, timeConstant: timeConstant)
        case .stepTest:
            guard let outputStep = NumberParser.parse(outputStepText),
                  let processChange = NumberParser.parse(processChangeText),
                  let t28 = Self.positive(t28Text),
                  let t63 = Self.positive(t63Text)
            else { return nil }
            return ProcessModel(outputStep: outputStep, processChange: processChange, t28: t28, t63: t63)
        }
    }

    var modelError: String? {
        guard method == .openLoop, processModel == nil else { return nil }
        switch modelInput {
        case .direct:
            return "K ≠ 0, L > 0, T > 0"
        case .stepTest:
            guard let outputStep = NumberParser.parse(outputStepText),
                  let processChange = NumberParser.parse(processChangeText),
                  let t28 = Self.positive(t28Text),
                  let t63 = Self.positive(t63Text)
            else { return "Введите Δu, Δy, t28 и t63 числами" }
            if outputStep == 0 { return "Δu не может быть 0" }
            if processChange == 0 { return "Δy = 0: процесс не отреагировал на ступеньку" }
            if t63 <= t28 { return "t63 должно быть больше t28" }
            return "Получилось L ≤ 0: t63 ≥ 3·t28 — проверьте отсчёт времени от момента ступеньки"
        }
    }

    var controllabilityHint: String? {
        guard method == .openLoop, let processModel else { return nil }
        let ratio = processModel.controllability
        let value = Fmt.fixed(ratio, fractionDigits: 2)
        switch ratio {
        case ..<0.1: return "L/T = \(value): запаздывание мало, контур легко настраивается"
        case ..<0.5: return "L/T = \(value): обычный процесс, подходят все методы"
        case ..<1: return "L/T = \(value): заметное запаздывание, Циглер–Николс агрессивен — предпочтите Коэн–Куна или SIMC"
        default: return "L/T = \(value): запаздывание доминирует — используйте SIMC, уменьшите Kp"
        }
    }

    // MARK: Results

    var results: [RuleResult] {
        switch method {
        case .closedLoop:
            guard let ultimateGain, let ultimatePeriod else { return [] }
            return ClosedLoopRule.allCases.compactMap { rule in
                rule.parameters(controllerType, ku: ultimateGain, tu: ultimatePeriod).map {
                    RuleResult(id: rule.rawValue, title: rule.title, note: rule.note, parameters: $0)
                }
            }
        case .openLoop:
            guard let processModel else { return [] }
            return OpenLoopRule.allCases.compactMap { rule in
                rule.parameters(controllerType, model: processModel).map {
                    RuleResult(id: rule.rawValue, title: rule.title, note: rule.note, parameters: $0)
                }
            }
        }
    }

    // MARK: Export

    var noteTitle: String { "Настройка \(controllerType.title)-регулятора" }

    var summary: String? {
        let rows = results
        guard !rows.isEmpty else { return nil }
        var lines = ["Настройка \(controllerType.title)-регулятора"]
        switch method {
        case .closedLoop:
            lines.append("Ku = \(ultimateGainText), Tu = \(ultimatePeriodText)")
        case .openLoop:
            if let processModel {
                lines.append(
                    "K = \(Fmt.number(processModel.gain, fractionDigits: 3)), "
                        + "L = \(Fmt.number(processModel.deadTime, fractionDigits: 2)), "
                        + "T = \(Fmt.number(processModel.timeConstant, fractionDigits: 2))"
                )
            }
        }
        for row in rows {
            lines.append("")
            lines.append(row.title + ":")
            lines.append("  " + Self.describe(row.parameters))
        }
        return lines.joined(separator: "\n")
    }

    static func describe(_ parameters: PIDParameters) -> String {
        var parts = [
            "Kp = \(Fmt.number(parameters.kp, fractionDigits: 3))",
            "Xp = \(Fmt.number(parameters.proportionalBand, fractionDigits: 1)) %",
        ]
        if let ti = parameters.ti { parts.append("Ti = \(Fmt.number(ti, fractionDigits: 2))") }
        if let td = parameters.td { parts.append("Td = \(Fmt.number(td, fractionDigits: 2))") }
        return parts.joined(separator: ", ")
    }

    private static func positive(_ text: String) -> Double? {
        guard let value = NumberParser.parse(text), value > 0 else { return nil }
        return value
    }
}
