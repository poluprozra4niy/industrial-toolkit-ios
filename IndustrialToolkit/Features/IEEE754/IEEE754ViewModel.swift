import Foundation
import Observation

@MainActor
@Observable
final class IEEE754ViewModel {
    enum InputMode: String, CaseIterable, Identifiable {
        case decimal
        case hex
        case registers

        var id: String { rawValue }

        var title: String {
            switch self {
            case .decimal: "Число"
            case .hex: "HEX"
            case .registers: "Регистры"
            }
        }
    }

    struct OrderRow: Identifiable {
        let order: ModbusByteOrder
        let first: UInt16
        let second: UInt16
        let word: Float32Word

        var id: ModbusByteOrder { order }
    }

    var mode: InputMode = .decimal
    private(set) var byteOrder: ModbusByteOrder = .abcd
    private(set) var registersInHex = true
    private(set) var decimalText = ""
    private(set) var hexText = ""
    private(set) var firstRegisterText = ""
    private(set) var secondRegisterText = ""
    private(set) var word: Float32Word?
    private(set) var inputError: String?
    /// Exact number the user typed, kept to report float32 rounding/overflow.
    private(set) var requestedValue: Double?

    /// `Float(Double.pi)` rounds to nearest (0x40490FDB) like PLCs do; `Float.pi` truncates.
    init(initialValue: Float = Float(Double.pi)) {
        apply(Float32Word(value: initialValue), editedField: nil)
    }

    // MARK: Intents

    func updateDecimal(_ text: String) {
        decimalText = text
        guard !text.allSatisfy(\.isWhitespace) else { return clear() }
        guard let value = NumberParser.parse(text, allowNonFinite: true) else {
            return fail("Введите число: 12.5, -0,001, 1e-6, inf, nan")
        }
        requestedValue = value
        apply(Float32Word(value: Float(value)), editedField: .decimal)
    }

    func updateHex(_ text: String) {
        hexText = text
        guard !text.allSatisfy(\.isWhitespace) else { return clear() }
        guard let parsed = Float32Word(hex: text) else {
            return fail("HEX: до 8 символов 0–9, A–F (префикс 0x допустим)")
        }
        requestedValue = nil
        apply(parsed, editedField: .hex)
    }

    func updateFirstRegister(_ text: String) {
        firstRegisterText = text
        parseRegisters()
    }

    func updateSecondRegister(_ text: String) {
        secondRegisterText = text
        parseRegisters()
    }

    func selectByteOrder(_ order: ModbusByteOrder) {
        byteOrder = order
        if mode == .registers {
            parseRegisters()
        } else if let word {
            syncRegisterTexts(from: word)
        }
    }

    func setRegistersInHex(_ hex: Bool) {
        let current = parsedRegisters
        registersInHex = hex
        guard let current else { return }
        firstRegisterText = format(register: current.first)
        secondRegisterText = format(register: current.second)
    }

    func toggleBit(_ bit: Int) {
        guard let word else { return }
        requestedValue = nil
        apply(word.togglingBit(bit), editedField: nil)
    }

    // MARK: Derived

    var conversionNote: String? {
        guard mode == .decimal, let requestedValue, let word, requestedValue.isFinite else { return nil }
        let stored = word.value
        if !stored.isFinite {
            return "Переполнение: |x| > 3.4028235e38, в float32 станет ∞"
        }
        if stored == 0, requestedValue != 0 {
            return "Потеря значимости: |x| < 1.4e-45, в float32 станет 0"
        }
        let error = Double(stored) - requestedValue
        guard error != 0 else { return nil }
        return "Погрешность представления: \(error.formatted(.number.precision(.significantDigits(1...4))))"
    }

    var orderRows: [OrderRow] {
        if mode == .registers, let registers = parsedRegisters {
            return ModbusByteOrder.allCases.map { order in
                OrderRow(
                    order: order,
                    first: registers.first,
                    second: registers.second,
                    word: Float32Word(registers: registers.first, registers.second, order: order)
                )
            }
        }
        guard let word else { return [] }
        return ModbusByteOrder.allCases.map { order in
            let registers = word.registers(order: order)
            return OrderRow(order: order, first: registers.first, second: registers.second, word: word)
        }
    }

    var summary: String? {
        guard let word else { return nil }
        let registers = word.registers(order: byteOrder)
        var lines = [
            "IEEE 754 float32",
            "Значение: \(Fmt.float(word.value))",
            "HEX: 0x\(word.hex)",
            "Двоичный: \(word.binaryGrouped)",
            "Порядок \(byteOrder.title) (\(byteOrder.subtitle)): "
                + "Рег.1 = 0x\(registers.first.hexString(digits: 4)) (\(registers.first)), "
                + "Рег.2 = 0x\(registers.second.hexString(digits: 4)) (\(registers.second))",
            "",
            "Все порядки байт:",
        ]
        lines += orderRows.map { row in
            "\(row.order.title): 0x\(row.first.hexString(digits: 4)) 0x\(row.second.hexString(digits: 4)) → \(Fmt.float(row.word.value))"
        }
        return lines.joined(separator: "\n")
    }

    var noteTitle: String {
        guard let word else { return "IEEE 754" }
        return "Float \(Fmt.float(word.value)) = 0x\(word.hex)"
    }

    func format(register value: UInt16) -> String {
        registersInHex ? value.hexString(digits: 4) : String(value)
    }

    // MARK: Private

    private var parsedRegisters: (first: UInt16, second: UInt16)? {
        guard let first = Float32Word.parseRegister(firstRegisterText, hex: registersInHex),
              let second = Float32Word.parseRegister(secondRegisterText, hex: registersInHex)
        else { return nil }
        return (first, second)
    }

    private func parseRegisters() {
        let firstEmpty = firstRegisterText.allSatisfy(\.isWhitespace)
        let secondEmpty = secondRegisterText.allSatisfy(\.isWhitespace)
        guard !(firstEmpty && secondEmpty) else { return clear() }
        let range = registersInHex ? "0000…FFFF" : "0…65535 или −32768…−1"
        guard let first = Float32Word.parseRegister(firstRegisterText, hex: registersInHex) else {
            return fail("Регистр 1: \(range)")
        }
        guard let second = Float32Word.parseRegister(secondRegisterText, hex: registersInHex) else {
            return fail("Регистр 2: \(range)")
        }
        requestedValue = nil
        apply(Float32Word(registers: first, second, order: byteOrder), editedField: .registers)
    }

    /// Writes the new word into every input except the one being edited, so switching
    /// modes always shows the same number and the user's own typing is never rewritten.
    private func apply(_ newWord: Float32Word, editedField: InputMode?) {
        word = newWord
        inputError = nil
        if editedField != .decimal { decimalText = newWord.value.description }
        if editedField != .hex { hexText = newWord.hex }
        if editedField != .registers { syncRegisterTexts(from: newWord) }
    }

    private func syncRegisterTexts(from word: Float32Word) {
        let registers = word.registers(order: byteOrder)
        firstRegisterText = format(register: registers.first)
        secondRegisterText = format(register: registers.second)
    }

    private func fail(_ message: String) {
        word = nil
        requestedValue = nil
        inputError = message
    }

    private func clear() {
        word = nil
        requestedValue = nil
        inputError = nil
    }
}
