import Foundation
import Testing
@testable import IndustrialToolkit
#if os(iOS)
import SwiftData
#endif

@Suite("Резервная копия: формат и слияние")
struct BackupArchiveTests {
    private let created = Date(timeIntervalSince1970: 1_790_000_000.75)

    private var sample: BackupArchive {
        BackupArchive(
            exportedAt: Date(timeIntervalSince1970: 1_790_100_000),
            notes: [
                BackupArchive.Note(title: "КНС-2, PT-101", body: "4–20 мА, 0…6 бар", category: "field", createdAt: created, updatedAt: created),
            ],
            checklists: [
                BackupArchive.Checklist(
                    objectName: "КНС-2",
                    kind: "loopCheckAI",
                    createdAt: created,
                    entries: [
                        BackupArchive.Entry(order: 0, section: "Подготовка", text: "Проверить маркировку", hint: "", isDone: true, remark: "ок", checkedAt: created),
                        BackupArchive.Entry(order: 1, section: "Подготовка", text: "Замерить изоляцию", hint: "500 В", isDone: false, remark: "", checkedAt: nil),
                    ]
                ),
            ]
        )
    }

    @Test("JSON туда и обратно без потерь (до секунды)")
    func roundTrip() throws {
        let restored = try BackupArchive.decode(sample.encoded())
        #expect(restored.format == BackupArchive.formatIdentifier)
        #expect(restored.version == BackupArchive.currentVersion)
        #expect(restored.notes.first?.body == "4–20 мА, 0…6 бар")
        #expect(restored.checklists.first?.entries.count == 2)
        #expect(restored.checklists.first?.entries.last?.checkedAt == nil)
        let restoredCreated = try #require(restored.notes.first?.createdAt)
        #expect(BackupMerge.second(restoredCreated) == BackupMerge.second(created))
    }

    @Test("Чужой файл и более новая версия отклоняются")
    func rejects() throws {
        #expect(throws: BackupError.unreadable) { try BackupArchive.decode(Data("не json".utf8)) }

        var foreign = sample
        foreign.format = "something-else"
        #expect(throws: BackupError.foreignFile) { try BackupArchive.decode(foreign.encoded()) }

        var newer = sample
        newer.version = BackupArchive.currentVersion + 1
        #expect(throws: BackupError.newerVersion(BackupArchive.currentVersion + 1)) { try BackupArchive.decode(newer.encoded()) }
    }

    @Test("Повторное восстановление не дублирует записи")
    func mergeSkipsDuplicates() throws {
        let restored = try BackupArchive.decode(sample.encoded())
        let existingNotes: Set = [BackupMerge.noteKey(title: "КНС-2, PT-101", createdAt: created)]
        let existingChecklists: Set = [BackupMerge.checklistKey(objectName: "КНС-2", kind: "loopCheckAI", createdAt: created)]

        let plan = BackupMerge.plan(restored, existingNotes: existingNotes, existingChecklists: existingChecklists)
        #expect(plan.notes.isEmpty)
        #expect(plan.checklists.isEmpty)
        #expect(plan.skippedDuplicates == 2)

        let fresh = BackupMerge.plan(restored, existingNotes: [], existingChecklists: [])
        #expect(fresh.notes.count == 1)
        #expect(fresh.checklists.count == 1)
        #expect(fresh.skippedDuplicates == 0)
    }

    @Test("Дубли внутри одного файла тоже отсекаются")
    func mergeDeduplicatesWithinArchive() {
        var archive = sample
        archive.notes.append(archive.notes[0])
        let plan = BackupMerge.plan(archive, existingNotes: [], existingChecklists: [])
        #expect(plan.notes.count == 1)
        #expect(plan.skippedDuplicates == 1)
    }

    @Test("Имя файла содержит дату")
    func fileName() {
        let name = BackupArchive.fileName(for: Date(timeIntervalSince1970: 1_790_100_000))
        #expect(name.hasPrefix("industrial-toolkit-backup-20"))
        #expect(name.hasSuffix(".json"))
    }
}

#if os(iOS)
@Suite("Резервная копия: SwiftData")
@MainActor
struct BackupStoreTests {
    @Test("Экспорт → восстановление в пустую базу → повтор без дублей")
    func restoreIntoEmptyStore() throws {
        let schema: [any PersistentModel.Type] = [EngineerNote.self, ChecklistRun.self, ChecklistEntry.self]
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let source = try ModelContainer(for: Schema(schema), configurations: configuration)
        let sourceContext = source.mainContext
        sourceContext.insert(EngineerNote(title: "PT-101", body: "0…6 бар", category: .field))
        let run = ChecklistRun.make(in: sourceContext, objectName: "КНС-2", kind: .allCases[0])
        run.orderedEntries.first?.toggle()
        try sourceContext.save()
        #expect(!run.entries.isEmpty)

        let data = try BackupStore.makeArchive(from: sourceContext).encoded()

        let target = try ModelContainer(for: Schema(schema), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let targetContext = target.mainContext
        let first = try BackupStore.restore(BackupArchive.decode(data), into: targetContext)
        #expect(first.notes == 1)
        #expect(first.checklists == 1)

        let runs = try targetContext.fetch(FetchDescriptor<ChecklistRun>())
        let restoredRun = try #require(runs.first)
        #expect(restoredRun.entries.count == run.entries.count)
        #expect(restoredRun.orderedEntries.first?.isDone == true)
        #expect(try targetContext.fetch(FetchDescriptor<EngineerNote>()).first?.category == .field)

        let second = try BackupStore.restore(BackupArchive.decode(data), into: targetContext)
        #expect(second.notes == 0)
        #expect(second.checklists == 0)
        #expect(second.skippedDuplicates == 2)
    }
}
#endif
