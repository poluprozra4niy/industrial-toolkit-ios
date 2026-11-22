import Testing
@testable import IndustrialToolkit

@Suite("Падение напряжения в кабельной линии")
struct VoltageDropTests {
    private func calculation(
        _ system: PowerSystem,
        voltage: Double,
        powerFactor: Double = 1,
        length: Double,
        section: Double,
        material: ConductorMaterial = .copper,
        temperature: Double = 20,
        reactancePerKm: Double = 0,
        allowed: Double = 5
    ) throws -> VoltageDropCalculation {
        try #require(VoltageDropCalculation(
            system: system,
            material: material,
            conductorTemperature: temperature,
            voltage: voltage,
            powerFactor: powerFactor,
            length: length,
            section: section,
            reactancePerKm: reactancePerKm,
            allowedDropPercent: allowed
        ))
    }

    @Test("DC 24 В, 2 А, 100 м, 1,5 мм² Cu: ΔU 4,67 В, нужно 6 мм²")
    func dcControlCircuit() throws {
        let result = try calculation(.dc, voltage: 24, length: 100, section: 1.5).result(current: 2)
        #expect(abs(result.drop - 4.666_667) < 1e-5)
        #expect(abs(result.dropPercent - 19.444_444) < 1e-5)
        #expect(abs(result.loadVoltage - 19.333_333) < 1e-5)
        #expect(abs(result.powerLoss - 9.333_333) < 1e-5)
        #expect(!result.isWithinLimit)
        #expect(abs((result.minimumSection ?? 0) - 5.833_333) < 1e-5)
        #expect(result.recommendedSection == 6)
        #expect(abs(result.maximumLength - 25.714_286) < 1e-5)
    }

    @Test("3~ 400 В, 100 А, 100 м, 35 мм², cos φ 0,9, x 0,08 Ом/км")
    func threePhaseWithReactance() throws {
        let result = try calculation(
            .threePhase, voltage: 400, powerFactor: 0.9, length: 100, section: 35, reactancePerKm: 0.08
        ).result(current: 100)
        #expect(abs(result.drop - 8.398_216) < 1e-4)
        #expect(abs(result.dropPercent - 2.099_554) < 1e-4)
        #expect(result.isWithinLimit)
    }

    @Test("1~ 230 В, 10 А, 50 м, 2,5 мм²: ΔU 7 В")
    func singlePhase() throws {
        let result = try calculation(.singlePhase, voltage: 230, length: 50, section: 2.5).result(current: 10)
        #expect(abs(result.drop - 7) < 1e-9)
        #expect(abs(result.dropPercent - 3.043_478) < 1e-5)
    }

    @Test("DC игнорирует cos φ и реактивное сопротивление")
    func dcIgnoresACParameters() throws {
        let plain = try calculation(.dc, voltage: 24, length: 100, section: 1.5).result(current: 2)
        let withAC = try calculation(
            .dc, voltage: 24, powerFactor: 0.5, length: 100, section: 1.5, reactancePerKm: 0.08
        ).result(current: 2)
        #expect(plain == withAC)
    }

    @Test("Сопротивление меди растёт с температурой")
    func temperatureCorrection() {
        #expect(abs(ConductorMaterial.copper.resistivity(at: 70) - 0.020_938_75) < 1e-9)
        #expect(ConductorMaterial.aluminium.resistivity(at: 20) == 0.0282)
    }

    @Test("Ток трёхфазной нагрузки 55 кВт, 400 В, cos φ 0,9 ≈ 88,2 А")
    func currentFromPower() {
        let current = PowerSystem.threePhase.current(fromPower: 55_000, voltage: 400, powerFactor: 0.9)
        #expect(abs(current - 88.206_3) < 1e-3)
        #expect(PowerSystem.dc.current(fromPower: 240, voltage: 24, powerFactor: 0.5) == 10)
    }

    @Test("Если реактивная составляющая сама превышает лимит — подходящего сечения нет")
    func impossibleSection() throws {
        let result = try calculation(
            .threePhase, voltage: 400, powerFactor: 0.9, length: 1000, section: 240, reactancePerKm: 0.08, allowed: 1
        ).result(current: 1000)
        #expect(result.minimumSection == nil)
        #expect(result.recommendedSection == nil)
    }

    @Test("Некорректные параметры отклоняются")
    func invalidInputs() {
        let make = { (pf: Double, section: Double, allowed: Double) in
            VoltageDropCalculation(
                system: .singlePhase, material: .copper, conductorTemperature: 20, voltage: 230,
                powerFactor: pf, length: 10, section: section, reactancePerKm: 0, allowedDropPercent: allowed
            )
        }
        #expect(make(0, 2.5, 5) == nil)
        #expect(make(1.2, 2.5, 5) == nil)
        #expect(make(0.9, 0, 5) == nil)
        #expect(make(0.9, 2.5, 100) == nil)
        #expect(make(0.9, 2.5, 5) != nil)
    }

    @Test("Подбор ближайшего стандартного сечения")
    func standardSections() {
        #expect(CableSections.nextStandard(atLeast: 5.83) == 6)
        #expect(CableSections.nextStandard(atLeast: 2.5) == 2.5)
        #expect(CableSections.nextStandard(atLeast: 300.1) == nil)
    }
}
