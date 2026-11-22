import Foundation
import Observation

@MainActor
@Observable
final class StepTestViewModel {
    private(set) var startedAt: Date?
    private(set) var stoppedAt: Date?
    private(set) var samples: [StepSample] = []
    private(set) var marked28: Double?
    private(set) var marked63: Double?

    var initialText = ""
    var currentText = ""
    var finalText = ""
    var spanText = "100"
    var outputStepText = "10"

    var isRunning: Bool { startedAt != nil && stoppedAt == nil }
    var hasStarted: Bool { startedAt != nil }

    func elapsed(at now: Date) -> Double {
        guard let startedAt else { return 0 }
        return max(0, (stoppedAt ?? now).timeIntervalSince(startedAt))
    }

    // MARK: Actions

    /// The step is applied at this instant; PV before it becomes the initial value if not typed.
    func start(at now: Date = .now) {
        if NumberParser.parse(initialText) == nil {
            initialText = currentText
        }
        startedAt = now
        stoppedAt = nil
        samples = []
        marked28 = nil
        marked63 = nil
    }

    func stop(at now: Date = .now) {
        guard isRunning else { return }
        stoppedAt = now
        if NumberParser.parse(finalText) == nil, let last = samples.last {
            finalText = Fmt.number(last.value, fractionDigits: 4)
        }
    }

    var canRecord: Bool { isRunning && NumberParser.parse(currentText) != nil }

    func record(at now: Date = .now) {
        guard isRunning, let value = NumberParser.parse(currentText) else { return }
        let time = elapsed(at: now)
        guard samples.last.map({ time > $0.time }) ?? true else { return }
        samples.append(StepSample(time: time, value: value))
    }

    func mark28(at now: Date = .now) {
        guard isRunning else { return }
        marked28 = elapsed(at: now)
    }

    func mark63(at now: Date = .now) {
        guard isRunning else { return }
        marked63 = elapsed(at: now)
    }

    func removeLastSample() {
        guard !samples.isEmpty else { return }
        samples.removeLast()
    }

    func reset() {
        startedAt = nil
        stoppedAt = nil
        samples = []
        marked28 = nil
        marked63 = nil
        finalText = ""
    }

    // MARK: Analysis

    var initialValue: Double? { NumberParser.parse(initialText) }
    var finalValue: Double? { NumberParser.parse(finalText) }

    var span: Double? {
        guard let value = NumberParser.parse(spanText), value > 0 else { return nil }
        return value
    }

    var analysis: StepTestAnalysis? {
        guard let initialValue, let finalValue else { return nil }
        return StepTestAnalysis(initialValue: initialValue, finalValue: finalValue, samples: samples)
    }

    /// Readings that cross 28 % / 63 % let the times be interpolated; button marks are the fallback.
    var t28: Double? { analysis?.t28 ?? marked28 }
    var t63: Double? { analysis?.t63 ?? marked63 }

    func targetLevel(_ fraction: Double) -> Double? { analysis?.level(fraction) }

    var result: StepTestResult? {
        guard let analysis,
              let outputStep = NumberParser.parse(outputStepText), outputStep != 0,
              let t28, let t63, t63 > t28
        else { return nil }
        return StepTestResult(
            outputStepPercent: outputStep,
            processChangePercent: analysis.changePercent(span: span),
            t28: t28,
            t63: t63
        )
    }

    var resultHint: String {
        if initialValue == nil { return "Введите PV до ступеньки." }
        if finalValue == nil { return "Введите установившееся значение PV после ступеньки." }
        if analysis == nil { return "PV не изменилось — процесс не отреагировал." }
        if t28 == nil || t63 == nil { return "Нужны замеры PV, пересекающие уровни 28 % и 63 %, или отметки кнопками." }
        if let t28, let t63, t63 <= t28 { return "t63 должно быть больше t28." }
        return "Введите Δu — изменение выхода регулятора, %."
    }
}
