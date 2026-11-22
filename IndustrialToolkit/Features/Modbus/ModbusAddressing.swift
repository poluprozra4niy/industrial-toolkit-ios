import Foundation

/// How an address is written in device manuals, SCADA tags or PLC code.
enum ModbusAddressNotation: String, CaseIterable, Identifiable {
    /// Modicon reference: 40108 / 400108, area from the leading digit.
    case reference
    /// 0-based offset as transmitted in the PDU.
    case offsetDecimal
    /// Same offset in hex: 0x006B, 006Bh, $6B, 16#006B.
    case offsetHex
    /// Register number counted from 1 (offset + 1).
    case oneBased
    /// Schneider Control Expert / Unity: %MW107 = holding register offset 107, %M107 = coil 107.
    case schneider

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reference: "4xxxx"
        case .offsetDecimal: "DEC с 0"
        case .offsetHex: "HEX с 0"
        case .oneBased: "DEC с 1"
        case .schneider: "%MW"
        }
    }

    var subtitle: String {
        switch self {
        case .reference: "Modicon"
        case .offsetDecimal, .offsetHex: "смещение PDU"
        case .oneBased: "номер"
        case .schneider: "Schneider"
        }
    }

    /// Notations without an area prefix need the area chosen separately.
    var needsArea: Bool {
        switch self {
        case .offsetDecimal, .offsetHex, .oneBased: true
        case .reference, .schneider: false
        }
    }

    var hint: String {
        switch self {
        case .reference: "40001…49999 или 400001…465536; первая цифра 0, 1, 3, 4. Бит регистра: 40108.5"
        case .offsetDecimal: "0…65535 — как передаётся в пакете. Бит: 107.5"
        case .offsetHex: "0000…FFFF; принимаются 0x6B, 6Bh, $6B, 16#6B. Бит: 0x6B.5"
        case .oneBased: "1…65536 — «регистр N» в паспортах приборов"
        case .schneider: "%MW0…%MW65535 — регистры, %M0…%M65535 — coils. Бит: %MW107.5"
        }
    }
}

extension ModbusArea {
    var isRegister: Bool { self == .inputRegisters || self == .holdingRegisters }

    var readFunctionCode: UInt8 {
        switch self {
        case .coils: 0x01
        case .discreteInputs: 0x02
        case .inputRegisters: 0x04
        case .holdingRegisters: 0x03
        }
    }

    /// Modbus Application Protocol v1.1b3: FC01/02 — 1…2000, FC03/04 — 1…125.
    var maxReadQuantity: Int { isRegister ? 125 : 2_000 }

    /// FC15 — 1…1968 coils, FC16 — 1…123 registers; read-only areas have no write limit.
    var maxWriteQuantity: Int? {
        switch self {
        case .coils: 1_968
        case .holdingRegisters: 123
        case .discreteInputs, .inputRegisters: nil
        }
    }

    var unitName: String { isRegister ? "рег." : "бит" }
}

/// A parsed address plus an optional bit inside a 16-bit register.
struct ModbusAddressInput: Equatable {
    let address: ModbusAddress
    let bit: Int?
}

struct ModbusAddressRow: Identifiable, Equatable {
    let label: String
    let value: String

    var id: String { label }
}

enum ModbusAddressParser {
    static func parse(_ text: String, notation: ModbusAddressNotation, area: ModbusArea) -> ModbusAddressInput? {
        let compact = text.filter { !$0.isWhitespace }
        guard !compact.isEmpty, let split = splitBit(compact) else { return nil }
        guard let address = address(split.body, notation: notation, area: area) else { return nil }
        if split.bit != nil && !address.area.isRegister { return nil }
        return ModbusAddressInput(address: address, bit: split.bit)
    }

    /// Writes the same address in another notation; nil when that notation cannot express the area.
    static func format(_ input: ModbusAddressInput, as notation: ModbusAddressNotation) -> String? {
        let address = input.address
        let body: String?
        switch notation {
        case .reference: body = address.fiveDigitReference ?? address.sixDigitReference
        case .offsetDecimal: body = String(address.offset)
        case .offsetHex: body = "0x" + address.offset.hexString(digits: 4)
        case .oneBased: body = String(address.oneBasedNumber)
        case .schneider: body = address.schneiderNotation
        }
        guard let body else { return nil }
        guard let bit = input.bit else { return body }
        return "\(body).\(bit)"
    }

    /// Accepts 0x / 16# / $ prefixes and an h suffix; "_" separators as in IEC 61131 literals.
    static func hex(_ text: String) -> Int? {
        var digits = Substring(text.lowercased().filter { $0 != "_" })
        if digits.hasPrefix("0x") {
            digits = digits.dropFirst(2)
        } else if digits.hasPrefix("16#") {
            digits = digits.dropFirst(3)
        } else if digits.hasPrefix("$") {
            digits = digits.dropFirst()
        }
        if digits.hasSuffix("h") { digits = digits.dropLast() }
        guard (1...8).contains(digits.count), digits.allSatisfy(\.isHexDigit) else { return nil }
        return Int(digits, radix: 16)
    }

    static func decimal<S: StringProtocol>(_ text: S) -> Int? {
        guard (1...7).contains(text.count), text.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(text)
    }

    private static func address(_ body: String, notation: ModbusAddressNotation, area: ModbusArea) -> ModbusAddress? {
        switch notation {
        case .reference:
            return ModbusAddress(reference: body)
        case .offsetDecimal:
            return decimal(body).flatMap { ModbusAddress(area: area, offset: $0) }
        case .offsetHex:
            return hex(body).flatMap { ModbusAddress(area: area, offset: $0) }
        case .oneBased:
            return decimal(body).flatMap { ModbusAddress(area: area, offset: $0 - 1) }
        case .schneider:
            let lower = body.lowercased()
            if lower.hasPrefix("%mw") {
                return decimal(lower.dropFirst(3)).flatMap { ModbusAddress(area: .holdingRegisters, offset: $0) }
            }
            if lower.hasPrefix("%m") {
                return decimal(lower.dropFirst(2)).flatMap { ModbusAddress(area: .coils, offset: $0) }
            }
            return nil
        }
    }

    private static func splitBit(_ text: String) -> (body: String, bit: Int?)? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        switch parts.count {
        case 1:
            return (text, nil)
        case 2:
            guard let bit = decimal(parts[1]), (0...15).contains(bit) else { return nil }
            return (String(parts[0]), bit)
        default:
            return nil
        }
    }
}

extension ModbusAddress {
    var oneBasedNumber: Int { offset + 1 }

    var schneiderNotation: String? {
        switch area {
        case .holdingRegisters: "%MW\(offset)"
        case .coils: "%M\(offset)"
        case .discreteInputs, .inputRegisters: nil
        }
    }

    /// Starting-address field of the request PDU, high byte first.
    var wireBytes: String {
        ModbusReadRequest.hex([UInt8(offset >> 8), UInt8(offset & 0xFF)])
    }

    func rows(bit: Int?) -> [ModbusAddressRow] {
        var rows = [
            ModbusAddressRow(label: "Modicon, 5 цифр", value: fiveDigitReference ?? "не помещается"),
            ModbusAddressRow(label: "Modicon, 6 цифр", value: sixDigitReference),
            ModbusAddressRow(label: "Смещение DEC (с 0)", value: String(offset)),
            ModbusAddressRow(label: "Смещение HEX (с 0)", value: "0x" + offset.hexString(digits: 4)),
            ModbusAddressRow(label: "IEC 61131 литерал", value: "16#" + offset.hexString(digits: 4)),
            ModbusAddressRow(label: "Номер DEC (с 1)", value: String(oneBasedNumber)),
            ModbusAddressRow(label: "Номер HEX (с 1)", value: "0x" + oneBasedNumber.hexString(digits: 4)),
        ]
        if let schneiderNotation {
            rows.append(ModbusAddressRow(label: "Schneider", value: schneiderNotation))
        }
        rows.append(ModbusAddressRow(label: "Байты адреса в PDU", value: wireBytes))
        guard let bit else { return rows }
        let mask = 1 << bit
        rows.append(ModbusAddressRow(label: "Modicon с битом", value: "\(sixDigitReference).\(bit)"))
        if let schneiderNotation {
            rows.append(ModbusAddressRow(label: "Schneider с битом", value: "\(schneiderNotation).\(bit)"))
        }
        rows.append(ModbusAddressRow(label: "Маска бита HEX", value: "0x" + mask.hexString(digits: 4)))
        rows.append(ModbusAddressRow(label: "Маска бита DEC", value: String(mask)))
        return rows
    }
}

/// Read request for the area's read function (01/02/03/04) and its RTU / TCP framing.
struct ModbusReadRequest: Equatable {
    let area: ModbusArea
    let offset: Int
    let quantity: Int

    init?(address: ModbusAddress, quantity: Int) {
        guard (1...address.area.maxReadQuantity).contains(quantity),
              address.offset + quantity - 1 <= ModbusAddress.maxOffset
        else { return nil }
        self.area = address.area
        self.offset = address.offset
        self.quantity = quantity
    }

    var lastAddress: ModbusAddress? { ModbusAddress(area: area, offset: offset + quantity - 1) }

    var pdu: [UInt8] {
        [area.readFunctionCode, UInt8(offset >> 8), UInt8(offset & 0xFF), UInt8(quantity >> 8), UInt8(quantity & 0xFF)]
    }

    /// Data bytes in the response: 2 per register, coils/inputs packed 8 per byte.
    var responseDataBytes: Int { area.isRegister ? 2 * quantity : (quantity + 7) / 8 }

    /// Function code + byte count + data.
    var responsePDULength: Int { 2 + responseDataBytes }

    var rtuResponseLength: Int { 1 + responsePDULength + 2 }

    var tcpResponseLength: Int { 7 + responsePDULength }

    func rtuFrame(unit: UInt8) -> [UInt8] {
        let body = [unit] + pdu
        let crc = Self.crc16(body)
        return body + [UInt8(crc & 0xFF), UInt8(crc >> 8)]
    }

    /// MBAP header: transaction ID, protocol 0, length (unit + PDU), unit ID.
    func tcpFrame(transaction: UInt16, unit: UInt8) -> [UInt8] {
        let length = pdu.count + 1
        return [
            UInt8(transaction >> 8), UInt8(transaction & 0xFF),
            0x00, 0x00,
            UInt8(length >> 8), UInt8(length & 0xFF),
            unit,
        ] + pdu
    }

    /// CRC-16/MODBUS: polynomial 0xA001 (reflected 0x8005), initial 0xFFFF; sent low byte first.
    static func crc16(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in bytes {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                crc = crc & 1 == 1 ? (crc >> 1) ^ 0xA001 : crc >> 1
            }
        }
        return crc
    }

    static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { $0.hexString(digits: 2) }.joined(separator: " ")
    }
}
