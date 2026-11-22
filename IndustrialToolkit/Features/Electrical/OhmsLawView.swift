import SwiftUI

struct OhmsLawView: View {
    @State private var model = OhmsLawViewModel()

    private let pairColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private let tileColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("Режим", selection: $model.mode) {
                    ForEach(OhmsLawViewModel.Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch model.mode {
                case .dc: dcContent
                case .ac: acContent
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Закон Ома и мощность")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: model.noteTitle, summary: model.summary, category: .electrical)
    }

    // MARK: DC

    @ViewBuilder
    private var dcContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Что известно")
            LazyVGrid(columns: pairColumns, spacing: 8) {
                ForEach(OhmPair.allCases) { pair in
                    ChoiceChip(title: pair.title, isSelected: model.pair == pair) {
                        model.selectPair(pair)
                    }
                }
            }
            let known = model.pair.quantities
            unitField(known.first)
            unitField(known.second)
        }
        .industrialCard()

        if let solution = model.solution {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Результат")
                LazyVGrid(columns: tileColumns, spacing: 10) {
                    ForEach(OhmQuantity.allCases) { quantity in
                        let reading = EngineeringNotation.format(solution.value(of: quantity), unit: quantity.baseUnit)
                        MetricTile(
                            title: "\(quantity.symbol) · \(quantity.title)",
                            value: reading.value,
                            unit: reading.unit,
                            isInput: model.pair.contains(quantity)
                        )
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.pair.formulas, id: \.self) { formula in
                        Text(formula)
                            .font(.monoBody)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .industrialCard()
        } else {
            Label("Введите два положительных значения", systemImage: "keyboard")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .industrialCard()
        }
    }

    private func unitField(_ quantity: OhmQuantity) -> some View {
        UnitField(
            quantity: quantity,
            text: Binding(get: { model.text(for: quantity) }, set: { model.setText($0, for: quantity) }),
            unit: Binding(get: { model.unit(for: quantity) }, set: { model.setUnit($0, for: quantity) }),
            isInvalid: model.isInvalid(quantity)
        )
    }

    // MARK: AC

    @ViewBuilder
    private var acContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Сеть")
            HStack(spacing: 8) {
                ForEach([PowerSystem.singlePhase, .threePhase]) { system in
                    ChoiceChip(title: system.title, subtitle: system.subtitle, isSelected: model.system == system) {
                        model.selectSystem(system)
                    }
                }
            }
            Picker("Известно", selection: $model.acInput) {
                ForEach(ACPowerInput.allCases) { input in
                    Text(input.title).tag(input)
                }
            }
            .pickerStyle(.segmented)

            NumericField(
                label: model.system == .threePhase ? "Линейное напряжение" : "Напряжение",
                text: $model.voltageText,
                unit: "В",
                isInvalid: model.isVoltageInvalid
            )
            switch model.acInput {
            case .voltageCurrent:
                HStack(alignment: .top, spacing: 10) {
                    NumericField(label: "Ток", text: $model.currentText, unit: "А", isInvalid: model.isCurrentInvalid)
                    NumericField(label: "cos φ", text: $model.powerFactorText, isInvalid: model.isPowerFactorInvalid)
                }
            case .activePower:
                HStack(alignment: .top, spacing: 10) {
                    NumericField(label: "Активная P", text: $model.activeKWText, unit: "кВт", isInvalid: model.isActiveInvalid)
                    NumericField(label: "cos φ", text: $model.powerFactorText, isInvalid: model.isPowerFactorInvalid)
                }
            case .activeReactive:
                HStack(alignment: .top, spacing: 10) {
                    NumericField(label: "Активная P", text: $model.activeKWText, unit: "кВт", isInvalid: model.isActiveInvalid)
                    NumericField(label: "Реактивная Q", text: $model.reactiveKvarText, unit: "квар", isInvalid: model.isReactiveInvalid)
                }
            }
        }
        .industrialCard()

        if let result = model.acResult {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Треугольник мощностей")
                LazyVGrid(columns: tileColumns, spacing: 10) {
                    powerTile("S · полная", result.apparent, "В·А")
                    powerTile("P · активная", result.active, "Вт")
                    powerTile("Q · реактивная", result.reactive, "вар")
                    MetricTile(title: "I · ток", value: Fmt.number(result.current, fractionDigits: 2), unit: "А")
                    MetricTile(title: "cos φ", value: Fmt.fixed(result.powerFactor, fractionDigits: 3), unit: "коэффициент мощности")
                    MetricTile(title: "φ", value: Fmt.number(result.phiDegrees, fractionDigits: 1), unit: "градусы")
                }
                Text(model.system == .threePhase ? "S = √3 · U · I,  P = S · cos φ,  Q = S · sin φ" : "S = U · I,  P = S · cos φ,  Q = S · sin φ")
                    .font(.monoCaption)
                    .foregroundStyle(.secondary)
            }
            .industrialCard()

            compensationCard(result)
        }
    }

    private func powerTile(_ title: String, _ value: Double, _ unit: String) -> MetricTile {
        let reading = EngineeringNotation.format(value, unit: unit, fractionDigits: 2)
        return MetricTile(title: title, value: reading.value, unit: reading.unit)
    }

    private func compensationCard(_ result: ACPowerResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Компенсация реактивной мощности")
            NumericField(label: "Целевой cos φ", text: $model.targetPowerFactorText, isInvalid: model.isTargetInvalid)
            if let compensation = model.compensation {
                if compensation > 0 {
                    ValueRow(label: "Мощность КРМ", value: OhmsLawViewModel.reading(compensation, "вар"), valueColor: Theme.accent)
                } else {
                    Label("Компенсация не требуется: cos φ уже не ниже целевого", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.ok)
                }
            }
            Text("Qc = P · (tg φ₁ − tg φ₂)")
                .font(.monoCaption)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }
}

/// Numeric field with a unit menu (мА / А, Ом / кОм / МОм …).
private struct UnitField: View {
    let quantity: OhmQuantity
    @Binding var text: String
    @Binding var unit: EngineeringUnit
    let isInvalid: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(quantity.symbol) · \(quantity.title)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("0", text: $text)
                    .keyboardType(.numbersAndPunctuation)
                    .font(.system(.title3, design: .monospaced, weight: .medium))
                    .autocorrectionDisabled()
                Menu {
                    Picker("Единица", selection: $unit) {
                        ForEach(quantity.units, id: \.self) { option in
                            Text(option.symbol).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(unit.symbol)
                            .font(.system(.callout, design: .monospaced))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Единица: \(unit.symbol)")
            }
            .fieldChrome(isInvalid: isInvalid)
        }
    }
}
