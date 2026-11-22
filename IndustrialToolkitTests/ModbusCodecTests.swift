import Testing
@testable import IndustrialToolkit

@Suite("Регистры Modbus: типы, порядок байт, адресация")
struct ModbusCodecTests {
    @Test("32 бита: совпадает с Float32Word во всех порядках", arguments: ModbusByteOrder.allCases)
    func matchesFloat32Word(order: ModbusByteOrder) {
        let word = Float32Word(bits: 0x4049_0FDB)
        let expected = word.registers(order: order)
        let registers = ModbusCodec.registers(fromBigEndian: word.bytes, order: order)
        #expect(registers == [expected.first, expected.second])
        #expect(ModbusCodec.bigEndianBytes(fromRegisters: registers, order: order) == word.bytes)
    }

    @Test("64 бита: порядок регистров для байтов 01…08")
    func sixtyFourBitOrders() {
        let bytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
        #expect(ModbusCodec.registers(fromBigEndian: bytes, order: .abcd) == [0x0102, 0x0304, 0x0506, 0x0708])
        #expect(ModbusCodec.registers(fromBigEndian: bytes, order: .badc) == [0x0201, 0x0403, 0x0605, 0x0807])
        #expect(ModbusCodec.registers(fromBigEndian: bytes, order: .cdab) == [0x0708, 0x0506, 0x0304, 0x0102])
        #expect(ModbusCodec.registers(fromBigEndian: bytes, order: .dcba) == [0x0807, 0x0605, 0x0403, 0x0201])
    }

    @Test("Подписи порядка байт")
    func wireLabels() {
        #expect(ModbusCodec.wireLabel(order: .cdab, byteCount: 4) == "CDAB")
        #expect(ModbusCodec.wireLabel(order: .abcd, byteCount: 8) == "ABCDEFGH")
        #expect(ModbusCodec.wireLabel(order: .badc, byteCount: 8) == "BADCFEHG")
        #expect(ModbusCodec.wireLabel(order: .cdab, byteCount: 8) == "GHEFCDAB")
        #expect(ModbusCodec.wireLabel(order: .dcba, byteCount: 8) == "HGFEDCBA")
        #expect(ModbusCodec.distinctOrders(registerCount: 1) == [.abcd, .badc])
    }

    @Test("INT32 −100000 ↔ регистры FFFE 7960")
    func int32RoundTrip() throws {
        let bytes = try #require(RegisterDataType.int32.encode("-100000"))
        #expect(bytes == [0xFF, 0xFE, 0x79, 0x60])
        #expect(ModbusCodec.registers(fromBigEndian: bytes, order: .cdab) == [0x7960, 0xFFFE])
        #expect(RegisterDataType.int32.decode([0xFFFE, 0x7960], order: .abcd) == "-100000")
        #expect(RegisterDataType.uint32.decode([0xFFFE, 0x7960], order: .abcd) == "4294867296")
        #expect(RegisterDataType.int32.decode([0x7960, 0xFFFE], order: .cdab) == "-100000")
    }

    @Test("16 бит и биты регистра")
    func sixteenBit() {
        #expect(RegisterDataType.int16.decode([0xFFFF], order: .abcd) == "-1")
        #expect(RegisterDataType.uint16.decode([0xFFFF], order: .abcd) == "65535")
        #expect(RegisterDataType.uint16.decode([0x0100], order: .badc) == "1")
        #expect(ModbusCodec.groupedBinary(0x4049) == "0100 0000 0100 1001")
    }

    @Test("FLOAT64 1.0 = 3FF0 0000 0000 0000")
    func float64() throws {
        let bytes = try #require(RegisterDataType.float64.encode("1"))
        #expect(ModbusCodec.registers(fromBigEndian: bytes, order: .abcd) == [0x3FF0, 0, 0, 0])
        #expect(RegisterDataType.float64.decode([0x3FF0, 0, 0, 0], order: .abcd) == "1.0")
        #expect(RegisterDataType.float32.encode("1") == [0x3F, 0x80, 0x00, 0x00])
    }

    @Test("Нехватка регистров → нет значения")
    func notEnoughRegisters() {
        #expect(RegisterDataType.float32.decode([0x4049], order: .abcd) == nil)
        #expect(RegisterDataType.int64.decode([1, 2, 3], order: .abcd) == nil)
    }

    @Test("Диапазоны целых типов и HEX-битовые шаблоны")
    func integerRanges() {
        #expect(RegisterDataType.int16.encode("40000") == nil)
        #expect(RegisterDataType.int16.encode("-32768") == [0x80, 0x00])
        #expect(RegisterDataType.uint16.encode("65535") == [0xFF, 0xFF])
        #expect(RegisterDataType.uint16.encode("-1") == nil)
        #expect(RegisterDataType.uint32.encode("0xFFFFFFFF") == [0xFF, 0xFF, 0xFF, 0xFF])
        #expect(RegisterDataType.uint32.encode("0x1FFFFFFFF") == nil)
        #expect(RegisterDataType.int64.encode("-1") == Array(repeating: 0xFF, count: 8))
        #expect(RegisterDataType.int32.encode("abc") == nil)
    }

    @Test("Адрес 4xxxx ↔ смещение PDU")
    func addressing() throws {
        let first = try #require(ModbusAddress(reference: "40001"))
        #expect(first.area == .holdingRegisters)
        #expect(first.offset == 0)
        #expect(ModbusAddress(reference: "30010")?.area == .inputRegisters)
        #expect(ModbusAddress(reference: "30010")?.offset == 9)
        #expect(ModbusAddress(reference: "400001")?.offset == 0)
        #expect(ModbusAddress(reference: "465536")?.offset == 65_535)
        #expect(ModbusAddress(reference: "20001") == nil)
        #expect(ModbusAddress(reference: "40000") == nil)
        #expect(ModbusAddress(reference: "4001") == nil)
        #expect(ModbusAddress(reference: "4o001") == nil)

        let address = try #require(ModbusAddress(area: .holdingRegisters, offset: 107))
        #expect(address.fiveDigitReference == "40108")
        #expect(address.sixDigitReference == "400108")
        #expect(ModbusAddress(area: .coils, offset: 9_999)?.fiveDigitReference == nil)
        #expect(ModbusAddress(area: .coils, offset: 65_536) == nil)
    }
}
