import Foundation
import Observation

@MainActor
@Observable
final class ModbusResponseViewModel {
    struct RegisterValueRow: Identifiable {
        let index: Int
        let address: String
        let raw: String
        let value: String

        var id: Int { index }
    }

    struct BitRow: Identifiable {
        let index: Int
        let address: String
        let isOn: Bool

        var id: Int { index }
    }

    /// Example from the Modbus specification: slave 0x11 answers FC03 for registers 108…110.
    var frameText = "11 03 06 02 2B 00 00 00 64 C8 BA"
    var framing: ModbusFraming = .rtu
    var startText = "107"
    var dataType: RegisterDataType = .uint16
    var order: ModbusByteOrder = .abcd

    var result: Result<ModbusFrame, ModbusFrameError> { ModbusFrame.parse(frameText, framing: framing) }

    var frame: ModbusFrame? {
        guard case .success(let frame) = result else { return nil }
        return frame
    }

    var errorMessage: String? {
        guard case .failure(let error) = result else { return nil }
        return error.message
    }

    var isFrameInvalid: Bool {
        guard case .failure(let error) = result else { return false }
        return error != .empty
    }

    // MARK: Addresses

    /// Requests carry their own start address; a response needs it from the request the user sent.
    var startOffset: Int? {
        if let address = frame?.body.startAddress { return address }
        let compact = startText.filter { !$0.isWhitespace }
        return ModbusAddressParser.decimal(compact) ?? ModbusAddressParser.hex(compact)
    }

    var needsStartAddress: Bool { frame?.body.startAddress == nil }

    var isStartInvalid: Bool { !startText.allSatisfy(\.isWhitespace) && startOffset == nil }

    private func addressLabel(_ index: Int) -> String {
        guard let area = frame?.body.area,
              let start = startOffset,
              let address = ModbusAddress(area: area, offset: start + index)
        else { return "n+\(index)" }
        return address.sixDigitReference
    }

    // MARK: Values

    var registers: [UInt16]? {
        switch frame?.body {
        case .readRegisters(_, let values)?, .writeRegistersRequest(_, _, let values)?: values
        default: nil
        }
    }

    var bits: [Bool]? {
        switch frame?.body {
        case .readBits(_, let values)?, .writeCoilsRequest(_, _, let values)?: values
        default: nil
        }
    }

    var availableTypes: [RegisterDataType] {
        let count = registers?.count ?? 0
        return RegisterDataType.allCases.filter { $0.registerCount <= max(count, 1) }
    }

    var availableOrders: [ModbusByteOrder] { ModbusCodec.distinctOrders(registerCount: dataType.registerCount) }

    func select(_ type: RegisterDataType) {
        dataType = type
        if !availableOrders.contains(order) { order = .abcd }
    }

    var registerRows: [RegisterValueRow] {
        guard let registers else { return [] }
        let size = dataType.registerCount
        let values = dataType.decodeAll(registers, order: order)
        return values.enumerated().map { group, value in
            let first = group * size
            let raw = registers[first..<(first + size)].map { $0.hexString(digits: 4) }.joined(separator: " ")
            return RegisterValueRow(index: first, address: addressLabel(first), raw: raw, value: value)
        }
    }

    var bitRows: [BitRow] {
        guard let bits else { return [] }
        return bits.enumerated().map { index, isOn in
            BitRow(index: index, address: addressLabel(index), isOn: isOn)
        }
    }

    // MARK: Export

    var noteTitle: String { "Modbus кадр \(frame.map { ModbusPDU.functionName($0.body.function) } ?? "")" }

    var summary: String? {
        guard let frame else { return nil }
        var lines = ["Кадр \(framing.title): \(frameText)"]
        if let unit = frame.unit { lines.append("Устройство: \(unit) (0x\(unit.hexString(digits: 2)))") }
        if let crc = frame.crc {
            lines.append("CRC: \(crc.isValid ? "верный" : "ошибка, ожидался \(ModbusReadRequest.hex([UInt8(crc.computed & 0xFF), UInt8(crc.computed >> 8)]))")")
        }
        lines.append("\(frame.body.kindTitle): FC\(frame.body.function.hexString(digits: 2)) \(ModbusPDU.functionName(frame.body.function))")
        if case .exception(_, let code) = frame.body {
            let exception = ModbusExceptionCode.describe(code)
            lines.append("Код ошибки \(code.hexString(digits: 2)) \(exception.name): \(exception.hint)")
        }
        lines += registerRows.map { "\($0.address)  \($0.raw)  \(dataType.title) \(order.title) = \($0.value)" }
        lines += bitRows.map { "\($0.address) = \($0.isOn ? 1 : 0)" }
        lines += frame.warnings.map { "⚠︎ \($0)" }
        return lines.joined(separator: "\n")
    }
}
