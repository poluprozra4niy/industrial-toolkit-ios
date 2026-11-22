import Foundation
import Testing
@testable import IndustrialToolkit

@Suite("Тест ступенькой: t28 / t63 по замерам")
struct StepTestTests {
    /// First-order plus dead time: K·Δu·(1 − e^(−(t − L)/T)) after the dead time.
    private func response(from start: Double, to end: Double, deadTime: Double, timeConstant: Double, step: Double) -> [StepSample] {
        stride(from: step, through: 8 * timeConstant, by: step).map { time in
            let rise = time <= deadTime ? 0 : 1 - exp(-(time - deadTime) / timeConstant)
            return StepSample(time: time, value: start + (end - start) * rise)
        }
    }

    @Test("Модель 1-го порядка L = 5 с, T = 20 с восстанавливается")
    func firstOrder() throws {
        let samples = response(from: 0, to: 100, deadTime: 5, timeConstant: 20, step: 1)
        let analysis = try #require(StepTestAnalysis(initialValue: 0, finalValue: 100, samples: samples))
        let t28 = try #require(analysis.t28)
        let t63 = try #require(analysis.t63)
        #expect(abs(t28 - (5 - 20 * log(1 - 0.283))) < 0.1)
        #expect(abs(t63 - (5 - 20 * log(1 - 0.632))) < 0.1)

        let model = try #require(ProcessModel(outputStep: 10, processChange: analysis.changePercent(span: 100), t28: t28, t63: t63))
        #expect(abs(model.timeConstant - 20) < 0.5)
        #expect(abs(model.deadTime - 5) < 0.5)
        #expect(abs(model.gain - 10) < 1e-9)
    }

    @Test("Падающий отклик и шкала в процентах")
    func fallingResponse() throws {
        let samples = response(from: 80, to: 60, deadTime: 2, timeConstant: 10, step: 0.5)
        let analysis = try #require(StepTestAnalysis(initialValue: 80, finalValue: 60, samples: samples.shuffled()))
        let t63 = try #require(analysis.t63)
        #expect(abs(t63 - (2 + 10 * 0.999_672)) < 0.05)
        #expect(analysis.changePercent(span: 200) == -10)
        #expect(analysis.changePercent(span: nil) == -20)
    }

    @Test("Точная интерполяция и нехватка замеров")
    func interpolation() throws {
        let samples = [StepSample(time: 10, value: 0), StepSample(time: 20, value: 50), StepSample(time: 30, value: 100)]
        let analysis = try #require(StepTestAnalysis(initialValue: 0, finalValue: 100, samples: samples))
        #expect(abs((analysis.t28 ?? 0) - 15.66) < 1e-9)
        #expect(abs((analysis.t63 ?? 0) - 22.64) < 1e-9)

        let short = try #require(StepTestAnalysis(initialValue: 0, finalValue: 100, samples: [StepSample(time: 5, value: 40)]))
        #expect(short.t28 != nil)
        #expect(short.t63 == nil)
        #expect(StepTestAnalysis(initialValue: 5, finalValue: 5, samples: samples) == nil)
    }

    @Test("Формат секундомера")
    func clock() {
        #expect(StepTestAnalysis.clock(0) == "00:00.0")
        #expect(StepTestAnalysis.clock(83.46) == "01:23.4")
    }
}
