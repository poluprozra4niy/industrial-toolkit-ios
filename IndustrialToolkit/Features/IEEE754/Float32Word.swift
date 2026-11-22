import Foundation

/// Order in which the four big-endian bytes A B C D of a float travel in two Modbus registers.
enum ModbusByteOrder: String, CaseIterable, Identifiable {
    case abcd
    case badc
    case cdab
    case dcba

    var id: String { rawValue }

    var title: String { rawValue.uppercased() }

    var subtitle: String {
        switch self {
        case .abcd: "Big-endian"
        case .badc: "Byte swap"
        case .cdab: "Word swap"
        case .dcba: "Little-endian"
        }
    }

    /// wire[i] = bytes[permutation[i]], where bytes = [A, B, C, D].
    fileprivate var permutation: [Int] {
        switch self {
        case .abcd: [0, 1, 2, 3]
        case .badc: [1, 0, 3, 2]
        case .cdab: [2, 3, 0, 1]
        case .dcba: [3, 2, 1, 0]
        }
    }
}

enum FloatClass: Equatable {
    case zero
    case subnormal
    case normal
    case infinity
    case quietNaN
    case signalingNaN

    var title: String {
        switch self {
        case .zero: "Ноль"
        case .subnormal: "Денормализованное"
        case .normal: "Нормализованное"
        case .infinity: "Бесконечность"
        case .quietNaN: "NaN (quiet)"
        case .signalingNaN: "NaN (signaling)"
        }
    }
}

enum BitField {
    case sign
    case exponent
    case mantissa

    static func of(bit: Int) -> BitField {
        switch bit {
        case 31: .sign
        case 23...30: .exponent
        default: .mantissa
        }
    }

    var title: String {
        switch self {
        case .sign: "Знак"
        case .exponent: "Порядок"
        case .mantissa: "Мантисса"
        }
    }
}

/// IEEE 754 binary32 as raw bits; the bit pattern is the source of truth so NaN payloads
/// and signed zeros survive every conversion untouched.
struct Float32Word: Equatable, Hashable {
    static let byteLabels = ["A", "B", "C", "D"]
    private static let fractionScale = Double(1 << 23)

    let bits: UInt32

    init(bits: UInt32) {
        self.bits = bits
    }

    init(value: Float) {
        self.bits = value.bitPattern
    }

    init(registers first: UInt16, _ second: UInt16, order: ModbusByteOrder) {
        let wire: [UInt8] = [
            UInt8(first >> 8), UInt8(first & 0xFF),
            UInt8(second >> 8), UInt8(second & 0xFF),
        ]
        var bytes = [UInt8](repeating: 0, count: 4)
        for (wireIndex, byteIndex) in order.permutation.enumerated() {
            bytes[byteIndex] = wire[wireIndex]
        }
        self.bits = bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    /// Accepts "40490FDB", "0x4049_0FDB", "4049 0fdb"; up to 8 hex digits.
    init?(hex text: String) {
        let cleaned = text.filter { !$0.isWhitespace && $0 != "_" }
        let digits = cleaned.lowercased().hasPrefix("0x") ? String(cleaned.dropFirst(2)) : cleaned
        guard (1...8).contains(digits.count),
              digits.allSatisfy(\.isHexDigit),
              let value = UInt32(digits, radix: 16)
        else { return nil }
        self.bits = value
    }

    var value: Float { Float(bitPattern: bits) }

    var bytes: [UInt8] { [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: bits >> $0) } }

    var sign: Int { Int(bits >> 31) }

    var biasedExponent: Int { Int((bits >> 23) & 0xFF) }

    var fraction: UInt32 { bits & 0x7F_FFFF }

    var floatClass: FloatClass {
        switch (biasedExponent, fraction) {
        case (0, 0): .zero
        case (0, _): .subnormal
        case (0xFF, 0): .infinity
        case (0xFF, let payload): payload & 0x40_0000 != 0 ? .quietNaN : .signalingNaN
        default: .normal
        }
    }

    /// Unbiased exponent; nil for zero, infinity and NaN where it carries no magnitude.
    var exponent: Int? {
        switch floatClass {
        case .normal: biasedExponent - 127
        case .subnormal: -126
        default: nil
        }
    }

    /// 1.f for normal numbers, 0.f for subnormals.
    var significand: Double? {
        switch floatClass {
        case .normal: 1 + Double(fraction) / Self.fractionScale
        case .subnormal: Double(fraction) / Self.fractionScale
        default: nil
        }
    }

    var hex: String { bits.hexString(digits: 8) }

    var binaryGrouped: String {
        let binary = bits.binaryString(digits: 32)
        let signPart = binary.prefix(1)
        let exponentPart = binary.dropFirst().prefix(8)
        let mantissaPart = binary.dropFirst(9)
        return "\(signPart) \(exponentPart) \(mantissaPart)"
    }

    var unsignedInteger: UInt32 { bits }

    var signedInteger: Int32 { Int32(bitPattern: bits) }

    func registers(order: ModbusByteOrder) -> (first: UInt16, second: UInt16) {
        let source = bytes
        let wire = order.permutation.map { source[$0] }
        return (
            (UInt16(wire[0]) << 8) | UInt16(wire[1]),
            (UInt16(wire[2]) << 8) | UInt16(wire[3])
        )
    }

    func isBitSet(_ bit: Int) -> Bool {
        precondition((0..<32).contains(bit), "bit index out of range")
        return (bits >> UInt32(bit)) & 1 == 1
    }

    func togglingBit(_ bit: Int) -> Float32Word {
        precondition((0..<32).contains(bit), "bit index out of range")
        return Float32Word(bits: bits ^ (UInt32(1) << UInt32(bit)))
    }

    /// Decimal 0…65535, signed −32768…−1 (as SCADA often shows INT16), or hex with/without "0x".
    static func parseRegister(_ text: String, hex: Bool) -> UInt16? {
        let cleaned = text
            .replacingOccurrences(of: "\u{2212}", with: "-")
            .filter { !$0.isWhitespace && $0 != "_" }
        let hasPrefix = cleaned.lowercased().hasPrefix("0x")
        if hex || hasPrefix {
            let digits = hasPrefix ? String(cleaned.dropFirst(2)) : cleaned
            guard (1...4).contains(digits.count), digits.allSatisfy(\.isHexDigit) else { return nil }
            return UInt16(digits, radix: 16)
        }
        guard let value = Int(cleaned), (-32_768...65_535).contains(value) else { return nil }
        return value < 0 ? UInt16(bitPattern: Int16(value)) : UInt16(value)
    }
}
