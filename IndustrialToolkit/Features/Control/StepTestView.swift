import SwiftUI

/// Stopwatch for an open-loop step test; the result is handed back to the PID tuning screen.
struct StepTestView: View {
    let onApply: (StepTestResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model = StepTestViewModel()

    private let twoColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    setupCard
                    stopwatchCard
                    if !model.samples.isEmpty {
                        samplesCard
                    }
                    resultCard
                }
                .padding(16)
            }
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Тест ступенькой")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("В расчёт ПИД") {
                        if let result = model.result {
                            onApply(result)
                            dismiss()
                        }
                    }
                    .disabled(model.result == nil)
                }
            }
        }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Перед ступенькой")
            LazyVGrid(columns: twoColumns, spacing: 10) {
                NumericField(label: "PV до ступеньки", text: $model.initialText, isInvalid: !model.initialText.isEmpty && model.initialValue == nil)
                NumericField(label: "Шкала PV (ВПИ − НПИ)", text: $model.spanText, isInvalid: model.span == nil)
                NumericField(label: "Δu выхода, %", text: $model.outputStepText)
            }
            Text("Регулятор в ручном режиме, процесс в установившемся состоянии. Изменить выход скачком на Δu и сразу нажать «Ступенька».")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }

    private var stopwatchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Секундомер")
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                Text(StepTestAnalysis.clock(model.elapsed(at: context.date)))
                    .font(.readoutLarge)
                    .monospacedDigit()
                    .foregroundStyle(model.isRunning ? Theme.accent : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if !model.hasStarted {
                Button {
                    model.start()
                } label: {
                    Label("Ступенька — старт", systemImage: "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            } else if model.isRunning {
                NumericField(label: "PV сейчас", text: $model.currentText, isInvalid: !model.currentText.isEmpty && NumberParser.parse(model.currentText) == nil)
                Button {
                    model.record()
                } label: {
                    Label("Записать замер", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canRecord)
                LazyVGrid(columns: twoColumns, spacing: 10) {
                    markButton(title: "28 % достигнуто", level: StepTestAnalysis.fraction28, marked: model.marked28) { model.mark28() }
                    markButton(title: "63 % достигнуто", level: StepTestAnalysis.fraction63, marked: model.marked63) { model.mark63() }
                }
                Button(role: .destructive) {
                    model.stop()
                } label: {
                    Label("Стоп — процесс установился", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            } else {
                NumericField(label: "PV установившееся", text: $model.finalText, isInvalid: !model.finalText.isEmpty && model.finalValue == nil)
                Button("Сбросить и начать заново", role: .destructive) {
                    model.reset()
                }
                .frame(maxWidth: .infinity)
            }
            Text("Записывайте PV по тренду каждые несколько секунд — t28 и t63 будут интерполированы. Если итоговое PV известно заранее, введите его: появятся целевые уровни, и можно просто нажать кнопки 28 % / 63 %.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if model.isRunning {
                NumericField(label: "Ожидаемое итоговое PV (необязательно)", text: $model.finalText)
            }
        }
        .industrialCard()
    }

    private func markButton(title: String, level fraction: Double, marked: Double?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                if let marked {
                    Text("t = \(StepTestAnalysis.clock(marked))").font(.monoCaption)
                } else if let level = model.targetLevel(fraction) {
                    Text("PV = \(Fmt.number(level, fractionDigits: 3))").font(.monoCaption)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }

    private var samplesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel("Замеры")
                if model.isRunning {
                    Button("Удалить последний", role: .destructive) { model.removeLastSample() }
                        .font(.caption)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("t, с")
                    Text("PV")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                ForEach(model.samples) { sample in
                    GridRow {
                        Text(Fmt.fixed(sample.time, fractionDigits: 1))
                        Text(Fmt.number(sample.value, fractionDigits: 4))
                    }
                    .font(.monoCaption)
                }
            }
        }
        .industrialCard()
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Результат")
            if let analysis = model.analysis {
                ValueRow(label: "Δy", value: "\(Fmt.number(analysis.change, fractionDigits: 3)) = \(Fmt.number(analysis.changePercent(span: model.span), fractionDigits: 2)) %", copyable: false)
            }
            if let t28 = model.t28 {
                ValueRow(label: "t28", value: "\(Fmt.fixed(t28, fractionDigits: 1)) с", valueColor: Theme.accent)
            }
            if let t63 = model.t63 {
                ValueRow(label: "t63", value: "\(Fmt.fixed(t63, fractionDigits: 1)) с", valueColor: Theme.accent)
            }
            if model.result != nil {
                Label("Нажмите «В расчёт ПИД» — значения подставятся в настройку по разгону.", systemImage: "arrow.uturn.left.circle")
                    .font(.caption)
                    .foregroundStyle(Theme.ok)
            } else {
                Text(model.resultHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .industrialCard()
    }
}
