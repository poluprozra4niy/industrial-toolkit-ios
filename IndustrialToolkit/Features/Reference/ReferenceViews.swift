import SwiftUI

// MARK: - IP rating

struct IPRatingView: View {
    @State private var codeText = "IP65"

    private let chipColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    private var codes: [IPRating.Code]? { IPRating.parse(codeText) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                inputCard
                if let codes {
                    ForEach(Array(codes.enumerated()), id: \.offset) { _, code in
                        decodedCard(code)
                    }
                    let notes = IPRating.waterNotes(for: codes)
                    if !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(notes, id: \.self) { note in
                                StatusBanner(title: "Вода", detail: note, symbol: "drop.triangle", tint: Theme.info)
                            }
                        }
                    }
                }
                referenceCard(title: "Первая цифра — доступ и твёрдые предметы", items: IPRating.solids)
                referenceCard(title: "Вторая цифра — вода", items: IPRating.water)
                referenceCard(title: "Дополнительная буква (доступ людей)", items: IPRating.additionalLetters)
                referenceCard(title: "Вспомогательная буква", items: IPRating.supplementaryLetters)
                Text("Источник: \(IPRating.source). X вместо цифры — характеристика не нормируется.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Степень защиты IP")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            NumericField(
                label: "Код IP (IP65, IPX7, IP2XC, IP66/IP67)",
                text: $codeText,
                keyboard: .asciiCapable,
                isInvalid: !codeText.isEmpty && codes == nil
            )
            LazyVGrid(columns: chipColumns, spacing: 8) {
                ForEach(IPRating.commonCodes, id: \.self) { code in
                    ChoiceChip(title: code, isSelected: codeText.uppercased() == code) {
                        codeText = code
                    }
                }
            }
        }
        .industrialCard()
    }

    private func decodedCard(_ code: IPRating.Code) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Расшифровка")
            digitRow(symbol: code.first.map { String($0) } ?? "X", info: IPRating.solid(code.first), fallback: "Не нормируется")
            digitRow(symbol: code.second.map { String($0) } ?? "X", info: IPRating.waterInfo(code.second), fallback: "Не нормируется")
            if let letter = IPRating.letter(code.additional, in: IPRating.additionalLetters) {
                digitRow(symbol: letter.code, info: letter, fallback: "")
            }
            ForEach(code.supplementary, id: \.self) { character in
                if let letter = IPRating.letter(character, in: IPRating.supplementaryLetters) {
                    digitRow(symbol: letter.code, info: letter, fallback: "")
                }
            }
        }
        .industrialCard()
    }

    private func digitRow(symbol: String, info: IPDigitInfo?, fallback: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(symbol)
                .font(.readout)
                .foregroundStyle(Theme.accent)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(info?.title ?? fallback)
                    .font(.subheadline.weight(.semibold))
                if let detail = info?.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func referenceCard(title: String, items: [IPDigitInfo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
            ForEach(items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(item.code)
                        .font(.monoBody.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.subheadline)
                        if !item.detail.isEmpty {
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .industrialCard()
    }
}

// MARK: - Conductor colours

struct ConductorColorsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel("Проводники")
                    ForEach(ConductorColors.markings) { marking in
                        markingRow(marking)
                        if marking.id != ConductorColors.markings.last?.id {
                            Divider()
                        }
                    }
                }
                .industrialCard()

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Правила")
                    ForEach(ConductorColors.rules, id: \.self) { rule in
                        Label(rule, systemImage: "checkmark.circle")
                            .font(.subheadline)
                    }
                }
                .industrialCard()

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Допустимые цвета изоляции (5.1)")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(ConductorColors.permittedColors) { color in
                            HStack(spacing: 8) {
                                ConductorSwatch(coloring: ConductorColoring(main: color, marks: nil))
                                Text(color.title).font(.caption)
                            }
                        }
                    }
                }
                .industrialCard()

                Text("Источник: \(ConductorColors.source). \(ConductorColors.currentStandardNote)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Маркировка проводников")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func markingRow(_ marking: ConductorMarking) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(marking.designation)
                    .font(.monoBody.weight(.bold))
                    .foregroundStyle(Theme.accent)
                Text(marking.name)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 4)
                Text("п. \(marking.clause)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(Array(marking.colorings.enumerated()), id: \.offset) { _, coloring in
                    ConductorSwatch(coloring: coloring)
                }
            }
            Text(marking.rule)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A short piece of insulated wire: main colour (striped for yellow-green) with optional end markings.
struct ConductorSwatch: View {
    let coloring: ConductorColoring

    var body: some View {
        HStack(spacing: 0) {
            if let marks = coloring.marks {
                fill(marks).frame(width: 8)
            }
            fill(coloring.main)
            if let marks = coloring.marks {
                fill(marks).frame(width: 8)
            }
        }
        .frame(width: 56, height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.border, lineWidth: 1))
        .accessibilityLabel(coloring.marks.map { "\(coloring.main.title) с метками \($0.title)" } ?? coloring.main.title)
    }

    @ViewBuilder
    private func fill(_ color: WireColor) -> some View {
        if color == .yellowGreen {
            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { index in
                    Rectangle().fill(index.isMultiple(of: 2) ? Self.swatch(.yellow) : Self.swatch(.green))
                }
            }
        } else {
            Rectangle().fill(Self.swatch(color))
        }
    }

    static func swatch(_ color: WireColor) -> Color {
        switch color {
        case .black: Color(red: 0.10, green: 0.10, blue: 0.10)
        case .brown: Color(red: 0.48, green: 0.29, blue: 0.16)
        case .red: Color(red: 0.83, green: 0.18, blue: 0.18)
        case .orange: Color(red: 0.96, green: 0.49, blue: 0.0)
        case .yellow: Color(red: 0.98, green: 0.75, blue: 0.18)
        case .green: Color(red: 0.22, green: 0.56, blue: 0.24)
        case .blue: Color(red: 0.12, green: 0.53, blue: 0.90)
        case .violet: Color(red: 0.48, green: 0.12, blue: 0.64)
        case .grey: Color(red: 0.62, green: 0.62, blue: 0.62)
        case .white: Color(red: 0.98, green: 0.98, blue: 0.98)
        case .pink: Color(red: 0.94, green: 0.38, blue: 0.57)
        case .turquoise: Color(red: 0.15, green: 0.78, blue: 0.85)
        case .yellowGreen: Color(red: 0.6, green: 0.7, blue: 0.2)
        }
    }
}
