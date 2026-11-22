import Foundation
import Observation

@MainActor
@Observable
final class SignalConverterViewModel {
    enum InputKind: String, CaseIterable, Identifiable {
        case signal
        case processValue
        case rawCounts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .signal: "Сигнал"
            case .processValue: "Величина"
            case .rawCounts: "Код АЦП"
            }
        }
    }

    static let unitPresets = ["бар", "МПа", "кПа", "°C", "%", "м³/ч", "т/ч", "м", "мм", "об/мин", "pH"]

    var signalRange: SignalRange = .mA4to20
    var rawRange: RawCountRange = .siemensS7
    var lowText = "0"
    var highText = "10"
    var unit = "бар"
    var squareRoot = false
    var inputText = "12"
    private(set) var inputKind: InputKind = .signal

    var low: Double? { NumberParser.parse(lowText) }
    var high: Double? { NumberParser.parse(highText) }
    var inputValue: Double? { NumberParser.parse(inputText) }

    var isLowInvalid: Bool { low == nil }
    var isHighInvalid: Bool { high == nil }
    var isInputInvalid: Bool { !inputText.isEmpty && inputValue == nil }

    var scale: SignalScale? {
        guard let low, let high else { return nil }
        return SignalScale(signal: signalRange, raw: rawRange, low: low, high: high, squareRoot: squareRoot)
    }

    var scaleError: String? {
        guard let low, let high else { return "Введите НПИ и ВПИ числами" }
        return low == high ? "НПИ и ВПИ не должны совпадать" : nil
    }

    var result: ScalingResult? {
        guard let scale, let value = inputValue else { return nil }
        switch inputKind {
        case .signal: return scale.convert(signal: value)
        case .processValue: return scale.convert(processValue: value)
        case .rawCounts: return scale.convert(rawCounts: value)
        }
    }

    var inputUnit: String {
        switch inputKind {
        case .signal: signalRange.unit
        case .processValue: unit
        case .rawCounts: "ед."
        }
    }

    var inputLabel: String {
        switch inputKind {
        case .signal: "Значение сигнала"
        case .processValue: "Значение величины"
        case .rawCounts: "Код АЦП (\(rawRange.title))"
        }
    }

    /// Carries the current value over so switching the input side never loses the reading.
    func selectInputKind(_ kind: InputKind) {
        guard kind != inputKind else { return }
        if let result {
            switch kind {
            case .signal: inputText = Fmt.number(result.signal, fractionDigits: 4)
            case .processValue: inputText = Fmt.number(result.processValue, fractionDigits: 4)
            case .rawCounts: inputText = Fmt.number(result.rawCounts, fractionDigits: 0)
            }
        }
        inputKind = kind
    }

    var noteTitle: String {
        "Сигнал \(signalRange.title) → \(lowText)…\(highText) \(unit)"
    }

    var summary: String? {
        guard let result, let scale else { return nil }
        let mode = squareRoot ? " (корнеизвлечение)" : ""
        return [
            "Конвертер сигналов",
            "Шкала: \(signalRange.title) → \(Fmt.number(scale.low, fractionDigits: 4)) … \(Fmt.number(scale.high, fractionDigits: 4)) \(unit)\(mode)",
            "Ввод (\(inputKind.title.lowercased())): \(inputText) \(inputUnit)",
            "Сигнал: \(Fmt.fixed(result.signal, fractionDigits: 3)) \(signalRange.unit) (\(Fmt.fixed(result.signalFraction * 100, fractionDigits: 2)) %)",
            "Величина: \(Fmt.number(result.processValue, fractionDigits: 4)) \(unit) (\(Fmt.fixed(result.processFraction * 100, fractionDigits: 2)) %)",
            "Код АЦП (\(rawRange.title)): \(Fmt.number(result.rawCounts, fractionDigits: 0))",
            "Состояние: \(result.health.title)",
        ].joined(separator: "\n")
    }
}
