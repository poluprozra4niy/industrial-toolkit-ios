import SwiftUI

struct ModbusResponseView: View {
    @State private var model = ModbusResponseViewModel()

    private let typeColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    private let bitColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                inputCard
                if let frame = model.frame {
                    headerCard(frame)
                    if case .exception(_, let code) = frame.body {
                        exceptionCard(code)
                    }
                    if model.registers != nil {
                        registersCard
                    }
                    if model.bits != nil {
                        bitsCard
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Разбор кадра Modbus")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: model.noteTitle, summary: model.summary, category: .automation)
    }

    // MARK: Input

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Формат кадра", selection: $model.framing) {
                ForEach(ModbusFraming.allCases) { framing in
                    Text(framing.title).tag(framing)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                Text("Байты кадра, HEX")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("11 03 06 02 2B …", text: $model.frameText, axis: .vertical)
                    .font(.monoBody)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .lineLimit(2...6)
                    .fieldChrome(isInvalid: model.isFrameInvalid)
            }
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(model.isFrameInvalid ? Theme.fault : Color.secondary)
            } else {
                Text("Вставьте строку из терминала или сниффера. Разделители — пробел, запятая, двоеточие; 0x допускается.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .industrialCard()
    }

    // MARK: Header

    private func headerCard(_ frame: ModbusFrame) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(frame.body.kindTitle)
            if let crc = frame.crc {
                StatusBanner(
                    title: crc.isValid ? "CRC верный" : "CRC не сходится",
                    detail: crc.isValid
                        ? "В кадре \(crcBytes(crc.received))"
                        : "В кадре \(crcBytes(crc.received)), должно быть \(crcBytes(crc.computed))",
                    symbol: crc.isValid ? "checkmark.seal.fill" : "xmark.seal.fill",
                    tint: crc.isValid ? Theme.ok : Theme.fault
                )
            }
            if let transaction = frame.transactionID {
                ValueRow(label: "Transaction ID", value: "0x" + transaction.hexString(digits: 4), copyable: false)
            }
            if let unit = frame.unit {
                ValueRow(
                    label: frame.framing == .rtu ? "Адрес устройства" : "Unit ID",
                    value: "\(unit) (0x\(unit.hexString(digits: 2)))",
                    valueColor: Theme.accent,
                    copyable: false
                )
            }
            ValueRow(
                label: "Функция",
                value: "\(frame.body.function.hexString(digits: 2)) · \(ModbusPDU.functionName(frame.body.function))",
                copyable: false
            )
            if let area = frame.body.area {
                ValueRow(label: "Область", value: area.title, copyable: false)
            }
            detailRows(frame.body)
            ValueRow(label: "PDU", value: ModbusReadRequest.hex(frame.pdu))
            ForEach(frame.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
        }
        .industrialCard()
    }

    @ViewBuilder
    private func detailRows(_ body: ModbusPDU) -> some View {
        switch body {
        case .readRequest(_, let address, let quantity):
            addressRow(address)
            ValueRow(label: "Количество", value: String(quantity), copyable: false)
        case .writeSingle(let function, let address, let value):
            addressRow(address)
            ValueRow(label: "Значение", value: singleValue(function: function, value: value))
        case .writeMultipleResponse(_, let address, let quantity),
             .writeCoilsRequest(let address, let quantity, _),
             .writeRegistersRequest(let address, let quantity, _):
            addressRow(address)
            ValueRow(label: "Количество", value: String(quantity), copyable: false)
        case .readBits(_, let values):
            ValueRow(label: "Байт данных", value: String(values.count / 8), copyable: false)
        case .readRegisters(_, let values):
            ValueRow(label: "Регистров", value: String(values.count), copyable: false)
        case .exception:
            EmptyView()
        }
    }

    private func addressRow(_ offset: Int) -> some View {
        let reference = model.frame?.body.area
            .flatMap { ModbusAddress(area: $0, offset: offset) }
            .map { " · \($0.sixDigitReference)" } ?? ""
        return ValueRow(label: "Адрес", value: "\(offset) (0x\(offset.hexString(digits: 4)))\(reference)")
    }

    private func singleValue(function: UInt8, value: UInt16) -> String {
        guard function == 0x05 else { return "\(value) (0x\(value.hexString(digits: 4)), INT16 \(Int16(bitPattern: value)))" }
        switch value {
        case 0xFF00: return "FF00 — ВКЛ"
        case 0x0000: return "0000 — ВЫКЛ"
        default: return value.hexString(digits: 4) + " — недопустимо"
        }
    }

    private func crcBytes(_ crc: UInt16) -> String {
        ModbusReadRequest.hex([UInt8(crc & 0xFF), UInt8(crc >> 8)])
    }

    // MARK: Exception

    private func exceptionCard(_ code: UInt8) -> some View {
        let exception = ModbusExceptionCode.describe(code)
        return StatusBanner(
            title: "Ошибка \(code.hexString(digits: 2)) · \(exception.name)",
            detail: exception.hint,
            symbol: "exclamationmark.octagon.fill",
            tint: Theme.fault
        )
    }

    // MARK: Values

    private var startField: some View {
        NumericField(
            label: "Смещение первого элемента из запроса (с 0, DEC или 0x)",
            text: $model.startText,
            keyboard: .asciiCapable,
            isInvalid: model.isStartInvalid
        )
    }

    private var registersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Значения регистров")
            if model.needsStartAddress {
                startField
            }
            LazyVGrid(columns: typeColumns, spacing: 8) {
                ForEach(model.availableTypes) { type in
                    ChoiceChip(title: type.title, subtitle: "\(type.registerCount) рег.", isSelected: model.dataType == type) {
                        model.select(type)
                    }
                }
            }
            LazyVGrid(columns: typeColumns, spacing: 8) {
                ForEach(model.availableOrders) { order in
                    ChoiceChip(
                        title: ModbusCodec.wireLabel(order: order, byteCount: model.dataType.byteCount),
                        subtitle: order.subtitle,
                        isSelected: model.order == order
                    ) {
                        model.order = order
                    }
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    Text("Адрес")
                    Text("HEX")
                    Text(model.dataType.title)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Divider()
                ForEach(model.registerRows) { row in
                    GridRow {
                        Text(row.address).font(.monoCaption)
                        Text(row.raw).font(.monoCaption).foregroundStyle(.secondary)
                        Text(row.value)
                            .font(.monoBody.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .textSelection(.enabled)
                    }
                }
            }
            if model.registerRows.isEmpty {
                Text("Регистров меньше, чем нужно для \(model.dataType.title).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .industrialCard()
    }

    private var bitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Состояния битов")
            if model.needsStartAddress {
                startField
                Text("Ответ дополняет последний байт нулями до 8 бит — лишние биты за пределами запрошенного количества не значимы.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: bitColumns, spacing: 6) {
                ForEach(model.bitRows) { row in
                    VStack(spacing: 2) {
                        Text(row.isOn ? "1" : "0")
                            .font(.monoBody.weight(.bold))
                            .foregroundStyle(row.isOn ? Theme.accent : Color.secondary)
                        Text(row.address)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        row.isOn ? Theme.accent.opacity(0.14) : Theme.surfaceSunken,
                        in: RoundedRectangle(cornerRadius: Theme.fieldCornerRadius)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(row.address): \(row.isOn ? "включён" : "выключен")")
                }
            }
        }
        .industrialCard()
    }
}
