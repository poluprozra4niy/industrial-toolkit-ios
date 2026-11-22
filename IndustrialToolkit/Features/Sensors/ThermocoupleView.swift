import SwiftUI

struct ThermocoupleView: View {
    private enum Direction: String, CaseIterable, Identifiable {
        case toTemperature
        case toEmf

        var id: String { rawValue }

        var title: String {
            switch self {
            case .toTemperature: "мВ → °C"
            case .toEmf: "°C → мВ"
            }
        }
    }

    @State private var direction: Direction = .toTemperature
    @State private var emfText = "4,096"
    @State private var temperatureText = "100"
    @State private var coldJunctionText = "0"

    private let tileColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    private var coldJunction: Double? {
        NumberParser.parse(coldJunctionText).flatMap { ThermocoupleTypeK.temperatureRange.contains($0) ? $0 : nil }
    }

    /// (hot junction °C, meter reading mV) for the current input.
    private var reading: (temperature: Double, measured: Double)? {
        guard let coldJunction else { return nil }
        switch direction {
        case .toTemperature:
            guard let measured = NumberParser.parse(emfText),
                  let temperature = ThermocoupleTypeK.temperature(measuredMillivolts: measured, coldJunction: coldJunction)
            else { return nil }
            return (temperature, measured)
        case .toEmf:
            guard let temperature = NumberParser.parse(temperatureText),
                  let measured = ThermocoupleTypeK.measuredMillivolts(temperature: temperature, coldJunction: coldJunction)
            else { return nil }
            return (temperature, measured)
        }
    }

    private var isInputInvalid: Bool {
        let text = direction == .toTemperature ? emfText : temperatureText
        return !text.isEmpty && reading == nil && coldJunction != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                inputCard
                resultCard
                Text("Источник: \(ThermocoupleTypeK.source). Погрешность аппроксимации \(ThermocoupleTypeK.maximumError). Диапазон −200…1372 °C (−5,891…54,886 мВ). Тип L (ТХК) — после сверки полиномов ГОСТ Р 8.585.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Термопара K (ТХА)")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: "Термопара K", summary: summary, category: .automation)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Направление", selection: $direction) {
                ForEach(Direction.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            switch direction {
            case .toTemperature:
                NumericField(label: "ТЭДС на клеммах прибора", text: $emfText, unit: "мВ", isInvalid: isInputInvalid)
            case .toEmf:
                NumericField(label: "Температура рабочего спая", text: $temperatureText, unit: "°C", isInvalid: isInputInvalid)
            }
            NumericField(label: "Температура холодного спая (клемм)", text: $coldJunctionText, unit: "°C", isInvalid: coldJunction == nil)
            Text("0 °C — табличная ТЭДС. Для прибора на объекте введите температуру его клемм: так учитывается компенсация холодного спая.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if isInputInvalid {
                Label("Вне диапазона −200…1372 °C", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.fault)
            }
        }
        .industrialCard()
    }

    @ViewBuilder
    private var resultCard: some View {
        if let reading {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: tileColumns, spacing: 10) {
                    MetricTile(
                        title: "Температура",
                        value: Fmt.fixed(reading.temperature, fractionDigits: 1),
                        unit: "°C",
                        isInput: direction == .toEmf
                    )
                    MetricTile(
                        title: "ТЭДС на приборе",
                        value: Fmt.fixed(reading.measured, fractionDigits: 3),
                        unit: "мВ",
                        isInput: direction == .toTemperature
                    )
                }
                if let sensitivity = ThermocoupleTypeK.sensitivity(temperature: reading.temperature) {
                    ValueRow(label: "Чувствительность", value: "\(Fmt.number(sensitivity, fractionDigits: 1)) мкВ/°C", copyable: false)
                }
                if let coldJunction, coldJunction != 0, let full = ThermocoupleTypeK.millivolts(temperature: reading.temperature) {
                    ValueRow(label: "ТЭДС при 0 °C на клеммах", value: "\(Fmt.fixed(full, fractionDigits: 3)) мВ")
                }
            }
            .industrialCard()
        }
    }

    private var summary: String? {
        guard let reading, let coldJunction else { return nil }
        return [
            "Термопара K (ТХА), \(ThermocoupleTypeK.source)",
            "t рабочего спая = \(Fmt.fixed(reading.temperature, fractionDigits: 1)) °C",
            "t холодного спая = \(Fmt.number(coldJunction, fractionDigits: 1)) °C",
            "ТЭДС на приборе = \(Fmt.fixed(reading.measured, fractionDigits: 3)) мВ",
        ].joined(separator: "\n")
    }
}
