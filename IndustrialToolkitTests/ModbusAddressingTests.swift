import Testing
@testable import IndustrialToolkit

@Suite("Адреса Modbus: форматы, кадр запроса, CRC")
struct ModbusAddressingTests {
    @Test(
        "Один и тот же регистр в разных записях",
        arguments: [
            (ModbusAddressNotation.reference, "40108"),
            (ModbusAddressNotation.reference, "400108"),
            (ModbusAddressNotation.offsetDecimal, "107"),
            (ModbusAddressNotation.offsetHex, "0x006B"),
            (ModbusAddressNotation.offsetHex, "6Bh"),
            (ModbusAddressNotation.offsetHex, "$6b"),
            (ModbusAddressNotation.offsetHex, "16#00_6B"),
            (ModbusAddressNotation.oneBased, "108"),
            (ModbusAddressNotation.schneider, "%MW107"),
            (ModbusAddressNotation.schneider, "%mw107"),
        ]
    )
    func sameRegister(notation: ModbusAddressNotation, text: String) throws {
        let input = try #require(ModbusAddressParser.parse(text, notation: notation, area: .holdingRegisters))
        #expect(input.address == ModbusAddress(area: .holdingRegisters, offset: 107))
        #expect(input.bit == nil)
    }

    @Test("Область из префикса и из выбора")
    func areas() {
        #expect(ModbusAddressParser.parse("30010", notation: .reference, area: .coils)?.address.area == .inputRegisters)
        #expect(ModbusAddressParser.parse("%M5", notation: .schneider, area: .holdingRegisters)?.address == ModbusAddress(area: .coils, offset: 5))
        #expect(ModbusAddressParser.parse("0x10", notation: .offsetHex, area: .discreteInputs)?.address == ModbusAddress(area: .discreteInputs, offset: 16))
    }

    @Test("Границы и мусор отклоняются")
    func invalid() {
        #expect(ModbusAddressParser.parse("0x10000", notation: .offsetHex, area: .holdingRegisters) == nil)
        #expect(ModbusAddressParser.parse("0", notation: .oneBased, area: .holdingRegisters) == nil)
        #expect(ModbusAddressParser.parse("65536", notation: .oneBased, area: .holdingRegisters)?.address.offset == 65_535)
        #expect(ModbusAddressParser.parse("65536", notation: .offsetDecimal, area: .holdingRegisters) == nil)
        #expect(ModbusAddressParser.parse("6G", notation: .offsetHex, area: .holdingRegisters) == nil)
        #expect(ModbusAddressParser.parse("%IW3", notation: .schneider, area: .holdingRegisters) == nil)
        #expect(ModbusAddressParser.parse("-1", notation: .offsetDecimal, area: .holdingRegisters) == nil)
        #expect(ModbusAddressParser.parse("", notation: .reference, area: .holdingRegisters) == nil)
    }

    @Test("Бит регистра")
    func bits() throws {
        let input = try #require(ModbusAddressParser.parse("40108.5", notation: .reference, area: .coils))
        #expect(input.bit == 5)
        let rows = input.address.rows(bit: input.bit)
        #expect(rows.contains(ModbusAddressRow(label: "Маска бита HEX", value: "0x0020")))
        #expect(rows.contains(ModbusAddressRow(label: "Schneider с битом", value: "%MW107.5")))
        #expect(ModbusAddressParser.parse("40108.16", notation: .reference, area: .coils) == nil)
        #expect(ModbusAddressParser.parse("00001.1", notation: .reference, area: .coils) == nil)
        #expect(ModbusAddressParser.parse("1.2.3", notation: .offsetDecimal, area: .holdingRegisters) == nil)
    }

    @Test("Перевод между форматами сохраняет адрес")
    func formatting() throws {
        let input = try #require(ModbusAddressParser.parse("%MW107.3", notation: .schneider, area: .coils))
        #expect(ModbusAddressParser.format(input, as: .reference) == "40108.3")
        #expect(ModbusAddressParser.format(input, as: .offsetHex) == "0x006B.3")
        #expect(ModbusAddressParser.format(input, as: .oneBased) == "108.3")
        let big = try #require(ModbusAddressParser.parse("0xFFFF", notation: .offsetHex, area: .holdingRegisters))
        #expect(ModbusAddressParser.format(big, as: .reference) == "465536")
        let inputRegister = try #require(ModbusAddressParser.parse("30001", notation: .reference, area: .coils))
        #expect(ModbusAddressParser.format(inputRegister, as: .schneider) == nil)
    }

    @Test("CRC-16/MODBUS по эталонным кадрам")
    func crc() throws {
        let address = try #require(ModbusAddress(area: .holdingRegisters, offset: 107))
        let request = try #require(ModbusReadRequest(address: address, quantity: 3))
        #expect(request.pdu == [0x03, 0x00, 0x6B, 0x00, 0x03])
        #expect(request.rtuFrame(unit: 0x11) == [0x11, 0x03, 0x00, 0x6B, 0x00, 0x03, 0x76, 0x87])

        let first = try #require(ModbusAddress(area: .holdingRegisters, offset: 0))
        let single = try #require(ModbusReadRequest(address: first, quantity: 1))
        #expect(ModbusReadRequest.hex(single.rtuFrame(unit: 1)) == "01 03 00 00 00 01 84 0A")
    }

    @Test("Кадр TCP и длина ответа")
    func tcpAndResponse() throws {
        let address = try #require(ModbusAddress(area: .holdingRegisters, offset: 107))
        let request = try #require(ModbusReadRequest(address: address, quantity: 3))
        #expect(request.tcpFrame(transaction: 1, unit: 0xFF) == [0x00, 0x01, 0x00, 0x00, 0x00, 0x06, 0xFF, 0x03, 0x00, 0x6B, 0x00, 0x03])
        #expect(request.rtuResponseLength == 11)
        #expect(request.tcpResponseLength == 15)

        let coils = try #require(ModbusAddress(area: .coils, offset: 19))
        let coilRequest = try #require(ModbusReadRequest(address: coils, quantity: 37))
        #expect(coilRequest.responseDataBytes == 5)
        #expect(ModbusReadRequest.hex(coilRequest.rtuFrame(unit: 1)) == "01 01 00 13 00 25 0C 14")
    }

    @Test("Лимиты количества по спецификации")
    func limits() throws {
        let register = try #require(ModbusAddress(area: .inputRegisters, offset: 0))
        #expect(ModbusReadRequest(address: register, quantity: 125) != nil)
        #expect(ModbusReadRequest(address: register, quantity: 126) == nil)
        #expect(ModbusReadRequest(address: register, quantity: 0) == nil)
        let coil = try #require(ModbusAddress(area: .discreteInputs, offset: 0))
        #expect(ModbusReadRequest(address: coil, quantity: 2_000) != nil)
        let top = try #require(ModbusAddress(area: .holdingRegisters, offset: 65_534))
        #expect(ModbusReadRequest(address: top, quantity: 2) != nil)
        #expect(ModbusReadRequest(address: top, quantity: 3) == nil)
        #expect(ModbusArea.holdingRegisters.maxWriteQuantity == 123)
        #expect(ModbusArea.coils.maxWriteQuantity == 1_968)
    }
}
