import Testing
@testable import IndustrialToolkit

@Suite("Разбор кадров Modbus")
struct ModbusFrameDecoderTests {
    private func decode(_ text: String, _ framing: ModbusFraming = .rtu) throws -> ModbusFrame {
        switch ModbusFrame.parse(text, framing: framing) {
        case .success(let frame): return frame
        case .failure(let error): throw error
        }
    }

    @Test("Разбор HEX-строки в любых записях")
    func hexInput() {
        #expect(ModbusFrame.bytes(fromHex: "11 03 06") == [0x11, 0x03, 0x06])
        #expect(ModbusFrame.bytes(fromHex: "110306") == [0x11, 0x03, 0x06])
        #expect(ModbusFrame.bytes(fromHex: "0x11,0x3, 0x06") == [0x11, 0x03, 0x06])
        #expect(ModbusFrame.bytes(fromHex: "11:03-06\n") == [0x11, 0x03, 0x06])
        #expect(ModbusFrame.bytes(fromHex: "1103 0") == [0x11, 0x03, 0x00])
        #expect(ModbusFrame.bytes(fromHex: "110") == nil)
        #expect(ModbusFrame.bytes(fromHex: "11 G3") == nil)
        #expect(ModbusFrame.parse("  ", framing: .rtu) == .failure(.empty))
    }

    @Test("Ответ FC03 из спецификации: регистры 108…110")
    func readRegistersResponse() throws {
        let frame = try decode("11 03 06 02 2B 00 00 00 64 C8 BA")
        #expect(frame.unit == 0x11)
        #expect(frame.crc?.isValid == true)
        #expect(frame.body == .readRegisters(function: 0x03, values: [0x022B, 0x0000, 0x0064]))
        #expect(frame.warnings.isEmpty)
    }

    @Test("Неверный CRC — предупреждение, данные всё равно разобраны")
    func badCRC() throws {
        let frame = try decode("11 03 06 02 2B 00 00 00 64 C8 BB")
        let crc = try #require(frame.crc)
        #expect(!crc.isValid)
        #expect(crc.computed == 0xBAC8)
        #expect(frame.warnings.contains { $0.contains("CRC") })
        #expect(frame.body.function == 0x03)
    }

    @Test("Ответ с ошибкой 02")
    func exception() throws {
        let frame = try decode("11 83 02 C1 34")
        #expect(frame.body == .exception(function: 0x03, code: 0x02))
        #expect(ModbusExceptionCode.describe(0x02).name == "Illegal Data Address")
        #expect(ModbusExceptionCode.describe(0x0B).name.hasPrefix("Gateway Target"))
    }

    @Test("Запрос чтения отличается от ответа по счётчику байт")
    func readRequest() throws {
        let frame = try decode("11 03 00 6B 00 03 76 87")
        #expect(frame.body == .readRequest(function: 0x03, address: 107, quantity: 3))
        #expect(frame.body.startAddress == 107)
    }

    @Test("FC01: биты младшим разрядом вперёд; двусмысленные 5 байт")
    func readCoils() throws {
        let frame = try decode("01 01 03 CD 6B 05 42 82")
        guard case .readBits(_, let values) = frame.body else {
            Issue.record("ожидался ответ с битами")
            return
        }
        #expect(values.count == 24)
        #expect(Array(values.prefix(8)) == [true, false, true, true, false, false, true, true])
        #expect(frame.warnings.contains { $0.contains("запрос") })
    }

    @Test("Запись: FC06 эхо и FC16 запрос")
    func writes() throws {
        let single = try decode("01 06 00 01 00 03 98 0B")
        #expect(single.body == .writeSingle(function: 0x06, address: 1, value: 3))
        let multiple = try decode("01 10 00 01 00 02 04 00 0A 01 02 92 30")
        #expect(multiple.body == .writeRegistersRequest(address: 1, quantity: 2, values: [0x000A, 0x0102]))
        let response = try decode("10 00 01 00 02", .pdu)
        #expect(response.body == .writeMultipleResponse(function: 0x10, address: 1, quantity: 2))
        guard case .failure(.malformed) = ModbusFrame.parse("10 00 01 00 02 04 00 0A", framing: .pdu) else {
            Issue.record("ожидалась ошибка длины данных FC16")
            return
        }
    }

    @Test("Modbus TCP: MBAP и проверка Length")
    func tcp() throws {
        let frame = try decode("00 01 00 00 00 09 FF 03 06 02 2B 00 00 00 64", .tcp)
        #expect(frame.transactionID == 1)
        #expect(frame.unit == 0xFF)
        #expect(frame.warnings.isEmpty)
        #expect(frame.body == .readRegisters(function: 0x03, values: [0x022B, 0, 0x0064]))
        let truncated = try decode("00 01 00 00 00 0B FF 03 06 02 2B 00 00 00 64", .tcp)
        #expect(truncated.warnings.contains { $0.contains("Length") })
    }

    @Test("Ошибки разбора")
    func failures() {
        #expect(ModbusFrame.parse("11 03 C8", framing: .rtu) == .failure(.tooShort(minimum: 4)))
        #expect(ModbusFrame.parse("2B 00", framing: .pdu) == .failure(.unsupported(function: 0x2B)))
        guard case .failure(.malformed) = ModbusFrame.parse("03 05 00 00 00 00 00", framing: .pdu) else {
            Issue.record("нечётный счётчик байт для регистров должен отклоняться")
            return
        }
    }

    @Test("Группировка регистров в FLOAT32")
    func decodeAll() {
        let registers: [UInt16] = [0x4049, 0x0FDB, 0x3F80, 0x0000, 0x1234]
        #expect(RegisterDataType.float32.decodeAll(registers, order: .abcd) == ["3.1415927", "1.0"])
        #expect(RegisterDataType.uint16.decodeAll([1, 2], order: .abcd) == ["1", "2"])
        #expect(RegisterDataType.float64.decodeAll([1, 2], order: .abcd).isEmpty)
    }
}
