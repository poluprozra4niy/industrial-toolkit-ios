import Testing
@testable import IndustrialToolkit

@Suite("Настройка ПИД")
struct PIDTuningTests {
    private func near(_ value: Double?, _ expected: Double, _ tolerance: Double = 1e-4) -> Bool {
        guard let value else { return false }
        return abs(value - expected) < tolerance
    }

    private func model() throws -> ProcessModel {
        try #require(ProcessModel(gain: 1.5, deadTime: 5, timeConstant: 40))
    }

    @Test("Циглер–Николс по Ku = 2, Tu = 30")
    func zieglerNicholsClosedLoop() throws {
        let pid = try #require(ClosedLoopRule.zieglerNichols.parameters(.pid, ku: 2, tu: 30))
        #expect(near(pid.kp, 1.2))
        #expect(near(pid.ti, 15))
        #expect(near(pid.td, 3.75))

        let pi = try #require(ClosedLoopRule.zieglerNichols.parameters(.pi, ku: 2, tu: 30))
        #expect(near(pi.kp, 0.9))
        #expect(near(pi.ti, 25))
        #expect(pi.td == nil)

        let p = try #require(ClosedLoopRule.zieglerNichols.parameters(.p, ku: 2, tu: 30))
        #expect(near(p.kp, 1.0))
        #expect(p.ti == nil)
    }

    @Test("Тайреус–Люйбен и модификации")
    func otherClosedLoopRules() throws {
        let tyreus = try #require(ClosedLoopRule.tyreusLuyben.parameters(.pid, ku: 2, tu: 30))
        #expect(near(tyreus.kp, 0.909_09))
        #expect(near(tyreus.ti, 66))
        #expect(near(tyreus.td, 4.761_9))
        #expect(ClosedLoopRule.someOvershoot.parameters(.p, ku: 2, tu: 30) == nil)
        #expect(ClosedLoopRule.tyreusLuyben.parameters(.p, ku: 2, tu: 30) == nil)
        #expect(ClosedLoopRule.zieglerNichols.parameters(.pid, ku: 0, tu: 30) == nil)
    }

    @Test("Циглер–Николс по разгону: K 1,5, L 5, T 40")
    func zieglerNicholsOpenLoop() throws {
        let process = try model()
        let pid = try #require(OpenLoopRule.zieglerNichols.parameters(.pid, model: process))
        #expect(near(pid.kp, 6.4))
        #expect(near(pid.ti, 10))
        #expect(near(pid.td, 2.5))
        let pi = try #require(OpenLoopRule.zieglerNichols.parameters(.pi, model: process))
        #expect(near(pi.kp, 4.8))
        #expect(near(pi.ti, 16.666_67))
    }

    @Test("Коэн–Кун")
    func cohenCoon() throws {
        let process = try model()
        let pi = try #require(OpenLoopRule.cohenCoon.parameters(.pi, model: process))
        #expect(near(pi.kp, 4.855_56))
        #expect(near(pi.ti, 13.206_52))
        let pid = try #require(OpenLoopRule.cohenCoon.parameters(.pid, model: process))
        #expect(near(pid.kp, 7.277_78))
        #expect(near(pid.ti, 11.696_43))
        #expect(near(pid.td, 1.777_78))
    }

    @Test("SIMC: только ПИ")
    func simc() throws {
        let process = try model()
        let pi = try #require(OpenLoopRule.simc.parameters(.pi, model: process))
        #expect(near(pi.kp, 2.666_67))
        #expect(near(pi.ti, 40))
        #expect(OpenLoopRule.simc.parameters(.pid, model: process) == nil)
    }

    @Test("Тест ступенькой по двум точкам")
    func stepTest() throws {
        let process = try #require(ProcessModel(outputStep: 10, processChange: 15, t28: 18, t63: 32))
        #expect(near(process.gain, 1.5))
        #expect(near(process.timeConstant, 21))
        #expect(near(process.deadTime, 11))
        #expect(ProcessModel(outputStep: 10, processChange: 15, t28: 32, t63: 18) == nil)
        #expect(ProcessModel(outputStep: 10, processChange: 15, t28: 10, t63: 30) == nil)
        #expect(ProcessModel(outputStep: 0, processChange: 15, t28: 18, t63: 32) == nil)
    }

    @Test("Параллельная форма и полоса пропорциональности")
    func forms() {
        let parameters = PIDParameters(kp: 2, ti: 10, td: 3)
        #expect(parameters.ki == 0.2)
        #expect(parameters.kd == 6)
        #expect(parameters.proportionalBand == 50)
        #expect(PIDParameters(kp: 2, ti: nil, td: nil).ki == nil)
    }
}
