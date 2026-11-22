import SwiftUI

struct CableSizingView: View {
    @State private var currentText = "25"
    @State private var material: ConductorMaterial = .copper
    @State private var isCable = false
    @State private var laying: ConductorLaying = .wiresPipe3
    @State private var bundle: WireBundle = .upToFour

    private let layingColumns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    private let bundleColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    private var current: Double? { NumberParser.parse(currentText).flatMap { $0 > 0 ? $0 : nil } }

    private var effectiveBundle: WireBundle { laying.isWire ? bundle : .upToFour }

    private var entries: [AmpacityEntry] {
        CableAmpacity.entries(material: material, laying: laying, bundle: effectiveBundle)
    }

    private var selected: AmpacityEntry? {
        current.flatMap { CableAmpacity.minimumSection(for: $0, material: material, laying: laying, bundle: effectiveBundle) }
    }

    private var tableNumber: String { CableAmpacity.tableNumber(material: material, laying: laying) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                inputCard
                resultCard
                tableCard
                Text("Источник: ПУЭ, гл. 1.3, табл. 1.3.4–1.3.7 и п. 1.3.10. \(CableAmpacity.conditions). При другой температуре среды — поправочные коэффициенты табл. 1.3.3 (в приложение не внесены). Четырёхжильные кабели с пластмассовой изоляцией до 1 кВ с алюминиевыми жилами — по табл. 1.3.7 как трёхжильные с коэффициентом 0,92.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Сечение кабеля")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: "Сечение по току \(currentText) А", summary: summary, category: .electrical)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            NumericField(label: "Расчётный ток", text: $currentText, unit: "А", isInvalid: current == nil)
            HStack(spacing: 8) {
                ForEach(ConductorMaterial.allCases) { option in
                    ChoiceChip(title: option.title, isSelected: material == option) { material = option }
                }
            }
            Picker("Тип", selection: Binding(get: { isCable }, set: { selectGroup(cable: $0) })) {
                Text("Провода").tag(false)
                Text("Кабели").tag(true)
            }
            .pickerStyle(.segmented)
            SectionLabel("Прокладка · табл. \(tableNumber)")
            LazyVGrid(columns: layingColumns, spacing: 8) {
                ForEach(isCable ? ConductorLaying.cables : ConductorLaying.wires) { option in
                    ChoiceChip(title: option.title, isSelected: laying == option) { laying = option }
                }
            }
            if laying.isWire {
                SectionLabel("Нагруженных проводов в трубе / коробе / пучке")
                LazyVGrid(columns: bundleColumns, spacing: 8) {
                    ForEach(WireBundle.allCases) { option in
                        ChoiceChip(
                            title: option.title,
                            subtitle: option == .upToFour ? "по табл." : "×\(Fmt.number(option.factor, fractionDigits: 2))",
                            isSelected: bundle == option
                        ) {
                            bundle = option
                        }
                    }
                }
                if bundle != .upToFour {
                    Text("Более 4 проводов: ток как для открытой прокладки × \(Fmt.number(bundle.factor, fractionDigits: 2)) (п. 1.3.10). Для вторичных цепей коэффициент не вводится.")
                        .font(.caption)
                        .foregroundStyle(Theme.info)
                }
            }
        }
        .industrialCard()
    }

    @ViewBuilder
    private var resultCard: some View {
        if let current {
            if let selected {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        MetricTile(title: "Минимальное сечение", value: CableSections.title(selected.section), unit: "мм² · \(material.title.lowercased())")
                        MetricTile(title: "Допустимый ток", value: Fmt.number(selected.ampacity, fractionDigits: 1), unit: "А · табл. \(tableNumber)")
                    }
                    ValueRow(
                        label: "Запас по току",
                        value: "\(Fmt.number((selected.ampacity / current - 1) * 100, fractionDigits: 0)) %",
                        copyable: false
                    )
                    Text("Проверьте также падение напряжения и отключение защиты при КЗ.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .industrialCard()
            } else {
                StatusBanner(
                    title: "Нет сечения в таблице",
                    detail: "Ток \(Fmt.number(current, fractionDigits: 1)) А больше максимального для этой прокладки — разделите линию на параллельные кабели или выберите другую прокладку",
                    symbol: "exclamationmark.octagon.fill",
                    tint: Theme.fault
                )
            }
        }
    }

    private var tableCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Табл. \(tableNumber): \(laying.title.lowercased())")
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("мм²")
                    Text("Iдоп, А").gridColumnAlignment(.trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Divider()
                ForEach(entries) { entry in
                    let isSelected = entry.section == selected?.section
                    GridRow {
                        Text(CableSections.title(entry.section))
                        Text(Fmt.number(entry.ampacity, fractionDigits: 1))
                    }
                    .font(.monoBody.weight(isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Theme.accent : Color.primary)
                }
            }
        }
        .industrialCard()
    }

    private func selectGroup(cable: Bool) {
        isCable = cable
        laying = cable ? .cableThreeAir : .wiresPipe3
    }

    private var summary: String? {
        guard let current, let selected else { return nil }
        var lines = [
            "Сечение по допустимому длительному току (ПУЭ, табл. \(tableNumber))",
            "Ток: \(Fmt.number(current, fractionDigits: 1)) А; \(material.title.lowercased()); \(laying.title.lowercased())",
        ]
        if laying.isWire && bundle != .upToFour {
            lines.append("Проводов в пучке: \(bundle.title), коэффициент \(Fmt.number(bundle.factor, fractionDigits: 2)) (п. 1.3.10)")
        }
        lines.append("Минимальное сечение: \(CableSections.title(selected.section)) мм², Iдоп = \(Fmt.number(selected.ampacity, fractionDigits: 1)) А")
        lines.append(CableAmpacity.conditions)
        return lines.joined(separator: "\n")
    }
}
