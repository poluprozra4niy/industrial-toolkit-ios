import SwiftUI

struct VoltageDropView: View {
    @State private var model = VoltageDropViewModel()

    private let tileColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                networkCard
                loadCard
                lineCard
                resultCard
                sectionsCard
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Падение напряжения")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: model.noteTitle, summary: model.summary, category: .electrical)
    }

    // MARK: Inputs

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Сеть")
            HStack(spacing: 8) {
                ForEach(PowerSystem.allCases) { system in
                    ChoiceChip(title: system.title, subtitle: system.subtitle, isSelected: model.system == system) {
                        model.selectSystem(system)
                    }
                }
            }
            NumericField(
                label: model.system == .threePhase ? "Линейное напряжение" : "Напряжение",
                text: $model.voltageText,
                unit: "В",
                isInvalid: model.isVoltageInvalid
            )
            SectionLabel("Проводник")
            HStack(spacing: 8) {
                ForEach(ConductorMaterial.allCases) { material in
                    ChoiceChip(title: material.title, isSelected: model.material == material) {
                        model.material = material
                    }
                }
            }
            HStack(spacing: 8) {
                ForEach(ConductorTemperature.allCases) { temperature in
                    ChoiceChip(title: temperature.title, subtitle: temperature.subtitle, isSelected: model.temperature == temperature) {
                        model.temperature = temperature
                    }
                }
            }
        }
        .industrialCard()
    }

    private var loadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Нагрузка")
            Picker("Нагрузка", selection: Binding(get: { model.loadInput }, set: { model.selectLoadInput($0) })) {
                ForEach(VoltageDropViewModel.LoadInput.allCases) { input in
                    Text(input.title).tag(input)
                }
            }
            .pickerStyle(.segmented)
            HStack(alignment: .top, spacing: 10) {
                NumericField(
                    label: model.loadInput == .current ? "Ток нагрузки" : "Мощность нагрузки",
                    text: $model.loadText,
                    unit: model.loadInput == .current ? "А" : "кВт",
                    isInvalid: model.isLoadInvalid
                )
                if model.system.isAC {
                    NumericField(label: "cos φ", text: $model.powerFactorText, isInvalid: model.isPowerFactorInvalid)
                }
            }
            if model.loadInput == .power, let current = model.current {
                ValueRow(label: "Расчётный ток", value: "\(Fmt.number(current, fractionDigits: 2)) А")
            }
        }
        .industrialCard()
    }

    private var lineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Линия")
            HStack(alignment: .top, spacing: 10) {
                NumericField(
                    label: "Длина трассы (в одну сторону)",
                    text: $model.lengthText,
                    unit: "м",
                    isInvalid: model.isLengthInvalid
                )
                sectionPicker
            }
            HStack(alignment: .top, spacing: 10) {
                if model.system.isAC {
                    NumericField(
                        label: "x, Ом/км",
                        text: $model.reactanceText,
                        isInvalid: model.isReactanceInvalid
                    )
                }
                NumericField(
                    label: "Допустимое ΔU",
                    text: $model.allowedText,
                    unit: "%",
                    isInvalid: model.isAllowedInvalid
                )
            }
            if let message = model.validationMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.fault)
            }
        }
        .industrialCard()
    }

    private var sectionPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Сечение")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Menu {
                Picker("Сечение", selection: $model.section) {
                    ForEach(CableSections.standard, id: \.self) { section in
                        Text("\(CableSections.title(section)) мм²").tag(section)
                    }
                }
            } label: {
                HStack {
                    Text(CableSections.title(model.section))
                        .font(.system(.title3, design: .monospaced, weight: .medium))
                        .foregroundStyle(Color.primary)
                    Text("мм²")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .fieldChrome()
            }
            .accessibilityLabel("Сечение \(CableSections.title(model.section)) квадратных миллиметров")
        }
    }

    // MARK: Outputs

    @ViewBuilder
    private var resultCard: some View {
        if let result = model.result {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Результат")
                LazyVGrid(columns: tileColumns, spacing: 10) {
                    MetricTile(title: "ΔU", value: Fmt.fixed(result.dropPercent, fractionDigits: 2), unit: "%")
                    MetricTile(title: "ΔU", value: Fmt.fixed(result.drop, fractionDigits: 2), unit: "В")
                    MetricTile(title: "U на нагрузке", value: Fmt.fixed(result.loadVoltage, fractionDigits: 1), unit: "В")
                    let loss = VoltageDropViewModel.powerReading(result.powerLoss)
                    MetricTile(title: "Потери в линии", value: loss.value, unit: loss.unit)
                }
                StatusBanner(
                    title: result.isWithinLimit ? "В пределах допустимого" : "Превышение допустимого ΔU",
                    detail: result.isWithinLimit
                        ? "Запас до предела: \(Fmt.fixed(model.marginPercent ?? 0, fractionDigits: 2)) %"
                        : "Увеличьте сечение или сократите длину трассы",
                    symbol: result.isWithinLimit ? "checkmark.circle.fill" : "exclamationmark.octagon.fill",
                    tint: result.isWithinLimit ? Theme.ok : Theme.fault
                )
                VStack(spacing: 8) {
                    ValueRow(
                        label: "Мин. сечение по ΔU",
                        value: result.recommendedSection.map { "\(CableSections.title($0)) мм²" } ?? "> 300 мм²",
                        valueColor: result.recommendedSection == nil ? Theme.fault : Theme.accent
                    )
                    if let minimum = result.minimumSection {
                        ValueRow(label: "Расчётное значение", value: "\(Fmt.number(minimum, fractionDigits: 2)) мм²", copyable: false)
                    }
                    ValueRow(label: "Макс. длина при \(CableSections.title(model.section)) мм²", value: "\(Fmt.number(result.maximumLength, fractionDigits: 0)) м")
                }
                Label("Сечение по нагреву (длительно допустимому току) проверяется отдельно.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .industrialCard()
        }
    }

    @ViewBuilder
    private var sectionsCard: some View {
        let rows = model.sectionRows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("ΔU по сечениям · нажмите, чтобы выбрать")
                Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("мм²").gridColumnAlignment(.leading)
                        Text("ΔU, В")
                        Text("ΔU, %")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    Divider()
                    ForEach(rows) { row in
                        let isSelected = row.section == model.section
                        GridRow {
                            Text(CableSections.title(row.section))
                                .fontWeight(isSelected ? .bold : .regular)
                                .foregroundStyle(isSelected ? Theme.accent : Color.primary)
                            Text(Fmt.fixed(row.drop, fractionDigits: 2))
                            Text(Fmt.fixed(row.dropPercent, fractionDigits: 2))
                                .foregroundStyle(row.isWithinLimit ? Theme.ok : Theme.fault)
                        }
                        .font(.monoBody)
                        .monospacedDigit()
                        .contentShape(Rectangle())
                        .onTapGesture { model.section = row.section }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
            .industrialCard()
        }
    }
}
