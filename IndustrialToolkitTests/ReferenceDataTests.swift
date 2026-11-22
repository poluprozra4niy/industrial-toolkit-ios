import Testing
@testable import IndustrialToolkit

@Suite("Код IP, ГОСТ 14254-2015")
struct IPRatingTests {
    @Test("Разбор кодов")
    func parsing() throws {
        let ip65 = try #require(IPRating.parse("IP65")?.first)
        #expect(ip65.first == 6)
        #expect(ip65.second == 5)
        let ipx7 = try #require(IPRating.parse("ipx7")?.first)
        #expect(ipx7.first == nil)
        #expect(ipx7.second == 7)
        let letters = try #require(IPRating.parse("IP2XC")?.first)
        #expect(letters.second == nil)
        #expect(letters.additional == "C")
        #expect(IPRating.parse("IP54M")?.first?.supplementary == ["M"])
        #expect(IPRating.parse("IP66/IP67")?.count == 2)
        #expect(IPRating.parse("IP7X") == nil)
        #expect(IPRating.parse("IP6") == nil)
        #expect(IPRating.parse("IP65Q") == nil)
        #expect(IPRating.parse("IP54MM") == nil)
    }

    @Test("Предупреждения о погружении и струях")
    func waterNotes() throws {
        let immersionOnly = try #require(IPRating.parse("IP67"))
        #expect(IPRating.waterNotes(for: immersionOnly).contains { $0.contains("не от струй") })
        let dual = try #require(IPRating.parse("IP66/IP67"))
        #expect(IPRating.waterNotes(for: dual).contains { $0.contains("Двойная") })
        let highPressure = try #require(IPRating.parse("IPX9"))
        #expect(IPRating.waterNotes(for: highPressure).contains { $0.contains("IPX9") })
        let jets = try #require(IPRating.parse("IP65"))
        #expect(IPRating.waterNotes(for: jets).isEmpty)
    }

    @Test("Таблицы полные")
    func tables() {
        #expect(IPRating.solids.map(\.code) == ["0", "1", "2", "3", "4", "5", "6"])
        #expect(IPRating.water.count == 10)
        #expect(IPRating.solid(6)?.title == "Пыленепроницаемо")
    }
}

@Suite("Цвета проводников, ГОСТ Р 50462-2009")
struct ConductorColorsTests {
    @Test("PE жёлто-зелёный, N синий, PEN — две схемы")
    func keyConductors() throws {
        let pe = try #require(ConductorColors.markings.first { $0.designation == "PE" })
        #expect(pe.colorings == [ConductorColoring(main: .yellowGreen, marks: nil)])
        let neutral = try #require(ConductorColors.markings.first { $0.designation == "N" })
        #expect(neutral.colorings.first?.main == .blue)
        let pen = try #require(ConductorColors.markings.first { $0.designation == "PEN" })
        #expect(pen.colorings.count == 2)
        #expect(!ConductorColors.permittedColors.contains(.yellowGreen))
    }
}

@Suite("Автоматы, ГОСТ IEC 60898-1-2020")
struct BreakerTests {
    @Test("C16: мгновенное расцепление 80…160 А")
    func c16() {
        let breaker = BreakerSelection(curve: .c, rating: 16)
        #expect(breaker.name == "C16")
        #expect(breaker.instantaneousLower == 80)
        #expect(breaker.instantaneousUpper == 160)
        #expect(abs(breaker.nonTrippingCurrent - 18.08) < 1e-9)
        #expect(abs(breaker.trippingCurrent - 23.2) < 1e-9)
        #expect(breaker.conventionalTime == "1 ч")
        #expect(breaker.thermalTestWindow == "1 с < t < 60 с")
    }

    @Test("Пороги времени для больших номиналов")
    func largeRatings() {
        #expect(BreakerSelection(curve: .b, rating: 40).thermalTestWindow == "1 с < t < 120 с")
        #expect(BreakerSelection(curve: .b, rating: 80).conventionalTime == "2 ч")
        #expect(BreakerSelection(curve: .d, rating: 10).instantaneousUpper == 200)
    }

    @Test("Петля фаза–ноль")
    func loopCheck() throws {
        let breaker = BreakerSelection(curve: .c, rating: 16)
        let current = try #require(BreakerSelection.faultCurrent(phaseVoltage: 230, loopImpedance: 1))
        #expect(current == 230)
        #expect(breaker.verdict(faultCurrent: current) == .guaranteed)
        #expect(breaker.verdict(faultCurrent: 120) == .uncertain)
        #expect(breaker.verdict(faultCurrent: 80) == .thermalOnly)
        let maxImpedance = try #require(breaker.maximumLoopImpedance(phaseVoltage: 230))
        #expect(abs(maxImpedance - 1.4375) < 1e-9)
    }
}

@Suite("Сечение по допустимому току, ПУЭ 1.3.4–1.3.7")
struct CableAmpacityTests {
    @Test("Медные провода, 3 в трубе")
    func copperWiresInPipe() throws {
        let exact = try #require(CableAmpacity.minimumSection(for: 25, material: .copper, laying: .wiresPipe3))
        #expect(exact.section == 2.5)
        #expect(exact.ampacity == 25)
        let next = try #require(CableAmpacity.minimumSection(for: 26, material: .copper, laying: .wiresPipe3))
        #expect(next.section == 3)
    }

    @Test("Табличные значения сверены с текстом ПУЭ")
    func spotChecks() {
        let copperOpen = CableAmpacity.entries(material: .copper, laying: .wiresOpen)
        #expect(copperOpen.first { $0.section == 1.5 }?.ampacity == 23)
        #expect(copperOpen.first { $0.section == 400 }?.ampacity == 830)
        let aluminiumOpen = CableAmpacity.entries(material: .aluminium, laying: .wiresOpen)
        #expect(aluminiumOpen.first { $0.section == 16 }?.ampacity == 75)
        let copperCableGround = CableAmpacity.entries(material: .copper, laying: .cableThreeGround)
        #expect(copperCableGround.first { $0.section == 2.5 }?.ampacity == 38)
        let aluminiumCableAir = CableAmpacity.entries(material: .aluminium, laying: .cableThreeAir)
        #expect(aluminiumCableAir.first { $0.section == 25 }?.ampacity == 75)
        #expect(CableAmpacity.tableNumber(material: .aluminium, laying: .cableTwoGround) == "1.3.7")
    }

    @Test("Пучок 5–6 проводов: открытая прокладка × 0,68; для кабелей не применяется")
    func bundleReduction() throws {
        let entries = CableAmpacity.entries(material: .copper, laying: .wiresPipe3, bundle: .fiveToSix)
        let twoAndHalf = try #require(entries.first { $0.section == 2.5 })
        #expect(abs(twoAndHalf.ampacity - 20.4) < 1e-9)
        #expect(CableAmpacity.entries(material: .copper, laying: .cableThreeAir, bundle: .tenToTwelve).first?.ampacity == 19)
    }

    @Test("Ток больше табличного максимума")
    func tooLarge() {
        #expect(CableAmpacity.minimumSection(for: 400, material: .copper, laying: .wiresPipe3) == nil)
        #expect(CableAmpacity.minimumSection(for: 0, material: .copper, laying: .wiresOpen) == nil)
    }
}

@Suite("Термопара K, NIST ITS-90")
struct ThermocoupleTests {
    @Test(
        "Границы диапазонов обратных функций NIST",
        arguments: [(0.0, 0.0), (20.644, 500.0), (54.886, 1372.0), (-5.891, -200.0)]
    )
    func segmentBoundaries(emf: Double, expected: Double) throws {
        let temperature = try #require(ThermocoupleTypeK.temperature(millivolts: emf))
        #expect(abs(temperature - expected) < 0.1)
    }

    @Test("100 °C ≈ 4,096 мВ (таблица NIST)")
    func hundredDegrees() throws {
        let emf = try #require(ThermocoupleTypeK.millivolts(temperature: 100))
        #expect(abs(emf - 4.096) < 0.003)
    }

    @Test("Обратимость t → E → t", arguments: [-150.0, 0.0, 25.0, 350.0, 800.0, 1200.0])
    func roundTrip(temperature: Double) throws {
        let emf = try #require(ThermocoupleTypeK.millivolts(temperature: temperature))
        let restored = try #require(ThermocoupleTypeK.temperature(millivolts: emf))
        #expect(abs(restored - temperature) < 1e-4)
    }

    @Test("Компенсация холодного спая")
    func coldJunction() throws {
        let measured = try #require(ThermocoupleTypeK.measuredMillivolts(temperature: 300, coldJunction: 25))
        let restored = try #require(ThermocoupleTypeK.temperature(measuredMillivolts: measured, coldJunction: 25))
        #expect(abs(restored - 300) < 1e-4)
        #expect(ThermocoupleTypeK.temperature(millivolts: 60) == nil)
        #expect(ThermocoupleTypeK.millivolts(temperature: 1400) == nil)
    }

    @Test("Чувствительность около 41 мкВ/°C при 100 °C")
    func sensitivity() throws {
        let value = try #require(ThermocoupleTypeK.sensitivity(temperature: 100))
        #expect(value > 40 && value < 43)
    }
}
