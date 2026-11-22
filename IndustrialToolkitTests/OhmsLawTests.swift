import Testing
@testable import IndustrialToolkit

@Suite("Закон Ома и мощность")
struct OhmsLawTests {
    private static let cases: [(OhmPair, Double, Double)] = [
        (.voltageCurrent, 24, 0.5),
        (.voltageResistance, 24, 48),
        (.voltagePower, 24, 12),
        (.currentResistance, 0.5, 48),
        (.currentPower, 0.5, 12),
        (.resistancePower, 48, 12),
    ]

    @Test("Любая пара даёт U = 24 В, I = 0,5 А, R = 48 Ом, P = 12 Вт", arguments: cases)
    func everyPairSolvesSameCircuit(pair: OhmPair, first: Double, second: Double) throws {
        let solution = try #require(OhmsLaw.solve(pair, first: first, second: second))
        #expect(abs(solution.voltage - 24) < 1e-9)
        #expect(abs(solution.current - 0.5) < 1e-9)
        #expect(abs(solution.resistance - 48) < 1e-9)
        #expect(abs(solution.power - 12) < 1e-9)
    }

    @Test("Нулевые и отрицательные значения отклоняются")
    func rejectsNonPositive() {
        #expect(OhmsLaw.solve(.voltageCurrent, first: 0, second: 1) == nil)
        #expect(OhmsLaw.solve(.resistancePower, first: 10, second: -1) == nil)
    }

    @Test("Приставки СИ")
    func engineeringScale() {
        let kilo = EngineeringNotation.scale(4_700)
        #expect(kilo.prefix == "к")
        #expect(abs(kilo.value - 4.7) < 1e-12)
        let milli = EngineeringNotation.scale(0.02)
        #expect(milli.prefix == "м")
        #expect(abs(milli.value - 20) < 1e-9)
        #expect(EngineeringNotation.scale(1.5e6).prefix == "М")
        #expect(EngineeringNotation.scale(12).prefix == "")
        #expect(EngineeringNotation.scale(0).value == 0)
        #expect(EngineeringNotation.scale(5e-7).prefix == "мк")
    }

    @Test("3~ 400 В, 10 А, cos φ 0,85")
    func threePhaseFromCurrent() throws {
        let result = try #require(ACPower.fromVoltageCurrent(system: .threePhase, voltage: 400, current: 10, powerFactor: 0.85))
        #expect(abs(result.apparent - 6_928.203) < 1e-2)
        #expect(abs(result.active - 5_888.973) < 1e-2)
        #expect(abs(result.reactive - 3_649.65) < 1e-1)
    }

    @Test("1~ 230 В, 2 кВт, cos φ 1 → 8,70 А, Q = 0")
    func singlePhaseFromActive() throws {
        let result = try #require(ACPower.fromActivePower(system: .singlePhase, activePower: 2_000, voltage: 230, powerFactor: 1))
        #expect(abs(result.current - 8.695_652) < 1e-5)
        #expect(result.reactive == 0)
        #expect(result.phiDegrees == 0)
    }

    @Test("P = 3 кВт, Q = 4 квар → S = 5 кВ·А, cos φ = 0,6")
    func fromActiveReactive() throws {
        let result = try #require(ACPower.fromActiveReactive(system: .threePhase, activePower: 3_000, reactivePower: 4_000, voltage: 400))
        #expect(abs(result.apparent - 5_000) < 1e-9)
        #expect(abs(result.powerFactor - 0.6) < 1e-12)
        #expect(abs(result.current - 7.216_878) < 1e-5)
    }

    @Test("cos φ 0,5 = 60°, DC не поддерживается")
    func phaseAngleAndDC() throws {
        let result = try #require(ACPower.fromVoltageCurrent(system: .singlePhase, voltage: 230, current: 1, powerFactor: 0.5))
        #expect(abs(result.phiDegrees - 60) < 1e-9)
        #expect(ACPower.fromVoltageCurrent(system: .dc, voltage: 24, current: 1, powerFactor: 1) == nil)
    }

    @Test("КРМ: 100 кВт с 0,8 до 0,95 ≈ 42,1 квар")
    func compensation() throws {
        let compensation = try #require(ACPower.compensation(activePower: 100_000, from: 0.8, to: 0.95))
        #expect(abs(compensation - 42_131.6) < 1)
        #expect(ACPower.compensation(activePower: 100_000, from: 0.97, to: 0.95) == 0)
        #expect(ACPower.compensation(activePower: 100_000, from: 0, to: 0.95) == nil)
    }
}
