import SwiftData
import SwiftUI

struct NotebookView: View {
    private enum EditorTarget: Identifiable {
        case new
        case existing(EngineerNote)

        var id: AnyHashable {
            switch self {
            case .new: AnyHashable("new")
            case .existing(let note): AnyHashable(note.persistentModelID)
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EngineerNote.createdAt, order: .reverse) private var notes: [EngineerNote]
    @State private var query = ""
    @State private var editorTarget: EditorTarget?
    @State private var deletionError: String?
    @State private var backup = BackupController()

    private var filteredNotes: [EngineerNote] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(needle) || $0.body.localizedCaseInsensitiveContains(needle)
        }
    }

    var body: some View {
        Group {
            if notes.isEmpty {
                ContentUnavailableView(
                    "Блокнот пуст",
                    systemImage: "note.text",
                    description: Text("Сохраняйте результаты кнопкой «В блокнот» в любом инструменте или создайте заметку. Резервную копию можно восстановить через меню слева вверху.")
                )
            } else if filteredNotes.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List {
                    ForEach(filteredNotes) { note in
                        Button {
                            editorTarget = .existing(note)
                        } label: {
                            NoteRow(note: note)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.surface)
                    }
                    .onDelete(perform: delete)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background)
        .navigationTitle("Блокнот")
        .searchable(text: $query, prompt: "Поиск по заметкам")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackupMenu(controller: backup)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !notes.isEmpty {
                    ShareLink(item: exportAll) {
                        Label("Экспорт всех", systemImage: "square.and.arrow.up")
                    }
                }
                Button {
                    editorTarget = .new
                } label: {
                    Label("Новая заметка", systemImage: "square.and.pencil")
                }
            }
        }
        .backupPresentation(backup)
        .sheet(item: $editorTarget) { target in
            switch target {
            case .new: NoteEditorView(note: nil)
            case .existing(let note): NoteEditorView(note: note)
            }
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

    private var exportAll: String {
        notes.map(\.exportText).joined(separator: "\n\n────────\n\n")
    }

    private func delete(at offsets: IndexSet) {
        let targets = offsets.map { filteredNotes[$0] }
        for note in targets {
            modelContext.delete(note)
        }
        do {
            try modelContext.save()
        } catch {
            deletionError = error.localizedDescription
        }
    }
}

private struct NoteRow: View {
    let note: EngineerNote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title.isEmpty ? "Без названия" : note.title)
                .font(.body.weight(.medium))
                .lineLimit(1)
            Text(note.body)
                .font(.monoCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 8) {
                Text(note.category.title.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.accent)
                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct NoteEditorView: View {
    let note: EngineerNote?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var text: String
    @State private var category: NoteCategory
    @State private var saveError: String?

    init(note: EngineerNote?) {
        self.note = note
        _title = State(initialValue: note?.title ?? "")
        _text = State(initialValue: note?.body ?? "")
        _category = State(initialValue: note?.category ?? .field)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Заголовок, напр. «КНС-2, PT-101»", text: $title)
                    Picker("Раздел", selection: $category) {
                        ForEach(NoteCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                }
                Section("Текст") {
                    TextEditor(text: $text)
                        .font(.monoBody)
                        .frame(minHeight: 260)
                }
                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.fault)
                    }
                }
            }
            .navigationTitle(note == nil ? "Новая заметка" : "Заметка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(!canSave)
                }
                if let note {
                    ToolbarItem(placement: .bottomBar) {
                        ShareLink(item: note.exportText) {
                            Label("Поделиться", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private func save() {
        if let note {
            note.title = title
            note.body = text
            note.category = category
            note.updatedAt = .now
        } else {
            modelContext.insert(EngineerNote(title: title, body: text, category: category))
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "Ошибка сохранения: \(error.localizedDescription)"
        }
    }
}
