import Foundation

/// One PV reading taken during an open-loop step test; time is counted from the step, s.
struct StepSample: Equatable, Identifiable {
    let time: Double
    let value: Double

    var id: Double { time }
}

/// Two-point (Smith) identification: the PV crosses 28.3 % and 63.2 % of its total change
/// at t28 and t63; the controller model in `ProcessModel` is derived from those times.
struct StepTestAnalysis: Equatable {
    static let fraction28 = 0.283
    static let fraction63 = 0.632

    let initialValue: Double
    let finalValue: Double
    let samples: [StepSample]

    init?(initialValue: Double, finalValue: Double, samples: [StepSample]) {
        guard initialValue.isFinite, finalValue.isFinite, finalValue != initialValue else { return nil }
        self.initialValue = initialValue
        self.finalValue = finalValue
        self.samples = samples.filter { $0.time >= 0 }.sorted { $0.time < $1.time }
    }

    var change: Double { finalValue - initialValue }

    func level(_ fraction: Double) -> Double { initialValue + fraction * change }

    /// First crossing of the level, linearly interpolated between readings. The step instant
    /// (t = 0, PV = initial) is the implicit first point; works for falling responses too.
    func crossingTime(_ fraction: Double) -> Double? {
        let target = level(fraction)
        let direction: Double = change > 0 ? 1 : -1
        var previous = StepSample(time: 0, value: initialValue)
        for sample in samples {
            let before = (previous.value - target) * direction
            let after = (sample.value - target) * direction
            if after >= 0 {
                if before >= 0 { return previous.time }
                let share = -before / (after - before)
                return previous.time + share * (sample.time - previous.time)
            }
            previous = sample
        }
        return nil
    }

    var t28: Double? { crossingTime(Self.fraction28) }
    var t63: Double? { crossingTime(Self.fraction63) }

    /// Stopwatch reading mm:ss.t.
    static func clock(_ seconds: Double) -> String {
        let tenths = Int((max(0, seconds) * 10).rounded(.down))
        let minutes = tenths / 600
        let rest = Double(tenths % 600) / 10
        return String(format: "%02d:%04.1f", minutes, rest)
    }

    /// Δy as a percentage of the PV span — the unit `ProcessModel` gain expects.
    func changePercent(span: Double?) -> Double {
        guard let span, span > 0 else { return change }
        return change / span * 100
    }
}

/// What the stopwatch hands to the PID tuning screen.
struct StepTestResult: Equatable {
    let outputStepPercent: Double
    let processChangePercent: Double
    let t28: Double
    let t63: Double
}
