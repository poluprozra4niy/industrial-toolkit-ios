import Foundation
import Observation

@MainActor
@Observable
final class ModbusRegistersViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case decode
        case encode
        case address

        var id: String { rawValue }

        var title: String {
            switch self {
            case .decode: "Регистры"
            case .encode: "Значение"
            case .address: "Адрес"
            }
        }
    }

    struct DecodedRow: Identifiable {
        let order: ModbusByteOrder
        let label: String
        let value: String

        var id: ModbusByteOrder { order }
    }

    struct EncodedRow: Identifiable {
        let order: ModbusByteOrder
        let label: String
        let registers: [UInt16]

        var id: ModbusByteOrder { order }

        var hex: String { registers.map { $0.hexString(digits: 4) }.joined(separator: " ") }
        var decimal: String { registers.map { String($0) }.joined(separator: " ") }
    }

    static let registerSlots = 4

    var mode: Mode = .decode
    var registerTexts = ["4049", "0FDB", "", ""]
    private(set) var registersInHex = true
    var encodeType: RegisterDataType = .int32
    var encodeText = "-100000"
    var referenceText = "40108"
    var offsetArea: ModbusArea = .holdingRegisters
    var offsetText = "107"

    // MARK: Registers → values

    func isRegisterInvalid(_ index: Int) -> Bool {
        let text = registerTexts[index]
        return !text.allSatisfy(\.isWhitespace) && Float32Word.parseRegister(text, hex: registersInHex) == nil
    }

    /// Leading run of valid registers; the first empty or invalid slot ends the value.
    var registers: [UInt16] {
        var result: [UInt16] = []
        for text in registerTexts {
            guard let value = Float32Word.parseRegister(text, hex: registersInHex) else { break }
            result.append(value)
        }
        return result
    }

    var registerError: String? {
        guard let index = registerTexts.indices.first(where: { isRegisterInvalid($0) }) else { return nil }
        return "Регистр \(Self.registerName(index)): " + (registersInHex ? "0000…FFFF" : "0…65535 или −32768…−1")
    }

    var wideTypes: [RegisterDataType] {
        let available = registers.count
        return RegisterDataType.allCases.filter { $0.registerCount > 1 && $0.registerCount <= available }
    }

    func decodedRows(_ type: RegisterDataType) -> [DecodedRow] {
        let values = registers
        return ModbusCodec.distinctOrders(registerCount: type.registerCount).compactMap { order in
            type.decode(values, order: order).map {
                DecodedRow(order: order, label: ModbusCodec.wireLabel(order: order, byteCount: type.byteCount), value: $0)
            }
        }
    }

    func setRegistersInHex(_ hex: Bool) {
        let parsed = registerTexts.map { Float32Word.parseRegister($0, hex: registersInHex) }
        registersInHex = hex
        registerTexts = zip(registerTexts, parsed).map { text, value in value.map { format(register: $0) } ?? text }
    }

    func format(register: UInt16) -> String {
        registersInHex ? register.hexString(digits: 4) : String(register)
    }

    static func registerName(_ index: Int) -> String {
        index == 0 ? "n" : "n+\(index)"
    }

    // MARK: Value → registers

    var encodedBytes: [UInt8]? { encodeType.encode(encodeText) }

    var isEncodeInvalid: Bool { !encodeText.allSatisfy(\.isWhitespace) && encodedBytes == nil }

    var encodedRows: [EncodedRow] {
        guard let bytes = encodedBytes else { return [] }
        return ModbusCodec.distinctOrders(registerCount: encodeType.registerCount).map { order in
            EncodedRow(
                order: order,
                label: ModbusCodec.wireLabel(order: order, byteCount: encodeType.byteCount),
                registers: ModbusCodec.registers(fromBigEndian: bytes, order: order)
            )
        }
    }

    // MARK: Addressing

    var referenceAddress: ModbusAddress? { ModbusAddress(reference: referenceText) }

    var isReferenceInvalid: Bool { !referenceText.allSatisfy(\.isWhitespace) && referenceAddress == nil }

    var offsetAddress: ModbusAddress? {
        guard let offset = Int(offsetText.filter { !$0.isWhitespace }) else { return nil }
        return ModbusAddress(area: offsetArea, offset: offset)
    }

    var isOffsetInvalid: Bool { !offsetText.allSatisfy(\.isWhitespace) && offsetAddress == nil }

    // MARK: Export

    var noteTitle: String {
        switch mode {
        case .decode: "Modbus: " + registers.map { $0.hexString(digits: 4) }.joined(separator: " ")
        case .encode: "Modbus: \(encodeType.title) \(encodeText)"
        case .address: "Modbus адрес \(referenceText)"
        }
    }

    var summary: String? {
        switch mode {
        case .decode: decodeSummary
        case .encode: encodeSummary
        case .address: addressSummary
        }
    }

    private var decodeSummary: String? {
        let values = registers
        guard !values.isEmpty else { return nil }
        var lines = ["Регистры Modbus: " + values.map { "0x\($0.hexString(digits: 4))" }.joined(separator: " ")]
        for (index, value) in values.enumerated() {
            lines.append("Рег. \(Self.registerName(index)): UINT16 \(value), INT16 \(Int16(bitPattern: value)), биты \(ModbusCodec.groupedBinary(value))")
        }
        for type in wideTypes {
            lines.append("")
            lines.append(type.title + ":")
            lines += decodedRows(type).map { "  \($0.label): \($0.value)" }
        }
        return lines.joined(separator: "\n")
    }

    private var encodeSummary: String? {
        let rows = encodedRows
        guard !rows.isEmpty else { return nil }
        let header = "Modbus: \(encodeType.title) = \(encodeText)"
        return ([header] + rows.map { "  \($0.label): \($0.hex)  (\($0.decimal))" }).joined(separator: "\n")
    }

    private var addressSummary: String? {
        guard let address = referenceAddress else { return nil }
        return [
            "Modbus адрес \(referenceText)",
            "Область: \(address.area.title) (\(address.area.detail))",
            "Функция чтения: \(address.area.readFunction), записи: \(address.area.writeFunctions)",
            "Смещение в PDU: \(address.offset) (0x\(address.offset.hexString(digits: 4)))",
        ].joined(separator: "\n")
    }
}
