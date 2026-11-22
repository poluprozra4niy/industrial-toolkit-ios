import SwiftUI

struct PIDTuningView: View {
    @State private var model = PIDTuningViewModel()
    @State private var showsStopwatch = false

    private let typeColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private let cellColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("Метод", selection: $model.method) {
                    ForEach(PIDTuningViewModel.Method.allCases) { method in
                        Text(method.title).tag(method)
                    }
                }
                .pickerStyle(.segmented)

                inputCard
                resultsContent
                guideCard
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Настройка ПИД")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: model.noteTitle, summary: model.summary, category: .design)
        .sheet(isPresented: $showsStopwatch) {
            StepTestView { result in
                model.apply(result)
            }
        }
    }

    // MARK: Input

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Регулятор")
            LazyVGrid(columns: typeColumns, spacing: 8) {
                ForEach(ControllerType.allCases) { type in
                    ChoiceChip(title: type.title, isSelected: model.controllerType == type) {
                        model.controllerType = type
                    }
                }
            }
            switch model.method {
            case .closedLoop: closedLoopFields
            case .openLoop: openLoopFields
            }
            Text("Время — в одних единицах (с или мин); Ti и Td получатся в них же.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }

    private var closedLoopFields: some View {
        HStack(alignment: .top, spacing: 10) {
            NumericField(label: "Ku (критический Kp)", text: $model.ultimateGainText, isInvalid: model.isUltimateGainInvalid)
            NumericField(label: "Tu (период колебаний)", text: $model.ultimatePeriodText, isInvalid: model.isUltimatePeriodInvalid)
        }
    }

    @ViewBuilder
    private var openLoopFields: some View {
        Picker("Модель", selection: $model.modelInput) {
            ForEach(PIDTuningViewModel.ModelInput.allCases) { input in
                Text(input.title).tag(input)
            }
        }
        .pickerStyle(.segmented)

        switch model.modelInput {
        case .direct:
            HStack(alignment: .top, spacing: 8) {
                NumericField(label: "K, %/%", text: $model.gainText)
                NumericField(label: "L (запазд.)", text: $model.deadTimeText)
                NumericField(label: "T (пост. вр.)", text: $model.timeConstantText)
            }
        case .stepTest:
            Button {
                showsStopwatch = true
            } label: {
                Label("Секундомер теста на объекте", systemImage: "stopwatch")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            HStack(alignment: .top, spacing: 10) {
                NumericField(label: "Δu выхода, %", text: $model.outputStepText)
                NumericField(label: "Δy процесса, %", text: $model.processChangeText)
            }
            HStack(alignment: .top, spacing: 10) {
                NumericField(label: "t28 (28,3 % Δy)", text: $model.t28Text)
                NumericField(label: "t63 (63,2 % Δy)", text: $model.t63Text)
            }
            if let processModel = model.processModel {
                ValueRow(
                    label: "Модель",
                    value: "K = \(Fmt.number(processModel.gain, fractionDigits: 3)), "
                        + "L = \(Fmt.number(processModel.deadTime, fractionDigits: 2)), "
                        + "T = \(Fmt.number(processModel.timeConstant, fractionDigits: 2))",
                    copyable: false
                )
            }
        }

        if let error = model.modelError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(Theme.fault)
        }
        if let hint = model.controllabilityHint {
            Label(hint, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(Theme.info)
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultsContent: some View {
        let results = model.results
        if results.isEmpty {
            Label("Введите исходные данные", systemImage: "keyboard")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .industrialCard()
        } else {
            ForEach(results) { result in
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.title)
                            .font(.headline)
                        Text(result.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: cellColumns, spacing: 8) {
                        ParameterCell(label: "Kp", value: Fmt.number(result.parameters.kp, fractionDigits: 3), isPrimary: true)
                        ParameterCell(label: "Ti", value: result.parameters.ti.map { Fmt.number($0, fractionDigits: 2) } ?? "—", isPrimary: true)
                        ParameterCell(label: "Td", value: result.parameters.td.map { Fmt.number($0, fractionDigits: 2) } ?? "—", isPrimary: true)
                        ParameterCell(label: "Xp, %", value: Fmt.number(result.parameters.proportionalBand, fractionDigits: 1))
                        ParameterCell(label: "Ki = Kp/Ti", value: result.parameters.ki.map { Fmt.number($0, fractionDigits: 4) } ?? "—")
                        ParameterCell(label: "Kd = Kp·Td", value: result.parameters.kd.map { Fmt.number($0, fractionDigits: 3) } ?? "—")
                    }
                }
                .industrialCard()
            }
            Text("Первая строка — стандартная форма (ISA), вторая — параллельная и полоса пропорциональности Xp = 100/Kp. Это стартовые значения: доводите настройку на живом процессе.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Guide

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Как получить данные")
            switch model.method {
            case .closedLoop:
                guideStep(1, "Переведите регулятор в П-режим: Ti = ∞ (или макс.), Td = 0.")
                guideStep(2, "Увеличивайте Kp, пока процесс не начнёт колебаться с постоянной амплитудой.")
                guideStep(3, "Это Kp и есть Ku, период колебаний — Tu.")
                guideStep(4, "Не доводите до расходящихся колебаний на реальном объекте.")
            case .openLoop:
                guideStep(1, "Ручной режим, процесс в установившемся состоянии.")
                guideStep(2, "Сделайте ступеньку выхода Δu (5–10 %) и запишите отклик процесса.")
                guideStep(3, "t28 и t63 — время от ступеньки до 28,3 % и 63,2 % итогового изменения Δy.")
                guideStep(4, "T = 1,5·(t63 − t28), L = t63 − T, K = Δy/Δu (в % шкалы).")
            }
        }
        .industrialCard()
    }

    private func guideStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.monoCaption.weight(.bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 16)
            Text(text)
                .font(.subheadline)
        }
    }
}

private struct ParameterCell: View {
    let label: String
    let value: String
    var isPrimary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(isPrimary ? .system(.title3, design: .monospaced, weight: .semibold) : .monoBody)
                .foregroundStyle(isPrimary ? Color.primary : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .textSelection(.enabled)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.fieldCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.fieldCornerRadius)
                .strokeBorder(isPrimary ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
