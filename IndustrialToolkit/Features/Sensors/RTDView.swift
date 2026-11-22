import SwiftUI

struct RTDView: View {
    @State private var model = RTDViewModel()

    private let curveColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private let nominalColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    private let tileColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                sensorCard
                inputCard
                resultCard
                tableLink
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Термосопротивления")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: model.noteTitle, summary: model.summary, category: .automation)
    }

    private var sensorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Тип ТС")
            LazyVGrid(columns: curveColumns, spacing: 8) {
                ForEach(RTDCurve.allCases) { curve in
                    ChoiceChip(title: curve.title, subtitle: curve.alphaTitle, isSelected: model.curve == curve) {
                        model.curve = curve
                    }
                }
            }
            SectionLabel("R₀ при 0 °C")
            LazyVGrid(columns: nominalColumns, spacing: 8) {
                ForEach(RTDSensor.nominalOptions, id: \.self) { nominal in
                    ChoiceChip(
                        title: Fmt.number(nominal, fractionDigits: 0),
                        subtitle: "Ом",
                        isSelected: model.nominal == nominal
                    ) {
                        model.nominal = nominal
                    }
                }
            }
            let sensor = model.sensor
            Text("\(sensor.name) · \(model.curve.standard) · \(Fmt.number(model.curve.range.lowerBound, fractionDigits: 0))…\(Fmt.number(model.curve.range.upperBound, fractionDigits: 0)) °C")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Направление", selection: Binding(get: { model.direction }, set: { model.selectDirection($0) })) {
                ForEach(RTDViewModel.Direction.allCases) { direction in
                    Text(direction.title).tag(direction)
                }
            }
            .pickerStyle(.segmented)
            switch model.direction {
            case .toResistance:
                NumericField(label: "Температура", text: $model.temperatureText, unit: "°C", isInvalid: model.isInputInvalid)
            case .toTemperature:
                NumericField(label: "Сопротивление", text: $model.resistanceText, unit: "Ом", isInvalid: model.isInputInvalid)
            }
            if let error = model.inputError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.fault)
            }
        }
        .industrialCard()
    }

    @ViewBuilder
    private var resultCard: some View {
        if let reading = model.reading {
            let sensor = model.sensor
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Результат · \(sensor.name)")
                LazyVGrid(columns: tileColumns, spacing: 10) {
                    MetricTile(
                        title: "Температура",
                        value: Fmt.fixed(reading.temperature, fractionDigits: 2),
                        unit: "°C",
                        isInput: model.direction == .toResistance
                    )
                    MetricTile(
                        title: "Сопротивление",
                        value: Fmt.fixed(reading.resistance, fractionDigits: 3),
                        unit: "Ом",
                        isInput: model.direction == .toTemperature
                    )
                    MetricTile(
                        title: "Чувствительность",
                        value: Fmt.fixed(sensor.sensitivity(at: reading.temperature), fractionDigits: 4),
                        unit: "Ом/°C"
                    )
                    MetricTile(title: "W₁₀₀", value: Fmt.fixed(sensor.w100, fractionDigits: 4), unit: "R₁₀₀ / R₀")
                }

                Divider()

                SectionLabel("2-проводная схема")
                NumericField(
                    label: "Сопротивление линии (обе жилы)",
                    text: $model.lineResistanceText,
                    unit: "Ом",
                    isInvalid: model.isLineResistanceInvalid
                )
                if let error = model.twoWireError {
                    ValueRow(
                        label: "Завышение показаний",
                        value: "+\(Fmt.fixed(error, fractionDigits: 2)) °C",
                        valueColor: error > 0.5 ? Theme.warning : Color.primary
                    )
                }
                Text("3-проводная схема компенсирует линию при равных жилах, 4-проводная — полностью.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .industrialCard()
        }
    }

    private var tableLink: some View {
        NavigationLink {
            RTDTableView(sensor: model.sensor)
        } label: {
            HStack {
                Label("Таблица R(t) для \(model.sensor.name)", systemImage: "tablecells")
                    .font(.body.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .industrialCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct RTDTableView: View {
    static let stepOptions: [Double] = [1, 5, 10, 50]

    let sensor: RTDSensor
    @State private var step: Double = 10

    private var tableText: String {
        let rows = sensor.table(step: step).map {
            "\(Fmt.number($0.temperature, fractionDigits: 0))\t\(Fmt.fixed($0.resistance, fractionDigits: 3))"
        }
        return (["\(sensor.name), шаг \(Fmt.number(step, fractionDigits: 0)) °C", "t, °C\tR, Ом"] + rows).joined(separator: "\n")
    }

    var body: some View {
        let rows = sensor.table(step: step)
        List {
            Section {
                HStack(spacing: 8) {
                    ForEach(Self.stepOptions, id: \.self) { option in
                        ChoiceChip(title: Fmt.number(option, fractionDigits: 0), subtitle: "°C", isSelected: step == option) {
                            step = option
                        }
                    }
                }
            } header: {
                Text("Шаг таблицы")
            }
            .listRowBackground(Theme.surface)

            Section {
                ForEach(rows) { row in
                    HStack {
                        Text(Fmt.number(row.temperature, fractionDigits: 0))
                            .foregroundStyle(row.temperature == 0 ? Theme.accent : Color.primary)
                        Spacer()
                        Text(Fmt.fixed(row.resistance, fractionDigits: 3))
                    }
                    .font(.monoBody)
                    .monospacedDigit()
                    .listRowBackground(Theme.surface)
                }
            } header: {
                HStack {
                    Text("t, °C")
                    Spacer()
                    Text("R, Ом")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("\(sensor.name): R(t)")
        .navigationBarTitleDisplayMode(.inline)
        .resultActions(title: "Таблица \(sensor.name)", summary: tableText, category: .automation)
    }
}
