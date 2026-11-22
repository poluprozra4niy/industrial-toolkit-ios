import Foundation
import SwiftData

/// Moves data between SwiftData and `BackupArchive`.
@MainActor
enum BackupStore {
    struct RestoreSummary: Equatable {
        let notes: Int
        let checklists: Int
        let skippedDuplicates: Int

        var message: String {
            var parts = ["Добавлено заметок: \(notes), чек-листов: \(checklists)."]
            if skippedDuplicates > 0 {
                parts.append("Уже были в приложении и пропущены: \(skippedDuplicates).")
            }
            return parts.joined(separator: " ")
        }
    }

    static func makeArchive(from context: ModelContext, now: Date = .now) throws -> BackupArchive {
        let notes = try context.fetch(FetchDescriptor<EngineerNote>(sortBy: [SortDescriptor(\.createdAt)]))
        let runs = try context.fetch(FetchDescriptor<ChecklistRun>(sortBy: [SortDescriptor(\.createdAt)]))
        return BackupArchive(
            exportedAt: now,
            notes: notes.map {
                BackupArchive.Note(
                    title: $0.title,
                    body: $0.body,
                    category: $0.categoryRaw,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            checklists: runs.map { run in
                BackupArchive.Checklist(
                    objectName: run.objectName,
                    kind: run.kindRaw,
                    createdAt: run.createdAt,
                    entries: run.orderedEntries.map {
                        BackupArchive.Entry(
                            order: $0.order,
                            section: $0.section,
                            text: $0.text,
                            hint: $0.hint,
                            isDone: $0.isDone,
                            remark: $0.remark,
                            checkedAt: $0.checkedAt
                        )
                    }
                )
            }
        )
    }

    /// Adds records missing from the store; existing ones are never overwritten.
    static func restore(_ archive: BackupArchive, into context: ModelContext) throws -> RestoreSummary {
        let existingNotes = try context.fetch(FetchDescriptor<EngineerNote>())
        let existingRuns = try context.fetch(FetchDescriptor<ChecklistRun>())
        let plan = BackupMerge.plan(
            archive,
            existingNotes: Set(existingNotes.map { BackupMerge.noteKey(title: $0.title, createdAt: $0.createdAt) }),
            existingChecklists: Set(existingRuns.map {
                BackupMerge.checklistKey(objectName: $0.objectName, kind: $0.kindRaw, createdAt: $0.createdAt)
            })
        )

        for item in plan.notes {
            let note = EngineerNote(title: item.title, body: item.body, createdAt: item.createdAt)
            note.categoryRaw = item.category
            note.updatedAt = item.updatedAt
            context.insert(note)
        }
        for item in plan.checklists {
            let run = ChecklistRun(objectName: item.objectName, kindRaw: item.kind, createdAt: item.createdAt)
            context.insert(run)
            // Entries are linked after the run is inserted: see ChecklistRun.make.
            for source in item.entries {
                let entry = ChecklistEntry(order: source.order, section: source.section, text: source.text, hint: source.hint)
                entry.isDone = source.isDone
                entry.remark = source.remark
                entry.checkedAt = source.checkedAt
                context.insert(entry)
                entry.run = run
            }
        }
        try context.save()
        return RestoreSummary(notes: plan.notes.count, checklists: plan.checklists.count, skippedDuplicates: plan.skippedDuplicates)
    }
}
