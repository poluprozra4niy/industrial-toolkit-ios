import Foundation
import Observation

@MainActor
@Observable
final class ModbusAddressViewModel {
    enum Transport: String, CaseIterable, Identifiable {
        case rtu
        case tcp

        var id: String { rawValue }

        var title: String {
            switch self {
            case .rtu: "RTU"
            case .tcp: "TCP"
            }
        }
    }

    struct RangeRow: Identifiable {
        let address: ModbusAddress

        var id: Int { address.offset }
    }

    static let tcpTransactionID: UInt16 = 0x0001
    /// Range table stays readable on a phone; longer ranges are summarised by first/last address.
    static let rangeRowLimit = 125

    private(set) var notation: ModbusAddressNotation = .reference
    var area: ModbusArea = .holdingRegisters
    var addressText = "40108"
    var quantityText = "3"
    var unitText = "17"
    var transport: Transport = .rtu

    // MARK: Address

    var input: ModbusAddressInput? { ModbusAddressParser.parse(addressText, notation: notation, area: area) }

    var isAddressInvalid: Bool { !addressText.allSatisfy(\.isWhitespace) && input == nil }

    var rows: [ModbusAddressRow] {
        guard let input else { return [] }
        return input.address.rows(bit: input.bit)
    }

    /// Switching notation rewrites the field so the same address stays selected.
    func select(_ newNotation: ModbusAddressNotation) {
        guard newNotation != notation else { return }
        let current = input
        notation = newNotation
        guard let current else { return }
        area = current.address.area
        if let converted = ModbusAddressParser.format(current, as: newNotation) {
            addressText = converted
        }
    }

    /// A bare number in a manual may be counted from 0 or from 1; show where the other reading lands.
    var ambiguityNote: String? {
        guard let input else { return nil }
        let offset = input.address.offset
        switch notation {
        case .offsetDecimal, .offsetHex:
            guard offset > 0 else { return nil }
            return "Если в документации нумерация с 1, то это смещение \(offset - 1) (0x\((offset - 1).hexString(digits: 4)))."
        case .oneBased:
            guard offset < ModbusAddress.maxOffset else { return nil }
            return "Если в документации нумерация с 0, то это смещение \(offset + 1) (0x\((offset + 1).hexString(digits: 4)))."
        case .reference, .schneider:
            return nil
        }
    }

    // MARK: Read request

    var quantity: Int? { ModbusAddressParser.decimal(quantityText.filter { !$0.isWhitespace }) }

    var unit: UInt8? {
        guard let value = ModbusAddressParser.decimal(unitText.filter { !$0.isWhitespace }), value <= 255 else { return nil }
        return UInt8(value)
    }

    var isQuantityInvalid: Bool { !quantityText.allSatisfy(\.isWhitespace) && request == nil && input != nil }

    var isUnitInvalid: Bool { unit == nil }

    var request: ModbusReadRequest? {
        guard let address = input?.address, let quantity else { return nil }
        return ModbusReadRequest(address: address, quantity: quantity)
    }

    var quantityError: String? {
        guard let address = input?.address, isQuantityInvalid else { return nil }
        let limit = min(address.area.maxReadQuantity, ModbusAddress.maxOffset - address.offset + 1)
        return "Количество 1…\(limit) \(address.area.unitName): FC\(address.area.readFunction) читает до \(address.area.maxReadQuantity), адрес не выше 65535."
    }

    /// RTU reads go to slaves 1…247; 0 is broadcast and gets no reply.
    var unitWarning: String? {
        guard let unit else { return "Адрес устройства 0…255." }
        if transport == .rtu && !(1...247).contains(unit) {
            return "В RTU адрес ведомого 1…247; 0 — широковещательный, ответа на чтение не будет."
        }
        return nil
    }

    var frame: [UInt8]? {
        guard let request, let unit else { return nil }
        switch transport {
        case .rtu: return request.rtuFrame(unit: unit)
        case .tcp: return request.tcpFrame(transaction: Self.tcpTransactionID, unit: unit)
        }
    }

    var responseLength: Int? {
        guard let request else { return nil }
        switch transport {
        case .rtu: return request.rtuResponseLength
        case .tcp: return request.tcpResponseLength
        }
    }

    var rangeRows: [RangeRow] {
        guard let request, request.quantity > 1 else { return [] }
        let count = min(request.quantity, Self.rangeRowLimit)
        return (0..<count).compactMap { index in
            ModbusAddress(area: request.area, offset: request.offset + index).map(RangeRow.init)
        }
    }

    // MARK: Export

    var noteTitle: String { "Modbus адрес \(addressText)" }

    var summary: String? {
        guard let input else { return nil }
        var lines = [
            "Modbus адрес \(addressText) (\(notation.title), \(notation.subtitle))",
            "Область: \(input.address.area.title), чтение FC\(input.address.area.readFunction), запись \(input.address.area.writeFunctions)",
        ]
        lines += rows.map { "\($0.label): \($0.value)" }
        if let request, let frame, let last = request.lastAddress {
            lines.append("")
            lines.append("Чтение \(request.quantity) \(request.area.unitName): \(input.address.sixDigitReference)…\(last.sixDigitReference)")
            lines.append("PDU: \(ModbusReadRequest.hex(request.pdu))")
            lines.append("Кадр \(transport.title): \(ModbusReadRequest.hex(frame))")
            if let responseLength {
                lines.append("Ожидаемый ответ: \(responseLength) байт")
            }
        }
        return lines.joined(separator: "\n")
    }
}
