import Foundation

/// How the captured bytes are wrapped: serial RTU (address + PDU + CRC), TCP (MBAP + PDU) or a bare PDU.
enum ModbusFraming: String, CaseIterable, Identifiable {
    case rtu
    case tcp
    case pdu

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rtu: "RTU"
        case .tcp: "TCP"
        case .pdu: "PDU"
        }
    }
}

enum ModbusFrameError: Error, Equatable {
    case empty
    case invalidHex
    case tooShort(minimum: Int)
    case malformed(function: UInt8, detail: String)
    case unsupported(function: UInt8)

    var message: String {
        switch self {
        case .empty: "Вставьте байты кадра в HEX."
        case .invalidHex: "Допустимы HEX-байты: «11 03 06», «1103 06», «0x11,0x03»."
        case .tooShort(let minimum): "Кадр слишком короткий: нужно не меньше \(minimum) байт."
        case .malformed(let function, let detail): "Функция \(function.hexString(digits: 2)): \(detail)"
        case .unsupported(let function): "Функция 0x\(function.hexString(digits: 2)) не разбирается (поддерживаются 01–06, 0F, 10 и ошибки)."
        }
    }
}

/// Modbus Application Protocol v1.1b3, section 7.
struct ModbusExceptionCode: Equatable {
    let code: UInt8
    let name: String
    let hint: String

    static func describe(_ code: UInt8) -> ModbusExceptionCode {
        switch code {
        case 0x01: ModbusExceptionCode(code: code, name: "Illegal Function", hint: "Устройство не поддерживает эту функцию — например, FC04 вместо FC03.")
        case 0x02: ModbusExceptionCode(code: code, name: "Illegal Data Address", hint: "Адрес или диапазон вне карты устройства. Проверьте нумерацию с 0 / с 1 и количество.")
        case 0x03: ModbusExceptionCode(code: code, name: "Illegal Data Value", hint: "Недопустимое значение или количество в запросе.")
        case 0x04: ModbusExceptionCode(code: code, name: "Server Device Failure", hint: "Внутренняя ошибка устройства при выполнении запроса.")
        case 0x05: ModbusExceptionCode(code: code, name: "Acknowledge", hint: "Запрос принят, но выполняется долго; опросите позже.")
        case 0x06: ModbusExceptionCode(code: code, name: "Server Device Busy", hint: "Устройство занято, повторите запрос позже.")
        case 0x08: ModbusExceptionCode(code: code, name: "Memory Parity Error", hint: "Ошибка чётности памяти при чтении файловой записи.")
        case 0x0A: ModbusExceptionCode(code: code, name: "Gateway Path Unavailable", hint: "Шлюз не нашёл маршрут: проверьте Unit ID и настройки шлюза.")
        case 0x0B: ModbusExceptionCode(code: code, name: "Gateway Target Device Failed to Respond", hint: "Устройство за шлюзом не ответило: линия RS-485, адрес, скорость, чётность.")
        default: ModbusExceptionCode(code: code, name: "Неизвестный код", hint: "Код не описан в спецификации — смотрите документацию устройства.")
        }
    }
}

enum ModbusPDU: Equatable {
    case exception(function: UInt8, code: UInt8)
    case readBits(function: UInt8, values: [Bool])
    case readRegisters(function: UInt8, values: [UInt16])
    case readRequest(function: UInt8, address: Int, quantity: Int)
    case writeSingle(function: UInt8, address: Int, value: UInt16)
    case writeMultipleResponse(function: UInt8, address: Int, quantity: Int)
    case writeCoilsRequest(address: Int, quantity: Int, values: [Bool])
    case writeRegistersRequest(address: Int, quantity: Int, values: [UInt16])

    typealias Decoded = (body: ModbusPDU, warnings: [String])

    var function: UInt8 {
        switch self {
        case .exception(let function, _),
             .readBits(let function, _),
             .readRegisters(let function, _),
             .readRequest(let function, _, _),
             .writeSingle(let function, _, _),
             .writeMultipleResponse(let function, _, _):
            function
        case .writeCoilsRequest: 0x0F
        case .writeRegistersRequest: 0x10
        }
    }

    var area: ModbusArea? { Self.area(for: function) }

    /// Start address carried by the PDU itself (requests and write echoes).
    var startAddress: Int? {
        switch self {
        case .readRequest(_, let address, _),
             .writeSingle(_, let address, _),
             .writeMultipleResponse(_, let address, _),
             .writeCoilsRequest(let address, _, _),
             .writeRegistersRequest(let address, _, _):
            address
        case .exception, .readBits, .readRegisters:
            nil
        }
    }

    var kindTitle: String {
        switch self {
        case .exception: "Ответ с ошибкой"
        case .readBits, .readRegisters: "Ответ на чтение"
        case .readRequest: "Запрос чтения"
        case .writeSingle: "Запись одного (запрос или эхо-ответ)"
        case .writeMultipleResponse: "Ответ на групповую запись"
        case .writeCoilsRequest, .writeRegistersRequest: "Запрос групповой записи"
        }
    }

    static func functionName(_ function: UInt8) -> String {
        switch function {
        case 0x01: "Read Coils"
        case 0x02: "Read Discrete Inputs"
        case 0x03: "Read Holding Registers"
        case 0x04: "Read Input Registers"
        case 0x05: "Write Single Coil"
        case 0x06: "Write Single Register"
        case 0x0F: "Write Multiple Coils"
        case 0x10: "Write Multiple Registers"
        default: "Функция 0x\(function.hexString(digits: 2))"
        }
    }

    static func area(for function: UInt8) -> ModbusArea? {
        switch function {
        case 0x01, 0x05, 0x0F: .coils
        case 0x02: .discreteInputs
        case 0x03, 0x06, 0x10: .holdingRegisters
        case 0x04: .inputRegisters
        default: nil
        }
    }

    /// Decodes a PDU; `warnings` collects interpretations the bytes alone cannot settle.
    static func decode(_ pdu: [UInt8]) -> Result<Decoded, ModbusFrameError> {
        guard let function = pdu.first else { return .failure(.tooShort(minimum: 1)) }
        if function & 0x80 != 0 {
            guard pdu.count == 2 else {
                return .failure(.malformed(function: function, detail: "ответ с ошибкой — ровно 2 байта PDU (функция | 0x80, код)."))
            }
            return .success((body: .exception(function: function & 0x7F, code: pdu[1]), warnings: []))
        }
        switch function {
        case 0x01, 0x02, 0x03, 0x04:
            return decodeRead(function: function, pdu: pdu)
        case 0x05, 0x06:
            guard pdu.count == 5 else {
                return .failure(.malformed(function: function, detail: "ожидается 5 байт PDU: функция, адрес, значение."))
            }
            let value = word(pdu, at: 3)
            var warnings: [String] = []
            if function == 0x05 && value != 0xFF00 && value != 0x0000 {
                warnings.append("Для FC05 допустимы только FF00 (ВКЛ) и 0000 (ВЫКЛ).")
            }
            let body = ModbusPDU.writeSingle(function: function, address: Int(word(pdu, at: 1)), value: value)
            return .success((body: body, warnings: warnings))
        case 0x0F, 0x10:
            return decodeWriteMultiple(function: function, pdu: pdu)
        default:
            return .failure(.unsupported(function: function))
        }
    }

    private static func decodeRead(function: UInt8, pdu: [UInt8]) -> Result<Decoded, ModbusFrameError> {
        let isRegister = function == 0x03 || function == 0x04
        let request: ModbusPDU? = pdu.count == 5
            ? .readRequest(function: function, address: Int(word(pdu, at: 1)), quantity: Int(word(pdu, at: 3)))
            : nil
        let byteCount = pdu.count >= 2 ? Int(pdu[1]) : -1
        let isResponse = byteCount > 0 && pdu.count == 2 + byteCount && (!isRegister || byteCount.isMultiple(of: 2))
        guard isResponse else {
            if let request { return .success((body: request, warnings: [])) }
            let detail = "счётчик байт \(max(byteCount, 0)) не совпадает с длиной данных \(max(pdu.count - 2, 0))"
                + (isRegister ? " или нечётный." : ".")
            return .failure(.malformed(function: function, detail: detail))
        }
        let data = Array(pdu.dropFirst(2))
        let body: ModbusPDU = isRegister
            ? .readRegisters(function: function, values: registers(data))
            : .readBits(function: function, values: bits(data))
        var warnings: [String] = []
        if request != nil {
            warnings.append("Эти 5 байт также читаются как запрос: адрес \(word(pdu, at: 1)), количество \(word(pdu, at: 3)).")
        }
        return .success((body: body, warnings: warnings))
    }

    private static func decodeWriteMultiple(function: UInt8, pdu: [UInt8]) -> Result<Decoded, ModbusFrameError> {
        guard pdu.count >= 5 else {
            return .failure(.malformed(function: function, detail: "ожидается не меньше 5 байт PDU."))
        }
        let address = Int(word(pdu, at: 1))
        let quantity = Int(word(pdu, at: 3))
        if pdu.count == 5 {
            let body = ModbusPDU.writeMultipleResponse(function: function, address: address, quantity: quantity)
            return .success((body: body, warnings: []))
        }
        let byteCount = Int(pdu[5])
        let expected = function == 0x10 ? 2 * quantity : (quantity + 7) / 8
        guard pdu.count == 6 + byteCount, byteCount == expected else {
            let detail = "количество \(quantity) требует \(expected) байт данных, в кадре счётчик \(byteCount) и \(max(pdu.count - 6, 0)) байт."
            return .failure(.malformed(function: function, detail: detail))
        }
        let data = Array(pdu.dropFirst(6))
        let body: ModbusPDU = function == 0x10
            ? .writeRegistersRequest(address: address, quantity: quantity, values: registers(data))
            : .writeCoilsRequest(address: address, quantity: quantity, values: Array(bits(data).prefix(quantity)))
        return .success((body: body, warnings: []))
    }

    private static func word(_ bytes: [UInt8], at index: Int) -> UInt16 {
        (UInt16(bytes[index]) << 8) | UInt16(bytes[index + 1])
    }

    private static func registers(_ data: [UInt8]) -> [UInt16] {
        stride(from: 0, to: data.count - 1, by: 2).map { word(data, at: $0) }
    }

    /// Coil/input bits are packed least significant bit first: bit 0 of byte 0 is the first address.
    private static func bits(_ data: [UInt8]) -> [Bool] {
        data.flatMap { byte in (0..<8).map { (byte >> UInt8($0)) & 1 == 1 } }
    }
}

extension RegisterDataType {
    /// Splits consecutive registers into values of this type; a trailing incomplete group is dropped.
    func decodeAll(_ registers: [UInt16], order: ModbusByteOrder) -> [String] {
        stride(from: 0, through: registers.count - registerCount, by: registerCount).compactMap { start in
            decode(Array(registers[start..<(start + registerCount)]), order: order)
        }
    }
}

struct ModbusFrame: Equatable {
    struct CRCCheck: Equatable {
        let received: UInt16
        let computed: UInt16

        var isValid: Bool { received == computed }
    }

    let framing: ModbusFraming
    let unit: UInt8?
    let transactionID: UInt16?
    let crc: CRCCheck?
    let pdu: [UInt8]
    let body: ModbusPDU
    let warnings: [String]

    static func parse(_ text: String, framing: ModbusFraming) -> Result<ModbusFrame, ModbusFrameError> {
        guard !text.allSatisfy(\.isWhitespace) else { return .failure(.empty) }
        guard let bytes = bytes(fromHex: text) else { return .failure(.invalidHex) }
        return parse(bytes, framing: framing)
    }

    static func parse(_ bytes: [UInt8], framing: ModbusFraming) -> Result<ModbusFrame, ModbusFrameError> {
        var unit: UInt8?
        var transactionID: UInt16?
        var crc: CRCCheck?
        var warnings: [String] = []
        let pdu: [UInt8]
        switch framing {
        case .rtu:
            guard bytes.count >= 4 else { return .failure(.tooShort(minimum: 4)) }
            let body = Array(bytes.dropLast(2))
            let received = UInt16(bytes[bytes.count - 2]) | (UInt16(bytes[bytes.count - 1]) << 8)
            let check = CRCCheck(received: received, computed: ModbusReadRequest.crc16(body))
            if !check.isValid {
                warnings.append("CRC не сходится: помехи на линии, обрезанный кадр или неверная скорость/чётность.")
            }
            unit = body[0]
            crc = check
            pdu = Array(body.dropFirst())
        case .tcp:
            guard bytes.count >= 9 else { return .failure(.tooShort(minimum: 9)) }
            transactionID = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            let protocolID = (UInt16(bytes[2]) << 8) | UInt16(bytes[3])
            let length = (Int(bytes[4]) << 8) | Int(bytes[5])
            if protocolID != 0 {
                warnings.append("Protocol ID \(protocolID) ≠ 0 — это не Modbus TCP.")
            }
            if length != bytes.count - 6 {
                warnings.append("Поле Length = \(length), а после него \(bytes.count - 6) байт: кадр обрезан или склеен с соседним.")
            }
            unit = bytes[6]
            pdu = Array(bytes.dropFirst(7))
        case .pdu:
            guard bytes.count >= 2 else { return .failure(.tooShort(minimum: 2)) }
            pdu = bytes
        }
        switch ModbusPDU.decode(pdu) {
        case .failure(let error):
            return .failure(error)
        case .success(let decoded):
            return .success(ModbusFrame(
                framing: framing,
                unit: unit,
                transactionID: transactionID,
                crc: crc,
                pdu: pdu,
                body: decoded.body,
                warnings: warnings + decoded.warnings
            ))
        }
    }

    /// Accepts bytes separated by spaces, commas, colons or dashes, optional 0x prefixes,
    /// or one continuous run of hex digits.
    static func bytes(fromHex text: String) -> [UInt8]? {
        let separators = CharacterSet(charactersIn: " \t\r\n,;:-")
        let tokens = text.components(separatedBy: separators).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }
        var result: [UInt8] = []
        for token in tokens {
            let digits = token.lowercased().hasPrefix("0x") ? String(token.dropFirst(2)) : token
            guard !digits.isEmpty, digits.allSatisfy(\.isHexDigit) else { return nil }
            if digits.count == 1 {
                guard let value = UInt8(digits, radix: 16) else { return nil }
                result.append(value)
                continue
            }
            guard digits.count.isMultiple(of: 2) else { return nil }
            var index = digits.startIndex
            while index < digits.endIndex {
                let next = digits.index(index, offsetBy: 2)
                guard let value = UInt8(digits[index..<next], radix: 16) else { return nil }
                result.append(value)
                index = next
            }
        }
        return result
    }
}
