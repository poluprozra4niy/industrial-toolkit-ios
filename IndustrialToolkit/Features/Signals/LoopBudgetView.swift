import SwiftUI

struct LoopBudgetView: View {
    @State private var model = LoopBudgetViewModel()

    private let twoColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let currentColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                sourceCard
                resistanceCard
                if let budget = model.budget {
                    resultCard(budget)
                    loadCard(budget)
                } else {
                    Label("Введите неотрицательные значения", systemImage: "keyboard")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .industrialCard()
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Нагрузка контура 4–20 мА")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: model.noteTitle, summary: model.summary, category: .automation)
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Питание и датчик")
            LazyVGrid(columns: twoColumns, spacing: 10) {
                NumericField(label: "Блок питания", text: $model.supplyText, unit: "В", isInvalid: model.isInvalid(model.supplyText))
                NumericField(label: "Мин. на датчике", text: $model.transmitterMinimumText, unit: "В", isInvalid: model.isInvalid(model.transmitterMinimumText))
            }
            SectionLabel("Расчётный ток")
            LazyVGrid(columns: currentColumns, spacing: 8) {
                ForEach(LoopBudgetViewModel.currentOptions) { option in
                    ChoiceChip(
                        title: Fmt.number(option.milliamps, fractionDigits: 1),
                        subtitle: option.caption,
                        isSelected: model.currentMilliamps == option.milliamps
                    ) {
                        model.currentMilliamps = option.milliamps
                    }
                }
            }
            Text("Минимальное напряжение — из паспорта датчика (обычно 10,5…12 В, с HART и индикатором больше). Проверяйте при аварийном токе: при отказе датчик выдаёт до 22 мА.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }

    private var resistanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Сопротивления в контуре")
            NumericField(label: "Входы и нагрузки (AI ПЛК, индикатор, HART-резистор)", text: $model.loadText, unit: "Ом", isInvalid: model.isInvalid(model.loadText))
            LazyVGrid(columns: twoColumns, spacing: 10) {
                NumericField(label: "Длина линии", text: $model.lengthText, unit: "м", isInvalid: model.isInvalid(model.lengthText))
                NumericField(label: "Сечение жилы", text: $model.sectionText, unit: "мм²", isInvalid: model.section == nil)
            }
            Picker("Материал", selection: $model.material) {
                ForEach(ConductorMaterial.allCases) { material in
                    Text(material.title).tag(material)
                }
            }
            .pickerStyle(.segmented)
            if let line = model.lineResistance {
                ValueRow(label: "Линия, обе жилы", value: "\(Fmt.number(line, fractionDigits: 1)) Ом", copyable: false)
            }
            LazyVGrid(columns: twoColumns, spacing: 10) {
                NumericField(label: "Барьер / изолятор", text: $model.barrierResistanceText, unit: "Ом", isInvalid: model.isInvalid(model.barrierResistanceText))
                NumericField(label: "Падение на нём", text: $model.barrierDropText, unit: "В", isInvalid: model.isInvalid(model.barrierDropText))
            }
            Text("Пассивный барьер на стабилитронах задают сопротивлением, активный изолятор — падением напряжения (из паспорта).")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Проверить для HART", isOn: $model.checksHART)
                .font(.subheadline)
        }
        .industrialCard()
    }

    private func resultCard(_ budget: LoopBudget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Результат при \(Fmt.number(model.currentMilliamps, fractionDigits: 1)) мА")
            StatusBanner(
                title: budget.isSufficient ? "Питания хватает" : "Питания не хватает",
                detail: "Запас \(Fmt.number(budget.margin, fractionDigits: 2)) В: на датчике \(Fmt.number(budget.terminalVoltage, fractionDigits: 2)) В при минимуме \(Fmt.number(budget.transmitterMinimumVoltage, fractionDigits: 2)) В",
                symbol: budget.isSufficient ? "checkmark.circle.fill" : "xmark.octagon.fill",
                tint: budget.isSufficient ? Theme.ok : Theme.fault
            )
            ValueRow(label: "Сумма сопротивлений", value: "\(Fmt.number(budget.totalResistance, fractionDigits: 1)) Ом")
            ValueRow(label: "Допустимое сопротивление", value: "\(Fmt.number(budget.maximumResistance, fractionDigits: 0)) Ом", valueColor: Theme.accent)
            ValueRow(label: "Мин. напряжение питания", value: "\(Fmt.number(budget.minimumSupplyVoltage, fractionDigits: 2)) В")
            if let length = model.maximumLineLength {
                ValueRow(label: "Макс. длина линии", value: "\(Fmt.number(length, fractionDigits: 0)) м")
            }
            if model.checksHART {
                Label(
                    budget.meetsHART
                        ? "HART: в контуре ≥ 230 Ом — связь возможна"
                        : "HART: нужно ≥ 230 Ом в контуре (обычно резистор 250 Ом)",
                    systemImage: budget.meetsHART ? "checkmark.circle" : "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(budget.meetsHART ? Theme.ok : Theme.warning)
            }
        }
        .industrialCard()
    }

    private func loadCard(_ budget: LoopBudget) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Напряжение на нагрузке \(Fmt.number(budget.loadResistance, fractionDigits: 0)) Ом")
            ForEach([4.0, 12.0, 20.0], id: \.self) { milliamps in
                ValueRow(
                    label: "\(Fmt.number(milliamps, fractionDigits: 0)) мА",
                    value: "\(Fmt.number(budget.voltageAcrossLoad(at: milliamps / 1_000), fractionDigits: 3)) В"
                )
            }
            Text("Шунт 250 Ом превращает 4–20 мА в 1–5 В для входа по напряжению.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }
}
