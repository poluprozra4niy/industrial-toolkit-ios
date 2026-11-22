import SwiftUI

struct ModbusAddressView: View {
    @State private var model = ModbusAddressViewModel()

    private let notationColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private let areaColumns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                inputCard
                if let input = model.input {
                    representationsCard(input)
                    requestCard(input)
                    if !model.rangeRows.isEmpty {
                        rangeCard
                    }
                }
                referenceCard
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Адреса Modbus")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: model.noteTitle, summary: model.summary, category: .automation)
    }

    // MARK: Input

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Формат ввода")
            LazyVGrid(columns: notationColumns, spacing: 8) {
                ForEach(ModbusAddressNotation.allCases) { notation in
                    ChoiceChip(
                        title: notation.title,
                        subtitle: notation.subtitle,
                        isSelected: model.notation == notation
                    ) {
                        model.select(notation)
                    }
                }
            }
            if model.notation.needsArea {
                SectionLabel("Область")
                LazyVGrid(columns: areaColumns, spacing: 8) {
                    ForEach(ModbusArea.allCases) { area in
                        ChoiceChip(
                            title: "FC\(area.readFunction)",
                            subtitle: area.title,
                            isSelected: model.area == area
                        ) {
                            model.area = area
                        }
                    }
                }
            }
            NumericField(
                label: "Адрес",
                text: $model.addressText,
                keyboard: model.notation == .offsetHex || model.notation == .schneider ? .asciiCapable : .numbersAndPunctuation,
                isInvalid: model.isAddressInvalid
            )
            Text(model.notation.hint)
                .font(.caption)
                .foregroundStyle(model.isAddressInvalid ? Theme.fault : Color.secondary)
            if let input = model.input {
                StatusBanner(
                    title: input.address.area.title,
                    detail: "\(input.address.area.detail) · чтение FC\(input.address.area.readFunction) · запись \(input.address.area.writeFunctions)",
                    symbol: input.address.area.isRegister ? "square.grid.3x2" : "switch.2",
                    tint: Theme.accent
                )
            }
            if let note = model.ambiguityNote {
                Label(note, systemImage: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .industrialCard()
    }

    // MARK: Results

    private func representationsCard(_ input: ModbusAddressInput) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(input.bit == nil ? "Все форматы" : "Все форматы · бит \(input.bit ?? 0)")
            ForEach(model.rows) { row in
                ValueRow(
                    label: row.label,
                    value: row.value,
                    valueColor: row.label.hasPrefix("Смещение DEC") ? Theme.accent : .primary
                )
            }
        }
        .industrialCard()
    }

    private func requestCard(_ input: ModbusAddressInput) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Запрос чтения FC\(input.address.area.readFunction)")
            HStack(alignment: .top, spacing: 10) {
                NumericField(
                    label: "Количество, \(input.address.area.unitName)",
                    text: $model.quantityText,
                    keyboard: .numberPad,
                    isInvalid: model.isQuantityInvalid
                )
                NumericField(
                    label: model.transport == .rtu ? "Адрес ведомого" : "Unit ID",
                    text: $model.unitText,
                    keyboard: .numberPad,
                    isInvalid: model.isUnitInvalid
                )
            }
            Picker("Протокол", selection: $model.transport) {
                ForEach(ModbusAddressViewModel.Transport.allCases) { transport in
                    Text(transport.title).tag(transport)
                }
            }
            .pickerStyle(.segmented)

            if let error = model.quantityError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.fault)
            }
            if let warning = model.unitWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }

            if let request = model.request {
                if let last = request.lastAddress, request.quantity > 1 {
                    ValueRow(
                        label: "Диапазон",
                        value: "\(input.address.sixDigitReference)…\(last.sixDigitReference)",
                        copyable: false
                    )
                    ValueRow(
                        label: "Смещения",
                        value: "\(request.offset)…\(last.offset)",
                        copyable: false
                    )
                }
                ValueRow(label: "PDU", value: ModbusReadRequest.hex(request.pdu))
                if let frame = model.frame {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(model.transport == .rtu ? "Кадр RTU (CRC младшим байтом вперёд)" : "Кадр TCP (MBAP, Transaction ID 0001)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            CopyButton(value: ModbusReadRequest.hex(frame))
                        }
                        Text(ModbusReadRequest.hex(frame))
                            .font(.monoBody.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .textSelection(.enabled)
                    }
                    .fieldChrome()
                }
                if let length = model.responseLength {
                    ValueRow(label: "Ожидаемый ответ", value: "\(length) байт", copyable: false)
                }
            }
        }
        .industrialCard()
    }

    private var rangeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Карта диапазона")
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Modicon")
                    Text("DEC")
                    Text("HEX")
                    Text("С 1")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Divider()
                ForEach(model.rangeRows) { row in
                    GridRow {
                        Text(row.address.sixDigitReference)
                        Text(String(row.address.offset))
                        Text(row.address.offset.hexString(digits: 4))
                        Text(String(row.address.oneBasedNumber))
                    }
                    .font(.monoCaption)
                }
            }
            if let request = model.request, request.quantity > ModbusAddressViewModel.rangeRowLimit {
                Text("Показаны первые \(ModbusAddressViewModel.rangeRowLimit) из \(request.quantity).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .industrialCard()
    }

    // MARK: Reference

    private var referenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Лимиты протокола")
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Область")
                    Text("Чтение")
                    Text("Запись")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Divider()
                ForEach(ModbusArea.allCases) { area in
                    GridRow {
                        Text(area.title).font(.caption)
                        Text("FC\(area.readFunction): до \(area.maxReadQuantity)").font(.monoCaption)
                        Text(writeLimit(area)).font(.monoCaption)
                    }
                }
            }
            Text("В пакете всегда передаётся смещение с нуля: 40001 → 0x0000. Если устройство отвечает соседним регистром — проверьте, с 0 или с 1 нумерует его документация.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }

    private func writeLimit(_ area: ModbusArea) -> String {
        switch area {
        case .coils: "FC05: 1, FC15: до \(area.maxWriteQuantity ?? 0)"
        case .holdingRegisters: "FC06: 1, FC16: до \(area.maxWriteQuantity ?? 0)"
        case .discreteInputs, .inputRegisters: "—"
        }
    }
}
