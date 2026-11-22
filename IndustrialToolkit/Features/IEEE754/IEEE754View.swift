import SwiftUI

struct IEEE754View: View {
    @State private var model = IEEE754ViewModel()

    private let orderColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                inputCard
                if let word = model.word {
                    readoutCard(word)
                    bitsCard(word)
                    breakdownCard(word)
                    ordersCard
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("IEEE 754 / Float")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: model.noteTitle, summary: model.summary, category: .automation)
        .sensoryFeedback(.selection, trigger: model.word)
    }

    // MARK: Input

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Ввод")
            Picker("Режим", selection: $model.mode) {
                ForEach(IEEE754ViewModel.InputMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch model.mode {
            case .decimal:
                NumericField(
                    label: "Десятичное значение",
                    text: Binding(get: { model.decimalText }, set: { model.updateDecimal($0) }),
                    isInvalid: model.inputError != nil
                )
            case .hex:
                NumericField(
                    label: "32 бита, HEX",
                    text: Binding(get: { model.hexText }, set: { model.updateHex($0) }),
                    unit: "hex",
                    keyboard: .asciiCapable,
                    isInvalid: model.inputError != nil
                )
            case .registers:
                registerInputs
            }

            if let error = model.inputError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.fault)
            }
            if let note = model.conversionNote {
                Label(note, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(Theme.info)
            }

            SectionLabel("Порядок байт Modbus")
            LazyVGrid(columns: orderColumns, spacing: 8) {
                ForEach(ModbusByteOrder.allCases) { order in
                    ChoiceChip(title: order.title, subtitle: order.subtitle, isSelected: model.byteOrder == order) {
                        model.selectByteOrder(order)
                    }
                }
            }
        }
        .industrialCard()
    }

    private var registerInputs: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                NumericField(
                    label: "Рег. 1 (адрес n)",
                    text: Binding(get: { model.firstRegisterText }, set: { model.updateFirstRegister($0) }),
                    keyboard: model.registersInHex ? .asciiCapable : .numbersAndPunctuation,
                    isInvalid: model.inputError != nil
                )
                NumericField(
                    label: "Рег. 2 (адрес n+1)",
                    text: Binding(get: { model.secondRegisterText }, set: { model.updateSecondRegister($0) }),
                    keyboard: model.registersInHex ? .asciiCapable : .numbersAndPunctuation,
                    isInvalid: model.inputError != nil
                )
            }
            Toggle(
                "Регистры в HEX",
                isOn: Binding(get: { model.registersInHex }, set: { model.setRegistersInHex($0) })
            )
            .font(.subheadline)
        }
    }

    // MARK: Output

    private func readoutCard(_ word: Float32Word) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Float32")
                Text(word.floatClass.title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(word.floatClass == .normal ? Color.secondary : Theme.warning)
                    .fixedSize()
            }
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.float(word.value))
                    .font(.readoutLarge)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .textSelection(.enabled)
                Spacer(minLength: 8)
                CopyButton(value: word.value.description)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("0x\(word.hex)")
                    .font(.readout)
                    .foregroundStyle(Theme.accent)
                    .textSelection(.enabled)
                Spacer(minLength: 8)
                CopyButton(value: word.hex)
            }
            let registers = word.registers(order: model.byteOrder)
            HStack(spacing: 10) {
                MetricTile(title: "Рег. 1 · \(model.byteOrder.title)", value: registers.first.hexString(digits: 4), unit: "\(registers.first)")
                MetricTile(title: "Рег. 2 · \(model.byteOrder.title)", value: registers.second.hexString(digits: 4), unit: "\(registers.second)")
            }
        }
        .industrialCard()
    }

    private func bitsCard(_ word: Float32Word) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Биты · нажмите, чтобы инвертировать")
            BitGrid(word: word) { model.toggleBit($0) }
            HStack(spacing: 14) {
                LegendItem(field: .sign)
                LegendItem(field: .exponent)
                LegendItem(field: .mantissa)
            }
            Text(word.binaryGrouped)
                .font(.monoCaption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .industrialCard()
    }

    private func breakdownCard(_ word: Float32Word) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Разбор")
            ValueRow(label: "Знак (s)", value: word.sign == 0 ? "0 (+)" : "1 (−)", valueColor: BitField.sign.tint)
            ValueRow(
                label: "Порядок (e)",
                value: word.exponent.map { "\(word.biasedExponent) → 2^\($0)" } ?? "\(word.biasedExponent)",
                valueColor: BitField.exponent.tint
            )
            ValueRow(
                label: "Мантисса (f)",
                value: "0x\(word.fraction.hexString(digits: 6))",
                valueColor: BitField.mantissa.tint
            )
            if let significand = word.significand, let exponent = word.exponent {
                ValueRow(
                    label: "Формула",
                    value: "\(word.sign == 0 ? "+" : "−")\(Fmt.fixed(significand, fractionDigits: 7)) × 2^\(exponent)",
                    copyable: false
                )
            }
            ValueRow(label: "Хранится как", value: Double(word.value).description)
            Divider()
            ValueRow(label: "UINT32", value: "\(word.unsignedInteger)")
            ValueRow(label: "INT32", value: "\(word.signedInteger)")
        }
        .industrialCard()
    }

    private var ordersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(model.mode == .registers ? "Те же регистры в других порядках" : "Регистры во всех порядках")
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Порядок")
                    Text("Рег. 1")
                    Text("Рег. 2")
                    if model.mode == .registers { Text("Float") }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Divider()
                ForEach(model.orderRows) { row in
                    GridRow {
                        Text(row.order.title)
                            .fontWeight(row.order == model.byteOrder ? .bold : .regular)
                            .foregroundStyle(row.order == model.byteOrder ? Theme.accent : Color.primary)
                        Text(row.first.hexString(digits: 4))
                        Text(row.second.hexString(digits: 4))
                        if model.mode == .registers {
                            Text(Fmt.float(row.word.value))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .font(.monoBody)
                    .contentShape(Rectangle())
                    .onTapGesture { model.selectByteOrder(row.order) }
                }
            }
            Text("Нажмите строку, чтобы выбрать порядок. Неверный порядок обычно даёт абсурдные значения: 1e-38, 4e+12, NaN.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }
}

// MARK: - Bit grid

private struct BitGrid: View {
    let word: Float32Word
    let onToggle: (Int) -> Void

    var body: some View {
        let bytes = word.bytes
        VStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { byteIndex in
                HStack(spacing: 4) {
                    Text(Float32Word.byteLabels[byteIndex])
                        .font(.monoCaption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    ForEach(0..<8, id: \.self) { offset in
                        let bit = 31 - (byteIndex * 8 + offset)
                        BitCell(bit: bit, isSet: word.isBitSet(bit)) { onToggle(bit) }
                    }
                    Text(bytes[byteIndex].hexString(digits: 2))
                        .font(.monoCaption)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
    }
}

private struct BitCell: View {
    let bit: Int
    let isSet: Bool
    let action: () -> Void

    var body: some View {
        let tint = BitField.of(bit: bit).tint
        Button(action: action) {
            Text(isSet ? "1" : "0")
                .font(.system(.callout, design: .monospaced, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(isSet ? Color.primary : Color.secondary)
                .background(tint.opacity(isSet ? 0.32 : 0.08), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(tint.opacity(0.55), lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Бит \(bit), \(BitField.of(bit: bit).title)")
        .accessibilityValue(isSet ? "1" : "0")
        .accessibilityHint("Инвертировать")
    }
}

private struct LegendItem: View {
    let field: BitField

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(field.tint)
                .frame(width: 10, height: 10)
            Text(field.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private extension BitField {
    var tint: Color {
        switch self {
        case .sign: Theme.fault
        case .exponent: Theme.info
        case .mantissa: Theme.ok
        }
    }
}
