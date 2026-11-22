import SwiftUI

struct UnitConverterView: View {
    @State private var model = UnitConverterViewModel()

    private let unitColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("Величина", selection: Binding(get: { model.category }, set: { model.select($0) })) {
                    ForEach(UnitCategory.allCases) { category in
                        Text(category.title).tag(category)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 12) {
                    NumericField(label: "Значение", text: $model.valueText, unit: model.unit.symbol, isInvalid: model.isValueInvalid)
                    if model.isBelowAbsoluteZero {
                        Text("Ниже абсолютного нуля (−273,15 °C).")
                            .font(.caption)
                            .foregroundStyle(Theme.fault)
                    }
                    SectionLabel("Единица ввода")
                    LazyVGrid(columns: unitColumns, spacing: 8) {
                        ForEach(model.category.units) { unit in
                            ChoiceChip(title: unit.symbol, isSelected: model.unit == unit) {
                                model.select(unit)
                            }
                        }
                    }
                    if model.needsDensity {
                        NumericField(
                            label: "Плотность среды (для м³ ↔ т)",
                            text: $model.densityText,
                            unit: "кг/м³",
                            isInvalid: model.isDensityInvalid
                        )
                    }
                }
                .industrialCard()

                let rows = model.rows
                if !rows.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Результат")
                        ForEach(rows) { row in
                            ValueRow(
                                label: row.unit.symbol,
                                value: row.value,
                                valueColor: row.unit == model.unit ? Theme.accent : .primary
                            )
                        }
                    }
                    .industrialCard()
                }

                if model.category == .pressure {
                    Text("Единицы кгс/см², мм и м вод. ст. определены через g = 9,80665 м/с²; мм рт. ст. — 133,322 Па. Избыточное и абсолютное давление отличаются на атмосферное (≈ 1,013 бар).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Конвертер единиц")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: model.noteTitle, summary: model.summary, category: .automation)
    }
}
