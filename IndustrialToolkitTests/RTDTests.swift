import Testing
@testable import IndustrialToolkit

@Suite("Термосопротивления: IEC 60751 / ГОСТ 6651")
struct RTDTests {
    private let pt100 = RTDSensor(curve: .platinum385, nominal: 100)

    @Test(
        "Pt100: эталонные точки IEC 60751",
        arguments: [
            (-200.0, 18.520_08),
            (-100.0, 60.255_84),
            (0.0, 100.0),
            (100.0, 138.505_5),
            (850.0, 390.481_6),
        ]
    )
    func pt100ReferencePoints(temperature: Double, expected: Double) throws {
        let resistance = try #require(pt100.resistance(at: temperature))
        #expect(abs(resistance - expected) < 1e-3)
    }

    @Test("Обратный расчёт R → t", arguments: [-195.0, -100.0, -0.5, 0.0, 25.0, 100.0, 600.0])
    func inverseRoundTrip(temperature: Double) throws {
        let resistance = try #require(pt100.resistance(at: temperature))
        let restored = try #require(pt100.temperature(for: resistance))
        #expect(abs(restored - temperature) < 1e-6)
    }

    @Test("Pt1000, 100П, 100М при 100 °C и 100М при −50 °C")
    func otherSensors() throws {
        let pt1000 = try #require(RTDSensor(curve: .platinum385, nominal: 1000).resistance(at: 100))
        #expect(abs(pt1000 - 1385.055) < 1e-2)
        let platinum391 = try #require(RTDSensor(curve: .platinum391, nominal: 100).resistance(at: 100))
        #expect(abs(platinum391 - 139.1059) < 1e-3)

        let copper = RTDSensor(curve: .copper428, nominal: 100)
        let hot = try #require(copper.resistance(at: 100))
        #expect(abs(hot - 142.8) < 1e-9)
        let cold = try #require(copper.resistance(at: -50))
        #expect(abs(cold - 78.4551) < 1e-3)
        let restored = try #require(copper.temperature(for: 78.4551))
        #expect(abs(restored + 50) < 1e-3)
    }

    @Test("Вне диапазона — нет результата")
    func outOfRange() {
        #expect(RTDSensor(curve: .copper428, nominal: 50).resistance(at: 250) == nil)
        #expect(pt100.resistance(at: -250) == nil)
        #expect(pt100.temperature(for: 10) == nil)
        #expect(pt100.temperature(for: 500) == nil)
    }

    @Test("Чувствительность и W₁₀₀")
    func sensitivity() {
        #expect(abs(pt100.sensitivity(at: 0) - 0.390_83) < 1e-9)
        #expect(abs(pt100.w100 - 1.385_055) < 1e-6)
        #expect(abs(RTDSensor(curve: .copper428, nominal: 100).w100 - 1.428) < 1e-12)
    }

    @Test("Производная совпадает с численной", arguments: RTDCurve.allCases)
    func derivativeMatchesNumeric(curve: RTDCurve) {
        let step = 1e-4
        for t in [-150.0, -20.0, 50.0, 150.0] {
            let numeric = (curve.ratio(at: t + step) - curve.ratio(at: t - step)) / (2 * step)
            #expect(abs(curve.ratioDerivative(at: t) - numeric) < 1e-8)
        }
    }

    @Test("2 Ом линии на Pt100 при 0 °C дают ≈ +5,12 °C")
    func twoWireError() throws {
        let error = try #require(pt100.twoWireError(lineResistance: 2, at: 0))
        #expect(abs(error - 5.121) < 0.01)
        let noLine = try #require(pt100.twoWireError(lineResistance: 0, at: 50))
        #expect(abs(noLine) < 1e-6)
    }

    @Test("Таблица и маркировка")
    func tableAndNames() {
        let platinumTable = pt100.table(step: 50)
        #expect(platinumTable.count == 22)
        #expect(platinumTable.first?.temperature == -200)
        #expect(platinumTable.last?.temperature == 850)
        let copperTemperatures = RTDSensor(curve: .copper428, nominal: 50).table(step: 50).map(\.temperature)
        #expect(copperTemperatures == [-150, -100, -50, 0, 50, 100, 150, 200])
        #expect(pt100.name == "Pt100")
        #expect(RTDSensor(curve: .platinum391, nominal: 100).name == "100П")
        #expect(RTDSensor(curve: .copper428, nominal: 50).name == "50М")
    }
}
