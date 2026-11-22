import SwiftUI

struct BreakersView: View {
    private enum FaultInput: String, CaseIterable, Identifiable {
        case impedance
        case current

        var id: String { rawValue }

        var title: String {
            switch self {
            case .impedance: "Zпетли, Ом"
            case .current: "Iкз, А"
            }
        }
    }

    @State private var curve: BreakerCurve = .c
    @State private var rating: Double = 16
    @State private var faultInput: FaultInput = .impedance
    @State private var voltageText = "230"
    @State private var impedanceText = "0,8"
    @State private var faultCurrentText = "300"

    private let curveColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private let ratingColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    private var selection: BreakerSelection { BreakerSelection(curve: curve, rating: rating) }

    private var voltage: Double? { NumberParser.parse(voltageText).flatMap { $0 > 0 ? $0 : nil } }

    private var faultCurrent: Double? {
        switch faultInput {
        case .impedance:
            guard let voltage, let impedance = NumberParser.parse(impedanceText) else { return nil }
            return BreakerSelection.faultCurrent(phaseVoltage: voltage, loopImpedance: impedance)
        case .current:
            return NumberParser.parse(faultCurrentText).flatMap { $0 > 0 ? $0 : nil }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                selectionCard
                characteristicsCard
                loopCard
                Text("Источник: \(BreakerSelection.source) — табл. 2 (мгновенное расцепление), 5.3.2 (номиналы), 5.2.2 (контрольная температура \(Fmt.number(BreakerSelection.referenceTemperature, fractionDigits: 0)) °C), времятоковые испытания. Выбор типа зависит от правил монтажа (4.6).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Автоматы B / C / D")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: "Автомат \(selection.name)", summary: summary, category: .electrical)
    }

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Характеристика")
            LazyVGrid(columns: curveColumns, spacing: 8) {
                ForEach(BreakerCurve.allCases) { option in
                    ChoiceChip(
                        title: option.title,
                        subtitle: "\(Fmt.number(option.lowerMultiple, fractionDigits: 0))–\(Fmt.number(option.upperMultiple, fractionDigits: 0)) In",
                        isSelected: curve == option
                    ) {
                        curve = option
                    }
                }
            }
            Text(curve.typicalUse)
                .font(.caption)
                .foregroundStyle(.secondary)
            SectionLabel("Номинальный ток In, А")
            LazyVGrid(columns: ratingColumns, spacing: 8) {
                ForEach(BreakerSelection.preferredRatings, id: \.self) { value in
                    ChoiceChip(title: Fmt.number(value, fractionDigits: 0), isSelected: rating == value) {
                        rating = value
                    }
                }
            }
        }
        .industrialCard()
    }

    private var characteristicsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Автомат \(selection.name)")
            HStack(spacing: 10) {
                MetricTile(
                    title: "Мгновенное расцепление",
                    value: "\(Fmt.number(selection.instantaneousLower, fractionDigits: 0))…\(Fmt.number(selection.instantaneousUpper, fractionDigits: 0))",
                    unit: "А (св. \(Fmt.number(curve.lowerMultiple, fractionDigits: 0)) до \(Fmt.number(curve.upperMultiple, fractionDigits: 0)) In вкл.)"
                )
            }
            ValueRow(
                label: "1,13 In = \(Fmt.number(selection.nonTrippingCurrent, fractionDigits: 1)) А",
                value: "не срабатывает \(selection.conventionalTime)",
                copyable: false
            )
            ValueRow(
                label: "1,45 In = \(Fmt.number(selection.trippingCurrent, fractionDigits: 1)) А",
                value: "срабатывает < \(selection.conventionalTime)",
                copyable: false
            )
            ValueRow(
                label: "2,55 In = \(Fmt.number(selection.thermalTestCurrent, fractionDigits: 1)) А",
                value: selection.thermalTestWindow,
                copyable: false
            )
            ValueRow(
                label: "\(Fmt.number(curve.lowerMultiple, fractionDigits: 0)) In = \(Fmt.number(selection.instantaneousLower, fractionDigits: 0)) А",
                value: "не срабатывает за 0,1 с",
                copyable: false
            )
            ValueRow(
                label: "\(Fmt.number(curve.upperMultiple, fractionDigits: 0)) In = \(Fmt.number(selection.instantaneousUpper, fractionDigits: 0)) А",
                value: "срабатывает < 0,1 с",
                copyable: false
            )
            Text("Время при 1,13 In и 1,45 In: 1 ч для In ≤ 63 А, 2 ч для In > 63 А. Калибровка при \(Fmt.number(BreakerSelection.referenceTemperature, fractionDigits: 0)) °C.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }

    private var loopCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Проверка петли фаза–ноль")
            Picker("Исходные данные", selection: $faultInput) {
                ForEach(FaultInput.allCases) { input in
                    Text(input.title).tag(input)
                }
            }
            .pickerStyle(.segmented)
            HStack(alignment: .top, spacing: 10) {
                NumericField(label: "U₀ (фаза–ноль)", text: $voltageText, unit: "В", isInvalid: voltage == nil)
                switch faultInput {
                case .impedance:
                    NumericField(label: "Zпетли", text: $impedanceText, unit: "Ом", isInvalid: faultCurrent == nil)
                case .current:
                    NumericField(label: "Iкз", text: $faultCurrentText, unit: "А", isInvalid: faultCurrent == nil)
                }
            }
            if let faultCurrent {
                let verdict = selection.verdict(faultCurrent: faultCurrent)
                ValueRow(label: "Ток КЗ", value: "\(Fmt.number(faultCurrent, fractionDigits: 0)) А", copyable: false)
                StatusBanner(
                    title: verdict.title,
                    detail: verdict.detail(for: selection),
                    symbol: verdict.symbol,
                    tint: verdict.tint
                )
            }
            if let voltage, let maxImpedance = selection.maximumLoopImpedance(phaseVoltage: voltage) {
                ValueRow(
                    label: "Макс. Zпетли для \(selection.name)",
                    value: "\(Fmt.number(maxImpedance, fractionDigits: 3)) Ом",
                    valueColor: Theme.accent
                )
            }
            Text("Iкз = U₀ / Zпетли. Гарантированное мгновенное отключение — при Iкз ≥ верхней границы диапазона. Требуемое время отключения — по ПУЭ / ГОСТ Р 50571.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }

    private var summary: String {
        var lines = [
            "Автомат \(selection.name) (\(BreakerSelection.source))",
            "Мгновенное расцепление: \(Fmt.number(selection.instantaneousLower, fractionDigits: 0))…\(Fmt.number(selection.instantaneousUpper, fractionDigits: 0)) А",
            "1,13 In = \(Fmt.number(selection.nonTrippingCurrent, fractionDigits: 1)) А: не срабатывает \(selection.conventionalTime)",
            "1,45 In = \(Fmt.number(selection.trippingCurrent, fractionDigits: 1)) А: срабатывает < \(selection.conventionalTime)",
            "2,55 In = \(Fmt.number(selection.thermalTestCurrent, fractionDigits: 1)) А: \(selection.thermalTestWindow)",
        ]
        if let faultCurrent {
            lines.append("Iкз = \(Fmt.number(faultCurrent, fractionDigits: 0)) А: \(selection.verdict(faultCurrent: faultCurrent).title)")
        }
        return lines.joined(separator: "\n")
    }
}

private extension InstantaneousTripVerdict {
    var title: String {
        switch self {
        case .guaranteed: "Мгновенное отключение гарантировано"
        case .uncertain: "В зоне разброса расцепителя"
        case .thermalOnly: "Только тепловой расцепитель"
        }
    }

    func detail(for selection: BreakerSelection) -> String {
        switch self {
        case .guaranteed:
            return "Iкз ≥ \(Fmt.number(selection.instantaneousUpper, fractionDigits: 0)) А — любой автомат \(selection.name) отключит без выдержки"
        case .uncertain:
            return "Конкретный экземпляр может сработать мгновенно, а может с выдержкой. Снизьте Zпетли или выберите тип с меньшей кратностью"
        case .thermalOnly:
            return "Iкз ≤ \(Fmt.number(selection.instantaneousLower, fractionDigits: 0)) А — отключение с выдержкой времени, возможна опасность"
        }
    }

    var symbol: String {
        switch self {
        case .guaranteed: "checkmark.circle.fill"
        case .uncertain: "exclamationmark.triangle.fill"
        case .thermalOnly: "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .guaranteed: Theme.ok
        case .uncertain: Theme.warning
        case .thermalOnly: Theme.fault
        }
    }
}
