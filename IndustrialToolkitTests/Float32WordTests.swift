import Testing
@testable import IndustrialToolkit

@Suite("IEEE 754 float32 и порядок байт Modbus")
struct Float32WordTests {
    private static let piRegisters: [(ModbusByteOrder, UInt16, UInt16)] = [
        (.abcd, 0x4049, 0x0FDB),
        (.badc, 0x4940, 0xDB0F),
        (.cdab, 0x0FDB, 0x4049),
        (.dcba, 0xDB0F, 0x4940),
    ]

    @Test("π кодируется как 0x40490FDB")
    func piBits() {
        let word = Float32Word(value: .pi)
        #expect(word.bits == 0x4049_0FDB)
        #expect(word.hex == "40490FDB")
        #expect(word.bytes == [0x40, 0x49, 0x0F, 0xDB])
    }

    @Test("Регистры π во всех порядках байт", arguments: piRegisters)
    func registersForEachOrder(order: ModbusByteOrder, first: UInt16, second: UInt16) {
        let registers = Float32Word(value: .pi).registers(order: order)
        #expect(registers.first == first)
        #expect(registers.second == second)
        #expect(Float32Word(registers: first, second, order: order).value == .pi)
    }

    @Test("Регистры → float → регистры без потерь", arguments: ModbusByteOrder.allCases)
    func registersRoundTrip(order: ModbusByteOrder) {
        let samples: [Float] = [0, -0.0, 1, -273.15, 1e-40, .greatestFiniteMagnitude, .infinity]
        for value in samples {
            let word = Float32Word(value: value)
            let registers = word.registers(order: order)
            #expect(Float32Word(registers: registers.first, registers.second, order: order) == word)
        }
    }

    @Test("Классификация значений")
    func classification() {
        #expect(Float32Word(value: 0).floatClass == .zero)
        #expect(Float32Word(value: .leastNonzeroMagnitude).floatClass == .subnormal)
        #expect(Float32Word(value: 1).floatClass == .normal)
        #expect(Float32Word(value: -.infinity).floatClass == .infinity)
        #expect(Float32Word(value: .nan).floatClass == .quietNaN)
        #expect(Float32Word(bits: 0x7F80_0001).floatClass == .signalingNaN)
    }

    @Test("Разбор 1.0: порядок 0, мантисса 1")
    func fieldsOfOne() {
        let word = Float32Word(value: 1)
        #expect(word.sign == 0)
        #expect(word.biasedExponent == 127)
        #expect(word.exponent == 0)
        #expect(word.significand == 1)
        #expect(word.binaryGrouped == "0 01111111 00000000000000000000000")
    }

    @Test("Инверсия бита знака превращает 1 в −1")
    func toggleSignBit() {
        let word = Float32Word(value: 1).togglingBit(31)
        #expect(word.value == -1)
        #expect(word.isBitSet(31))
    }

    @Test("Разбор HEX")
    func hexParsing() {
        #expect(Float32Word(hex: "0x3F80_0000")?.value == 1)
        #expect(Float32Word(hex: "3f800000")?.value == 1)
        #expect(Float32Word(hex: "4049 0FDB")?.value == .pi)
        #expect(Float32Word(hex: "XYZ") == nil)
        #expect(Float32Word(hex: "123456789") == nil)
        #expect(Float32Word(hex: "") == nil)
    }

    @Test("Разбор регистров: десятичные, знаковые, HEX")
    func registerParsing() {
        #expect(Float32Word.parseRegister("16457", hex: false) == 0x4049)
        #expect(Float32Word.parseRegister("-1", hex: false) == 0xFFFF)
        #expect(Float32Word.parseRegister("−32768", hex: false) == 0x8000)
        #expect(Float32Word.parseRegister("65536", hex: false) == nil)
        #expect(Float32Word.parseRegister("0x4049", hex: false) == 0x4049)
        #expect(Float32Word.parseRegister("0fdb", hex: true) == 0x0FDB)
        #expect(Float32Word.parseRegister("12345", hex: true) == nil)
    }
}
