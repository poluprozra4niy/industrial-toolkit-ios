import Foundation
import Testing
@testable import IndustrialToolkit

private func unit(_ id: String, in category: UnitCategory) -> MeasurementUnit? {
    category.units.first { $0.id == id }
}

@Suite("Конвертер единиц")
struct UnitConversionTests {
    @Test(
        "Давление",
        arguments: [
            ("bar", "kgfcm2", 1.0, 1.019_716_2),
            ("kgfcm2", "bar", 1.0, 0.980_665),
            ("psi", "bar", 1.0, 0.068_947_57),
            ("MPa", "mH2O", 1.0, 101.971_62),
            ("atm", "mmHg", 1.0, 760.0),
            ("kPa", "mmH2O", 1.0, 101.971_62),
        ]
    )
    func pressure(from: String, to: String, value: Double, expected: Double) throws {
        let source = try #require(unit(from, in: .pressure))
        let target = try #require(unit(to, in: .pressure))
        let result = try #require(UnitConverter.convert(value, from: source, to: target))
        #expect(abs(result - expected) / expected < 1e-6)
    }

    @Test("Температура и абсолютный ноль")
    func temperature() throws {
        let celsius = try #require(unit("C", in: .temperature))
        let kelvin = try #require(unit("K", in: .temperature))
        let fahrenheit = try #require(unit("F", in: .temperature))
        #expect(abs((UnitConverter.convert(100, from: celsius, to: kelvin) ?? 0) - 373.15) < 1e-9)
        #expect(abs((UnitConverter.convert(100, from: celsius, to: fahrenheit) ?? 0) - 212) < 1e-9)
        #expect(abs((UnitConverter.convert(-40, from: fahrenheit, to: celsius) ?? 0) + 40) < 1e-9)
        #expect(UnitConverter.convert(-300, from: celsius, to: kelvin) == nil)
        #expect(UnitConverter.convert(-1, from: kelvin, to: celsius) == nil)
    }

    @Test("Расход: объём ↔ масса через плотность")
    func flow() throws {
        let cubicPerHour = try #require(unit("m3h", in: .flow))
        let litresPerSecond = try #require(unit("ls", in: .flow))
        let tonnesPerHour = try #require(unit("th", in: .flow))
        let cubicPerDay = try #require(unit("m3d", in: .flow))
        #expect(abs((UnitConverter.convert(36, from: cubicPerHour, to: litresPerSecond) ?? 0) - 10) < 1e-9)
        #expect(abs((UnitConverter.convert(36, from: cubicPerHour, to: tonnesPerHour, density: 1_000) ?? 0) - 36) < 1e-9)
        #expect(abs((UnitConverter.convert(10, from: tonnesPerHour, to: cubicPerHour, density: 800) ?? 0) - 12.5) < 1e-9)
        #expect(abs((UnitConverter.convert(24, from: cubicPerDay, to: cubicPerHour) ?? 0) - 1) < 1e-9)
        #expect(UnitConverter.convert(1, from: cubicPerHour, to: tonnesPerHour) == nil)
    }

    @Test("Мощность")
    func power() throws {
        let kilowatt = try #require(unit("kW", in: .power))
        let horsepower = try #require(unit("hpMetric", in: .power))
        let gigacalorie = try #require(unit("Gcalh", in: .power))
        #expect(abs((UnitConverter.convert(1, from: horsepower, to: kilowatt) ?? 0) - 0.735_498_75) < 1e-12)
        #expect(abs((UnitConverter.convert(1, from: gigacalorie, to: kilowatt) ?? 0) - 1_163) < 1e-9)
    }
}

@Suite("Нагрузка контура 4–20 мА")
struct LoopBudgetTests {
    @Test("24 В, 250 Ом, 200 м × 0,75 мм² Cu при 22 мА")
    func typicalLoop() throws {
        let line = try #require(LoopBudget.lineResistance(length: 200, section: 0.75, material: .copper))
        #expect(abs(line - 9.333_333) < 1e-5)
        let budget = try #require(LoopBudget(
            supplyVoltage: 24,
            transmitterMinimumVoltage: 12,
            current: 0.022,
            loadResistance: 250,
            lineResistance: line
        ))
        #expect(abs(budget.terminalVoltage - 18.294_667) < 1e-5)
        #expect(budget.isSufficient)
        #expect(abs(budget.maximumResistance - 545.454_545) < 1e-5)
        let length = try #require(budget.maximumLineLength(section: 0.75, material: .copper))
        #expect(abs(length - 6_331.168_8) < 1e-3)
        #expect(budget.meetsHART)
        #expect(abs(budget.voltageAcrossLoad(at: 0.004) - 1) < 1e-12)
        #expect(abs(budget.voltageAcrossLoad(at: 0.020) - 5) < 1e-12)
    }

    @Test("Барьер съедает запас")
    func barrier() throws {
        let budget = try #require(LoopBudget(
            supplyVoltage: 24,
            transmitterMinimumVoltage: 12,
            current: 0.022,
            loadResistance: 250,
            lineResistance: 10,
            barrierResistance: 300,
            barrierDrop: 0.9
        ))
        #expect(!budget.isSufficient)
        #expect(budget.margin < 0)
        #expect(abs(budget.minimumSupplyVoltage - (12 + 0.9 + 0.022 * 560)) < 1e-9)
        #expect(budget.maximumLineLength(section: 0.75, material: .copper) == 0)
        #expect(LoopBudget(supplyVoltage: 24, transmitterMinimumVoltage: 12, current: 0, loadResistance: 250, lineResistance: 0) == nil)
        #expect(LoopBudget(supplyVoltage: 24, transmitterMinimumVoltage: 12, current: 0.02, loadResistance: 100, lineResistance: 0)?.meetsHART == false)
    }
}

@Suite("Двигатель и частотник")
struct MotorTests {
    private let nameplate = MotorNameplate(power: 7.5, voltage: 380, cosPhi: 0.85, efficiency: 0.88, ratedSpeed: 1_450)

    @Test("7,5 кВт 380 В: ток, полюса, момент")
    func ratedValues() throws {
        let motor = try #require(nameplate)
        #expect(abs(motor.ratedCurrent - 15.234) < 0.001)
        #expect(abs(motor.startingCurrent - 7 * motor.ratedCurrent) < 1e-9)
        #expect(motor.polePairs == 2)
        #expect(motor.synchronousSpeed == 1_500)
        #expect(abs(motor.slip - 1.0 / 30) < 1e-12)
        #expect(abs(motor.ratedTorque - 49.396_55) < 1e-4)
    }

    @Test("Частотник: обороты и мощность насоса")
    func inverter() throws {
        let motor = try #require(nameplate)
        #expect(motor.speed(atFrequency: 50) == 1_450)
        #expect(motor.speed(atFrequency: 25) == 700)
        #expect(motor.speed(atFrequency: 1) == 0)
        let half = motor.affinityPower(atFrequency: 25)
        #expect(abs(half - 7.5 * pow(700.0 / 1_450, 3)) < 1e-9)
    }

    @Test("Автомат: C16 может сработать при пуске, D16 — нет")
    func breakers() throws {
        let motor = try #require(nameplate)
        let c = try #require(motor.breakerCheck(curve: .c))
        #expect(c.breaker.rating == 16)
        #expect(!c.survivesStart)
        let d = try #require(motor.breakerCheck(curve: .d))
        #expect(d.survivesStart)
        let big = try #require(MotorNameplate(power: 90, voltage: 380, cosPhi: 0.88, efficiency: 0.94, ratedSpeed: 1_480))
        #expect(big.breakerCheck(curve: .c) == nil)
    }

    @Test("Однофазный и недопустимые данные")
    func validation() throws {
        let single = try #require(MotorNameplate(power: 1.1, voltage: 230, cosPhi: 0.9, efficiency: 0.75, ratedSpeed: 2_800, supply: .singlePhase))
        #expect(abs(single.ratedCurrent - 1_100 / (230 * 0.9 * 0.75)) < 1e-9)
        #expect(single.polePairs == 1)
        #expect(MotorNameplate(power: 7.5, voltage: 380, cosPhi: 1.2, efficiency: 0.9, ratedSpeed: 1_450) == nil)
        #expect(MotorNameplate(power: 7.5, voltage: 380, cosPhi: 0.85, efficiency: 0.9, ratedSpeed: 3_100) == nil)
    }
}
