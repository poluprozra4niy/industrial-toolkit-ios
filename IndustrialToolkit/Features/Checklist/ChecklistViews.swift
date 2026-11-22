import SwiftData
import SwiftUI

// MARK: - List of runs

struct ChecklistListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChecklistRun.createdAt, order: .reverse) private var runs: [ChecklistRun]
    @State private var isCreating = false
    @State private var deletionError: String?

    var body: some View {
        Group {
            if runs.isEmpty {
                ContentUnavailableView {
                    Label("Нет чек-листов", systemImage: "checklist")
                } description: {
                    Text("Создайте чек-лист для канала или кабеля и отмечайте пункты по ходу ПНР.")
                } actions: {
                    Button("Новый чек-лист") { isCreating = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(runs) { run in
                        NavigationLink {
                            ChecklistRunView(run: run)
                        } label: {
                            RunRow(run: run)
                        }
                        .listRowBackground(Theme.surface)
                    }
                    .onDelete(perform: delete)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background)
        .navigationTitle("Чек-листы ПНР")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreating = true
                } label: {
                    Label("Новый чек-лист", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            NewChecklistSheet()
        }
        .alert(
            "Не удалось удалить",
            isPresented: Binding(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionError ?? "")
        }
    }

    private func delete(at offsets: IndexSet) {
        let targets = offsets.map { runs[$0] }
        for run in targets {
            modelContext.delete(run)
        }
        do {
            try modelContext.save()
        } catch {
            deletionError = error.localizedDescription
        }
    }
}

private struct RunRow: View {
    let run: ChecklistRun

    var body: some View {
        let progress = run.progress
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(run.objectName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(progress.done)/\(progress.total)")
                    .font(.monoCaption.weight(.semibold))
                    .foregroundStyle(progress.isComplete ? Theme.ok : Color.secondary)
            }
            Text(run.kindTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: progress.fraction)
                .tint(progress.isComplete ? Theme.ok : Theme.accent)
            Text(run.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Create

private struct NewChecklistSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var objectName = ""
    @State private var kind: ChecklistKind = .analogLoop
    @State private var saveError: String?

    private var trimmedName: String { objectName.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Объект") {
                    TextField("Тег или название, напр. «PT-101»", text: $objectName)
                        .autocorrectionDisabled()
                }
                Section("Шаблон") {
                    ForEach(ChecklistKind.allCases) { option in
                        Button {
                            kind = option
                        } label: {
                            TemplateRow(kind: option, isSelected: kind == option)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.fault)
                    }
                }
            }
            .navigationTitle("Новый чек-лист")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать", action: create)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func create() {
        ChecklistRun.make(in: modelContext, objectName: trimmedName, kind: kind)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "Ошибка сохранения: \(error.localizedDescription)"
        }
    }
}

private struct TemplateRow: View {
    let kind: ChecklistKind
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbol)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .foregroundStyle(Color.primary)
                Text("\(kind.itemCount) пунктов · \(kind.subtitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Run

struct ChecklistRunView: View {
    let run: ChecklistRun

    @State private var remarkTarget: ChecklistEntry?
    @State private var remarkDraft = ""
    @State private var photoTarget: ChecklistEntry?
    @State private var showsProtocol = false

    private struct EntryGroup: Identifiable {
        let title: String
        let entries: [ChecklistEntry]

        var id: String { title }
    }

    /// Consecutive entries of one template section, in template order.
    private var groups: [EntryGroup] {
        var result: [EntryGroup] = []
        for entry in run.orderedEntries {
            if let last = result.last, last.title == entry.section {
                result[result.count - 1] = EntryGroup(title: last.title, entries: last.entries + [entry])
            } else {
                result.append(EntryGroup(title: entry.section, entries: [entry]))
            }
        }
        return result
    }

    var body: some View {
        let progress = run.progress
        List {
            Section {
                ProgressHeader(kindTitle: run.kindTitle, progress: progress)
            }
            .listRowBackground(Theme.surface)

            ForEach(groups) { group in
                Section(group.title) {
                    ForEach(group.entries) { entry in
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) { entry.toggle() }
                        } label: {
                            EntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.surface)
                        .swipeActions(edge: .leading) {
                            Button {
                                photoTarget = entry
                            } label: {
                                Label("Фото", systemImage: "camera")
                            }
                            .tint(Theme.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                remarkDraft = entry.remark
                                remarkTarget = entry
                            } label: {
                                Label("Замечание", systemImage: "text.bubble")
                            }
                            .tint(Theme.info)
                        }
                    }
                }
            }

            Section {
                Text("Нажмите пункт, чтобы отметить. Смахните влево — замечание, вправо — фото. PDF-протокол с фото и подписями — кнопка вверху.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(run.objectName)
        .navigationBarTitleDisplayMode(.inline)
        .resultActions(title: "Чек-лист: \(run.objectName)", summary: run.report, category: .field)
        .sensoryFeedback(.selection, trigger: progress.done)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsProtocol = true
                } label: {
                    Label("PDF-протокол", systemImage: "doc.richtext")
                }
            }
        }
        .sheet(item: $photoTarget) { entry in
            EntryPhotosSheet(entry: entry)
        }
        .sheet(isPresented: $showsProtocol) {
            ReportExportSheet(filePrefix: "Протокол", objectName: run.objectName) { signers in
                run.protocolDocument(signers: signers)
            }
        }
        .alert(
            "Замечание",
            isPresented: Binding(get: { remarkTarget != nil }, set: { if !$0 { remarkTarget = nil } })
        ) {
            TextField("Текст замечания", text: $remarkDraft)
            Button("Сохранить") {
                remarkTarget?.remark = remarkDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                remarkTarget = nil
            }
            Button("Отмена", role: .cancel) { remarkTarget = nil }
        } message: {
            Text(remarkTarget?.text ?? "")
        }
    }
}

private struct ProgressHeader: View {
    let kindTitle: String
    let progress: ChecklistProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(kindTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text("\(progress.done) / \(progress.total)")
                    .font(.monoBody.weight(.semibold))
                    .monospacedDigit()
            }
            ProgressView(value: progress.fraction)
                .tint(progress.isComplete ? Theme.ok : Theme.accent)
            if progress.isComplete {
                Label("Все пункты выполнены", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ok)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct EntryRow: View {
    let entry: ChecklistEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.isDone ? "checkmark.square.fill" : "square")
                .font(.title2)
                .foregroundStyle(entry.isDone ? Theme.ok : Color.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text)
                    .foregroundStyle(entry.isDone ? Color.secondary : Color.primary)
                if !entry.hint.isEmpty {
                    Text(entry.hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !entry.remark.isEmpty {
                    Label(entry.remark, systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
                HStack(spacing: 10) {
                    if let checkedAt = entry.checkedAt {
                        Text(checkedAt.formatted(date: .omitted, time: .shortened))
                            .font(.monoCaption)
                            .foregroundStyle(.secondary)
                    }
                    if !entry.photos.isEmpty {
                        Label("\(entry.photos.count)", systemImage: "camera.fill")
                            .font(.monoCaption)
                            .foregroundStyle(Theme.accent)
                            .accessibilityLabel("Фото: \(entry.photos.count)")
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(entry.isDone ? .isSelected : [])
        .accessibilityHint("Отметить выполнение")
    }
}
