import SwiftUI
import UIKit

// MARK: - Containers

struct IndustrialCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }
}

struct FieldChrome: ViewModifier {
    let isInvalid: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.fieldCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.fieldCornerRadius)
                    .strokeBorder(isInvalid ? Theme.fault : Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    func industrialCard() -> some View { modifier(IndustrialCard()) }

    func fieldChrome(isInvalid: Bool = false) -> some View { modifier(FieldChrome(isInvalid: isInvalid)) }

    func keyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                    )
                }
                .fontWeight(.semibold)
            }
        }
    }
}

struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Inputs

struct NumericField: View {
    let label: String
    @Binding var text: String
    var unit: String?
    var keyboard: UIKeyboardType = .numbersAndPunctuation
    var isInvalid = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("0", text: $text)
                    .keyboardType(keyboard)
                    .font(.system(.title3, design: .monospaced, weight: .medium))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if let unit, !unit.isEmpty {
                    Text(unit)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .fieldChrome(isInvalid: isInvalid)
        }
    }
}

struct ChoiceChip: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 6)
            .foregroundStyle(isSelected ? Theme.accent : Color.primary)
            .background(
                isSelected ? Theme.accent.opacity(0.14) : Theme.surfaceSunken,
                in: RoundedRectangle(cornerRadius: Theme.fieldCornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.fieldCornerRadius)
                    .strokeBorder(isSelected ? Theme.accent : Theme.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Outputs

struct MetricTile: View {
    let title: String
    let value: String
    let unit: String
    var isInput = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if isInput {
                    Text("ВВОД")
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.accent)
                }
            }
            Text(value)
                .font(.readout)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.45)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.fieldCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.fieldCornerRadius)
                .strokeBorder(isInput ? Theme.accent : Theme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

struct ValueRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    var copyable = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
            if copyable {
                CopyButton(value: value)
            }
        }
        .font(.subheadline)
    }
}

struct CopyButton: View {
    let value: String
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = value
            copied = true
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.caption)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(copied ? "Скопировано" : "Копировать \(value)")
        .sensoryFeedback(.success, trigger: copied) { _, isCopied in isCopied }
        .task(id: copied) {
            guard copied, (try? await Task.sleep(for: .seconds(1.2))) != nil else { return }
            copied = false
        }
    }
}

struct StatusBanner: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.fieldCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.fieldCornerRadius)
                .strokeBorder(tint.opacity(0.5), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
