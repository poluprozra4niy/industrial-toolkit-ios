import SwiftUI

struct MotorView: View {
    @State private var model = MotorViewModel()

    private let twoColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let voltageColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                nameplateCard
                if let motor = model.motor {
                    currentsCard(motor)
                    breakersCard(motor)
                    inverterCard(motor)
                } else {
                    Label(model.validationHint, systemImage: "keyboard")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .industrialCard()
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Двигатель и частотник")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: model.noteTitle, summary: model.summary, category: .electrical)
    }

    private var nameplateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Шильдик двигателя")
            Picker("Сеть", selection: Binding(get: { model.supply }, set: { model.selectSupply($0) })) {
                ForEach(MotorSupply.allCases) { supply in
                    Text(supply.title).tag(supply)
                }
            }
            .pickerStyle(.segmented)
            LazyVGrid(columns: twoColumns, spacing: 10) {
                NumericField(label: "Мощность на валу", text: $model.powerText, unit: "кВт", isInvalid: model.isInvalid(model.powerText))
                NumericField(label: "Напряжение", text: $model.voltageText, unit: "В", isInvalid: model.isInvalid(model.voltageText))
            }
            LazyVGrid(columns: voltageColumns, spacing: 8) {
                ForEach(MotorViewModel.voltagePresets, id: \.self) { voltage in
                    let title = Fmt.number(voltage, fractionDigits: 0)
                    ChoiceChip(title: title, isSelected: model.voltageText == title) {
                        model.voltageText = title
                    }
                }
            }
            LazyVGrid(columns: twoColumns, spacing: 10) {
                NumericField(label: "cos φ", text: $model.cosPhiText, isInvalid: model.isInvalid(model.cosPhiText))
                NumericField(label: "КПД", text: $model.efficiencyText, unit: "%", isInvalid: model.isInvalid(model.efficiencyText))
                NumericField(label: "Обороты", text: $model.speedText, unit: "об/мин", isInvalid: model.isInvalid(model.speedText))
                NumericField(label: "Частота сети", text: $model.frequencyText, unit: "Гц", isInvalid: model.isInvalid(model.frequencyText))
            }
            NumericField(label: "Кратность пускового тока Iп/Iн", text: $model.startingRatioText, isInvalid: model.isInvalid(model.startingRatioText))
        }
        .industrialCard()
    }

    private func currentsCard(_ motor: MotorNameplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Токи и мощность")
            LazyVGrid(columns: twoColumns, spacing: 10) {
                MetricTile(title: "Iн", value: Fmt.number(motor.ratedCurrent, fractionDigits: 2), unit: "А")
                MetricTile(title: "Iп прямой пуск", value: Fmt.number(motor.startingCurrent, fractionDigits: 1), unit: "А")
            }
            ValueRow(label: "Iп при пуске Y/Δ", value: "\(Fmt.number(motor.starDeltaStartingCurrent, fractionDigits: 1)) А")
            ValueRow(label: "Потребляемая P", value: "\(Fmt.number(motor.inputPower, fractionDigits: 2)) кВт")
            ValueRow(label: "Полная S", value: "\(Fmt.number(motor.apparentPower, fractionDigits: 2)) кВА")
            ValueRow(label: "Реактивная Q", value: "\(Fmt.number(motor.reactivePower, fractionDigits: 2)) квар")
            ValueRow(label: "Момент на валу", value: "\(Fmt.number(motor.ratedTorque, fractionDigits: 1)) Н·м")
            ValueRow(label: "Синхронная скорость", value: "\(Fmt.number(motor.synchronousSpeed, fractionDigits: 0)) об/мин")
            ValueRow(label: "Пар полюсов / скольжение", value: "\(motor.polePairs) / \(Fmt.number(motor.slip * 100, fractionDigits: 1)) %", copyable: false)
            Text("Пуск Y/Δ снижает пусковой ток и момент в 3 раза; ударный ток первого полупериода выше Iп.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }

    private func breakersCard(_ motor: MotorNameplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Автомат по ГОСТ IEC 60898-1")
            ForEach(BreakerCurve.allCases) { curve in
                if let check = motor.breakerCheck(curve: curve) {
                    StatusBanner(
                        title: "\(check.breaker.name): \(check.survivesStart ? "прямой пуск выдержит" : "может сработать при пуске")",
                        detail: "Мгновенный расцепитель \(Fmt.number(check.breaker.instantaneousLower, fractionDigits: 0))…\(Fmt.number(check.breaker.instantaneousUpper, fractionDigits: 0)) А, Iп = \(Fmt.number(motor.startingCurrent, fractionDigits: 0)) А",
                        symbol: check.survivesStart ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                        tint: check.survivesStart ? Theme.ok : Theme.warning
                    )
                }
            }
            if motor.breakerCheck(curve: .c) == nil {
                Text("Номинальный ток больше 125 А — нужен автомат в литом корпусе или мотор-автомат.")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
            Text("Проверка только мгновенного расцепителя. Тепловой расцепитель при затяжном пуске и защиту от перегрузки двигателя выбирайте по каталогу (мотор-автомат, тепловое реле).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }

    private func inverterCard(_ motor: MotorNameplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Частотный преобразователь")
            NumericField(label: "Выходная частота", text: $model.outputFrequencyText, unit: "Гц", isInvalid: model.outputFrequency == nil)
            if let frequency = model.outputFrequency {
                ValueRow(label: "Обороты при \(Fmt.number(frequency, fractionDigits: 1)) Гц", value: "\(Fmt.number(motor.speed(atFrequency: frequency), fractionDigits: 0)) об/мин", valueColor: Theme.accent)
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("f, Гц")
                    Text("n, об/мин")
                    Text("n, %")
                    Text("P насоса, кВт")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Divider()
                ForEach(model.frequencyRows) { row in
                    GridRow {
                        Text(Fmt.number(row.frequency, fractionDigits: 1))
                        Text(Fmt.number(row.speed, fractionDigits: 0))
                        Text(Fmt.number(row.percent, fractionDigits: 0))
                        Text(Fmt.number(row.pumpPower, fractionDigits: 2))
                    }
                    .font(.monoCaption)
                }
            }
            Text("Скорость — при скалярном управлении U/f со скольжением как на номинале. Мощность центробежного насоса или вентилятора — по законам подобия: Q ∝ n, H ∝ n², P ∝ n³.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }
}
