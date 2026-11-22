import SwiftUI

struct ModbusRegistersView: View {
    @State private var model = ModbusRegistersViewModel()

    private let twoColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let typeColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("Режим", selection: $model.mode) {
                    ForEach(ModbusRegistersViewModel.Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch model.mode {
                case .decode: decodeContent
                case .encode: encodeContent
                case .address: addressContent
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Регистры Modbus")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: model.noteTitle, summary: model.summary, category: .automation)
    }

    // MARK: Registers → values

    @ViewBuilder
    private var decodeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Регистры подряд с адреса n")
            LazyVGrid(columns: twoColumns, spacing: 10) {
                ForEach(0..<ModbusRegistersViewModel.registerSlots, id: \.self) { index in
                    NumericField(
                        label: "Рег. \(ModbusRegistersViewModel.registerName(index))",
                        text: $model.registerTexts[index],
                        keyboard: model.registersInHex ? .asciiCapable : .numbersAndPunctuation,
                        isInvalid: model.isRegisterInvalid(index)
                    )
                }
            }
            Toggle(
                "Регистры в HEX",
                isOn: Binding(get: { model.registersInHex }, set: { model.setRegistersInHex($0) })
            )
            .font(.subheadline)
            if let error = model.registerError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.fault)
            } else if model.registers.count < 2 {
                Text("2 регистра — 32-битные типы, 4 — 64-битные.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .industrialCard()

        let registers = model.registers
        if !registers.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("16 бит")
                ForEach(Array(registers.enumerated()), id: \.offset) { index, value in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Рег. \(ModbusRegistersViewModel.registerName(index))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(value.hexString(digits: 4))
                                .font(.monoBody.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        ValueRow(label: "UINT16", value: String(value))
                        ValueRow(label: "INT16", value: String(Int16(bitPattern: value)))
                        ValueRow(label: "Биты 15…0", value: ModbusCodec.groupedBinary(value))
                    }
                    if index < registers.count - 1 {
                        Divider()
                    }
                }
            }
            .industrialCard()

            ForEach(model.wideTypes) { type in
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("\(type.title) · рег. n…n+\(type.registerCount - 1)")
                    ForEach(model.decodedRows(type)) { row in
                        ValueRow(label: row.label, value: row.value)
                    }
                }
                .industrialCard()
            }

            if !model.wideTypes.isEmpty {
                Text("Верный порядок байт обычно даёт единственное правдоподобное значение.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Value → registers

    @ViewBuilder
    private var encodeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Тип данных")
            LazyVGrid(columns: typeColumns, spacing: 8) {
                ForEach(RegisterDataType.allCases) { type in
                    ChoiceChip(
                        title: type.title,
                        subtitle: "\(type.registerCount) рег.",
                        isSelected: model.encodeType == type
                    ) {
                        model.encodeType = type
                    }
                }
            }
            NumericField(label: "Значение", text: $model.encodeText, isInvalid: model.isEncodeInvalid)
            Text(model.encodeType.inputHint)
                .font(.caption)
                .foregroundStyle(model.isEncodeInvalid ? Theme.fault : Color.secondary)
        }
        .industrialCard()

        let rows = model.encodedRows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Регистры n, n+1, …")
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.label)
                                .font(.monoBody.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                            Text(row.order.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            CopyButton(value: row.hex)
                        }
                        Text(row.hex)
                            .font(.monoBody)
                            .textSelection(.enabled)
                        Text(row.decimal)
                            .font(.monoCaption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .industrialCard()
        }
    }

    // MARK: Addressing

    @ViewBuilder
    private var addressContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Адрес → смещение")
            NumericField(
                label: "Адрес 0xxxx / 1xxxx / 3xxxx / 4xxxx",
                text: $model.referenceText,
                keyboard: .numberPad,
                isInvalid: model.isReferenceInvalid
            )
            if let address = model.referenceAddress {
                ValueRow(label: "Область", value: address.area.title, copyable: false)
                ValueRow(label: "Тип", value: address.area.detail, copyable: false)
                ValueRow(label: "Функция чтения", value: address.area.readFunction, copyable: false)
                ValueRow(label: "Функции записи", value: address.area.writeFunctions, copyable: false)
                ValueRow(label: "Смещение в PDU", value: String(address.offset), valueColor: Theme.accent)
                ValueRow(label: "Смещение HEX", value: "0x" + address.offset.hexString(digits: 4))
            } else if model.isReferenceInvalid {
                Text("5 цифр (40001…49999) или 6 цифр (400001…465536); первая цифра 0, 1, 3 или 4.")
                    .font(.caption)
                    .foregroundStyle(Theme.fault)
            }
        }
        .industrialCard()

        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Смещение → адрес")
            LazyVGrid(columns: twoColumns, spacing: 8) {
                ForEach(ModbusArea.allCases) { area in
                    ChoiceChip(title: "\(area.rawValue)x", subtitle: area.title, isSelected: model.offsetArea == area) {
                        model.offsetArea = area
                    }
                }
            }
            NumericField(
                label: "Смещение в PDU (с нуля)",
                text: $model.offsetText,
                keyboard: .numberPad,
                isInvalid: model.isOffsetInvalid
            )
            if let address = model.offsetAddress {
                ValueRow(label: "5-значный адрес", value: address.fiveDigitReference ?? "не помещается")
                ValueRow(label: "6-значный адрес", value: address.sixDigitReference)
            }
        }
        .industrialCard()

        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Области Modbus")
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Адрес")
                    Text("Область")
                    Text("Чтение")
                    Text("Запись")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Divider()
                ForEach(ModbusArea.allCases) { area in
                    GridRow {
                        Text("\(area.rawValue)xxxx").font(.monoCaption)
                        Text(area.title).font(.caption)
                        Text(area.readFunction).font(.monoCaption)
                        Text(area.writeFunctions).font(.monoCaption)
                    }
                }
            }
            Text("В пакете передаётся смещение с нуля: 40001 → 0. Часть ПЛК и SCADA нумерует регистры с нуля — сверяйтесь с документацией устройства.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }
}
