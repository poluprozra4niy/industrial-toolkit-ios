import SwiftUI

struct SignalConverterView: View {
    @State private var model: SignalConverterViewModel

    /// `preset` opens the converter already set to a tag's scale (from the I/O list).
    init(preset: SignalConverterViewModel? = nil) {
        _model = State(initialValue: preset ?? SignalConverterViewModel())
    }

    private let chipColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private let tileColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                signalCard
                scaleCard
                inputCard
                resultCard
                loopCheckCard
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Конвертер сигналов")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: model.noteTitle, summary: model.summary, category: .automation)
    }

    // MARK: Inputs

    private var signalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Тип сигнала")
            LazyVGrid(columns: chipColumns, spacing: 8) {
                ForEach(SignalRange.allCases) { range in
                    ChoiceChip(title: range.title, isSelected: model.signalRange == range) {
                        model.signalRange = range
                    }
                }
            }
        }
        .industrialCard()
    }

    private var scaleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Шкала прибора")
            HStack(alignment: .top, spacing: 10) {
                NumericField(label: "НПИ (0 %)", text: $model.lowText, unit: model.unit, isInvalid: model.isLowInvalid)
                NumericField(label: "ВПИ (100 %)", text: $model.highText, unit: model.unit, isInvalid: model.isHighInvalid)
            }
            unitField
            Toggle(isOn: $model.squareRoot) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Корнеизвлечение")
                    Text("Расход по перепаду давления: Q ~ √ΔP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let error = model.scaleError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.fault)
            }
        }
        .industrialCard()
    }

    private var unitField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Единица величины")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                TextField("ед.", text: $model.unit)
                    .font(.system(.title3, design: .monospaced, weight: .medium))
                    .autocorrectionDisabled()
                Menu {
                    ForEach(SignalConverterViewModel.unitPresets, id: \.self) { preset in
                        Button(preset) { model.unit = preset }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Выбрать единицу")
            }
            .fieldChrome()
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Что известно")
            Picker("Вход", selection: Binding(get: { model.inputKind }, set: { model.selectInputKind($0) })) {
                ForEach(SignalConverterViewModel.InputKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            NumericField(
                label: model.inputLabel,
                text: $model.inputText,
                unit: model.inputUnit,
                isInvalid: model.isInputInvalid
            )

            HStack {
                Text("Шкала АЦП ПЛК")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Шкала АЦП", selection: $model.rawRange) {
                    ForEach(RawCountRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .industrialCard()
    }

    // MARK: Outputs

    @ViewBuilder
    private var resultCard: some View {
        if let result = model.result {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Результат")
                LazyVGrid(columns: tileColumns, spacing: 10) {
                    MetricTile(
                        title: "Сигнал",
                        value: Fmt.fixed(result.signal, fractionDigits: 3),
                        unit: model.signalRange.unit,
                        isInput: model.inputKind == .signal
                    )
                    MetricTile(
                        title: "Величина",
                        value: Fmt.number(result.processValue, fractionDigits: 3),
                        unit: model.unit,
                        isInput: model.inputKind == .processValue
                    )
                    MetricTile(
                        title: "Шкала",
                        value: Fmt.fixed(result.processFraction * 100, fractionDigits: 2),
                        unit: model.squareRoot ? "% величины" : "%"
                    )
                    MetricTile(
                        title: "Код АЦП",
                        value: Fmt.number(result.rawCounts, fractionDigits: 0),
                        unit: model.rawRange.title,
                        isInput: model.inputKind == .rawCounts
                    )
                }
                if model.squareRoot {
                    ValueRow(label: "% сигнала", value: Fmt.fixed(result.signalFraction * 100, fractionDigits: 2) + " %")
                }
                ScaleBar(fraction: result.signalFraction, tint: result.health.tint)
                StatusBanner(
                    title: result.health.title,
                    detail: result.health.detail(for: model.signalRange),
                    symbol: result.health.symbol,
                    tint: result.health.tint
                )
            }
            .industrialCard()
        } else if model.scaleError == nil {
            Label("Введите значение для расчёта", systemImage: "keyboard")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .industrialCard()
        }
    }

    @ViewBuilder
    private var loopCheckCard: some View {
        if let scale = model.scale {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Таблица проверки контура")
                Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("%").gridColumnAlignment(.leading)
                        Text(model.signalRange.unit)
                        Text(model.unit.isEmpty ? "ПВ" : model.unit)
                        Text("Код")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    Divider()
                    ForEach(Array(scale.loopCheckTable.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            Text(Fmt.number(row.signalFraction * 100, fractionDigits: 0))
                            Text(Fmt.fixed(row.signal, fractionDigits: 2))
                            Text(Fmt.number(row.processValue, fractionDigits: 3))
                            Text(Fmt.number(row.rawCounts, fractionDigits: 0))
                        }
                        .font(.monoBody)
                        .monospacedDigit()
                    }
                }
            }
            .industrialCard()
        }
    }
}

// MARK: - Scale bar

/// Horizontal position indicator over −12.5 % … 112.5 % so NAMUR saturation/failure zones stay visible.
private struct ScaleBar: View {
    let fraction: Double
    let tint: Color

    private static let domain: ClosedRange<Double> = -0.125...1.125
    private static let ticks: [Double] = [0, 0.25, 0.5, 0.75, 1]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let zero = Self.position(0, width: width)
            let full = Self.position(1, width: width)
            let marker = Self.position(fraction, width: width)
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.surfaceSunken)
                Rectangle()
                    .fill(Theme.border.opacity(0.6))
                    .frame(width: full - zero)
                    .offset(x: zero)
                Rectangle()
                    .fill(tint.opacity(0.45))
                    .frame(width: abs(marker - zero))
                    .offset(x: min(marker, zero))
                ForEach(Self.ticks, id: \.self) { tick in
                    Rectangle()
                        .fill(Color.secondary)
                        .frame(width: 1, height: 6)
                        .offset(x: Self.position(tick, width: width))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                Rectangle()
                    .fill(tint)
                    .frame(width: 3)
                    .offset(x: marker - 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .frame(height: 16)
        .accessibilityElement()
        .accessibilityLabel("Положение на шкале")
        .accessibilityValue("\(Fmt.fixed(fraction * 100, fractionDigits: 1)) процентов")
    }

    private static func position(_ value: Double, width: CGFloat) -> CGFloat {
        let clamped = min(max(value, domain.lowerBound), domain.upperBound)
        return CGFloat((clamped - domain.lowerBound) / (domain.upperBound - domain.lowerBound)) * width
    }
}

private extension SignalHealth {
    var tint: Color {
        switch self {
        case .normal: Theme.ok
        case .underRange, .overRange: Theme.warning
        case .failureLow, .failureHigh: Theme.fault
        }
    }

    var symbol: String {
        switch self {
        case .normal: "checkmark.circle.fill"
        case .underRange: "arrow.down.to.line"
        case .overRange: "arrow.up.to.line"
        case .failureLow, .failureHigh: "exclamationmark.octagon.fill"
        }
    }
}
