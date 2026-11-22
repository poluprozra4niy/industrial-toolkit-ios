import Testing
@testable import IndustrialToolkit

@Suite("Масштабирование аналоговых сигналов")
struct SignalScaleTests {
    private func scale(
        _ signal: SignalRange = .mA4to20,
        low: Double = 0,
        high: Double = 10,
        squareRoot: Bool = false
    ) throws -> SignalScale {
        try #require(SignalScale(signal: signal, raw: .siemensS7, low: low, high: high, squareRoot: squareRoot))
    }

    @Test("12 мА на шкале 0…10 бар = 5 бар, код S7 13824")
    func midScale() throws {
        let result = try scale().convert(signal: 12)
        #expect(abs(result.processValue - 5) < 1e-9)
        #expect(abs(result.signalFraction - 0.5) < 1e-9)
        #expect(abs(result.rawCounts - 13_824) < 1e-9)
        #expect(result.health == .normal)
    }

    @Test("Границы шкалы: 4 мА = НПИ, 20 мА = ВПИ")
    func endpoints() throws {
        let scale = try scale()
        #expect(abs(scale.convert(signal: 4).processValue) < 1e-9)
        #expect(abs(scale.convert(signal: 20).processValue - 10) < 1e-9)
    }

    @Test("Обратный расчёт: 2,5 бар → 8 мА")
    func processToSignal() throws {
        let result = try scale().convert(processValue: 2.5)
        #expect(abs(result.signal - 8) < 1e-9)
    }

    @Test("Код АЦП 27648 → ВПИ")
    func rawToProcess() throws {
        let result = try scale().convert(rawCounts: 27_648)
        #expect(abs(result.processValue - 10) < 1e-9)
        #expect(abs(result.signal - 20) < 1e-9)
    }

    @Test("Корнеизвлечение: 25 % сигнала = 50 % расхода и обратно")
    func squareRootExtraction() throws {
        let scale = try scale(squareRoot: true)
        let forward = scale.convert(signal: 8)
        #expect(abs(forward.processValue - 5) < 1e-9)
        #expect(abs(forward.processFraction - 0.5) < 1e-9)
        let backward = scale.convert(processValue: 5)
        #expect(abs(backward.signal - 8) < 1e-9)
    }

    @Test("Обратная шкала 100…0: 4 мА = 100")
    func reversedScale() throws {
        let result = try scale(low: 100, high: 0).convert(signal: 4)
        #expect(abs(result.processValue - 100) < 1e-9)
    }

    @Test("Совпадающие НПИ и ВПИ отклоняются")
    func degenerateScale() {
        #expect(SignalScale(signal: .mA4to20, raw: .siemensS7, low: 5, high: 5, squareRoot: false) == nil)
    }

    @Test(
        "Диагностика 4–20 мА по NAMUR NE43",
        arguments: [
            (3.5, SignalHealth.failureLow),
            (3.7, .underRange),
            (3.9, .normal),
            (12.0, .normal),
            (20.7, .overRange),
            (21.5, .failureHigh),
        ]
    )
    func namur(value: Double, expected: SignalHealth) {
        #expect(SignalHealth.evaluate(value, in: .mA4to20) == expected)
    }

    @Test("Диагностика вольтовых сигналов")
    func voltageHealth() {
        #expect(SignalHealth.evaluate(10.2, in: .v0to10) == .overRange)
        #expect(SignalHealth.evaluate(0.5, in: .v2to10) == .failureLow)
        #expect(SignalHealth.evaluate(1.5, in: .v2to10) == .underRange)
        #expect(SignalHealth.evaluate(5, in: .v0to10) == .normal)
    }

    @Test("Таблица loop check: 5 точек 0…100 %")
    func loopCheckTable() throws {
        let rows = try scale().loopCheckTable
        #expect(rows.map(\.signal) == [4, 8, 12, 16, 20])
        #expect(rows.map(\.processValue) == [0, 2.5, 5, 7.5, 10])
    }
}

@Suite("Парсер чисел")
struct NumberParserTests {
    @Test(
        "Запятая, точка, пробелы, минус Unicode",
        arguments: [
            ("12,5", 12.5),
            ("12.5", 12.5),
            (" 1 000,5 ", 1000.5),
            ("−3", -3.0),
            ("1e-6", 0.000001),
        ]
    )
    func parsesVariants(text: String, expected: Double) {
        #expect(NumberParser.parse(text) == expected)
    }

    @Test("Мусор и пустая строка → nil")
    func rejectsGarbage() {
        #expect(NumberParser.parse("abc") == nil)
        #expect(NumberParser.parse("") == nil)
        #expect(NumberParser.parse("1,2,3") == nil)
    }

    @Test("inf/nan только при явном разрешении")
    func nonFinite() {
        #expect(NumberParser.parse("inf") == nil)
        #expect(NumberParser.parse("inf", allowNonFinite: true) == .infinity)
    }
}
