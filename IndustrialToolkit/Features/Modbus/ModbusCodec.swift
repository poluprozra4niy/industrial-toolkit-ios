import Foundation

extension ModbusByteOrder {
    /// Bytes swapped inside each 16-bit register (BADC, DCBA).
    var swapsBytes: Bool { self == .badc || self == .dcba }
    /// Register order reversed (CDAB, DCBA) — "word swap" generalised to any register count.
    var swapsWords: Bool { self == .cdab || self == .dcba }
}

/// Maps big-endian value bytes to Modbus registers and back for any even byte count,
/// so 32- and 64-bit types share one implementation of the four byte orders.
enum ModbusCodec {
    static func registers(fromBigEndian bytes: [UInt8], order: ModbusByteOrder) -> [UInt16] {
        precondition(bytes.count.isMultiple(of: 2), "Modbus values occupy whole registers")
        let words = stride(from: 0, to: bytes.count, by: 2).map { (UInt16(bytes[$0]) << 8) | UInt16(bytes[$0 + 1]) }
        let swapped = order.swapsBytes ? words.map(\.byteSwapped) : words
        return order.swapsWords ? Array(swapped.reversed()) : swapped
    }

    static func bigEndianBytes(fromRegisters registers: [UInt16], order: ModbusByteOrder) -> [UInt8] {
        let ordered = order.swapsWords ? Array(registers.reversed()) : registers
        let words = order.swapsBytes ? ordered.map(\.byteSwapped) : ordered
        return words.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
    }

    /// Wire order as letters, e.g. "CDAB" for 4 bytes or "GHEFCDAB" for 8 bytes.
    static func wireLabel(order: ModbusByteOrder, byteCount: Int) -> String {
        let identity = (0..<byteCount).map { UInt8($0) }
        let wire = registers(fromBigEndian: identity, order: order).flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
        return String(wire.map { Character(UnicodeScalar(UInt8(65) + $0)) })
    }

    /// Orders that differ for a value of `registerCount` registers (word swap is a no-op for one register).
    static func distinctOrders(registerCount: Int) -> [ModbusByteOrder] {
        registerCount == 1 ? [.abcd, .badc] : ModbusByteOrder.allCases
    }

    static func groupedBinary(_ register: UInt16) -> String {
        let bits = register.binaryString(digits: 16)
        return stride(from: 0, to: 16, by: 4)
            .map { offset in
                let start = bits.index(bits.startIndex, offsetBy: offset)
                return String(bits[start..<bits.index(start, offsetBy: 4)])
            }
            .joined(separator: " ")
    }
}

enum RegisterDataType: String, CaseIterable, Identifiable {
    case uint16
    case int16
    case uint32
    case int32
    case float32
    case uint64
    case int64
    case float64

    var id: String { rawValue }

    var title: String { rawValue.uppercased() }

    var registerCount: Int {
        switch self {
        case .uint16, .int16: 1
        case .uint32, .int32, .float32: 2
        case .uint64, .int64, .float64: 4
        }
    }

    var byteCount: Int { registerCount * 2 }

    var isFloat: Bool { self == .float32 || self == .float64 }

    var isSigned: Bool { self == .int16 || self == .int32 || self == .int64 }

    /// Interprets the first `registerCount` registers; nil when fewer are given.
    func decode(_ registers: [UInt16], order: ModbusByteOrder) -> String? {
        guard registers.count >= registerCount else { return nil }
        let bytes = ModbusCodec.bigEndianBytes(fromRegisters: Array(registers.prefix(registerCount)), order: order)
        let bits = bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        switch self {
        case .uint16: return String(UInt16(truncatingIfNeeded: bits))
        case .int16: return String(Int16(truncatingIfNeeded: bits))
        case .uint32: return String(UInt32(truncatingIfNeeded: bits))
        case .int32: return String(Int32(truncatingIfNeeded: bits))
        case .float32: return Fmt.float(Float(bitPattern: UInt32(truncatingIfNeeded: bits)))
        case .uint64: return String(bits)
        case .int64: return String(Int64(bitPattern: bits))
        case .float64: return Fmt.double(Double(bitPattern: bits))
        }
    }

    /// Big-endian bytes of a user-typed value. Integer types also accept a "0x…" bit pattern.
    func encode(_ text: String) -> [UInt8]? {
        let bits: UInt64
        if isFloat {
            guard let value = NumberParser.parse(text, allowNonFinite: true) else { return nil }
            bits = self == .float32 ? UInt64(Float(value).bitPattern) : value.bitPattern
        } else {
            guard let parsed = parseInteger(text) else { return nil }
            bits = parsed
        }
        return (0..<byteCount).reversed().map { UInt8(truncatingIfNeeded: bits >> UInt64(8 * $0)) }
    }

    var inputHint: String {
        switch self {
        case .uint16: "0…65535 или 0x0000…0xFFFF"
        case .int16: "−32768…32767 или 0x…"
        case .uint32: "0…4294967295 или 0x…"
        case .int32: "−2147483648…2147483647 или 0x…"
        case .uint64: "0…18446744073709551615 или 0x…"
        case .int64: "64-битное целое со знаком или 0x…"
        case .float32, .float64: "Число: 12.5, -0,001, 1e-6, inf, nan"
        }
    }

    private func parseInteger(_ text: String) -> UInt64? {
        let cleaned = text
            .replacingOccurrences(of: "\u{2212}", with: "-")
            .filter { !$0.isWhitespace && $0 != "_" }
        let bitWidth = byteCount * 8
        let mask: UInt64 = bitWidth == 64 ? .max : (UInt64(1) << UInt64(bitWidth)) - 1
        if cleaned.lowercased().hasPrefix("0x") {
            let digits = String(cleaned.dropFirst(2))
            guard (1...(byteCount * 2)).contains(digits.count),
                  digits.allSatisfy(\.isHexDigit),
                  let value = UInt64(digits, radix: 16)
            else { return nil }
            return value
        }
        if isSigned {
            guard let value = Int64(cleaned) else { return nil }
            let lowest: Int64 = bitWidth == 64 ? .min : -(Int64(1) << Int64(bitWidth - 1))
            let highest: Int64 = bitWidth == 64 ? .max : (Int64(1) << Int64(bitWidth - 1)) - 1
            guard (lowest...highest).contains(value) else { return nil }
            return UInt64(bitPattern: value) & mask
        }
        guard let value = UInt64(cleaned), value <= mask else { return nil }
        return value
    }
}

enum ModbusArea: Int, CaseIterable, Identifiable {
    case coils = 0
    case discreteInputs = 1
    case inputRegisters = 3
    case holdingRegisters = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .coils: "Coils"
        case .discreteInputs: "Discrete Inputs"
        case .inputRegisters: "Input Registers"
        case .holdingRegisters: "Holding Registers"
        }
    }

    var detail: String {
        switch self {
        case .coils: "Биты, чтение и запись"
        case .discreteInputs: "Биты, только чтение"
        case .inputRegisters: "16 бит, только чтение"
        case .holdingRegisters: "16 бит, чтение и запись"
        }
    }

    var readFunction: String {
        switch self {
        case .coils: "01"
        case .discreteInputs: "02"
        case .inputRegisters: "04"
        case .holdingRegisters: "03"
        }
    }

    var writeFunctions: String {
        switch self {
        case .coils: "05, 15"
        case .discreteInputs, .inputRegisters: "—"
        case .holdingRegisters: "06, 16"
        }
    }
}

/// Converts between "reference" notation (40001 / 400001) and the 0-based PDU offset sent on the wire.
struct ModbusAddress: Equatable {
    static let maxOffset = 65_535

    let area: ModbusArea
    let offset: Int

    init?(area: ModbusArea, offset: Int) {
        guard (0...Self.maxOffset).contains(offset) else { return nil }
        self.area = area
        self.offset = offset
    }

    /// Accepts 5-digit (40001…49999) and 6-digit (400001…465536) references.
    init?(reference text: String) {
        let digits = text.filter { !$0.isWhitespace }
        guard (5...6).contains(digits.count),
              digits.allSatisfy({ $0.isASCII && $0.isNumber }),
              let leading = digits.first?.wholeNumberValue,
              let area = ModbusArea(rawValue: leading),
              let number = Int(digits.dropFirst())
        else { return nil }
        let highest = digits.count == 5 ? 9_999 : Self.maxOffset + 1
        guard (1...highest).contains(number) else { return nil }
        self.init(area: area, offset: number - 1)
    }

    /// Classic 5-digit reference; only offsets 0…9998 fit.
    var fiveDigitReference: String? {
        offset < 9_999 ? "\(area.rawValue)\(Self.padded(offset + 1, width: 4))" : nil
    }

    var sixDigitReference: String { "\(area.rawValue)\(Self.padded(offset + 1, width: 5))" }

    private static func padded(_ value: Int, width: Int) -> String {
        let raw = String(value)
        return String(repeating: "0", count: max(0, width - raw.count)) + raw
    }
}
