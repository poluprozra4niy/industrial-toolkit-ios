import Foundation
import SwiftData

/// Moves data between SwiftData and `BackupArchive`.
@MainActor
enum BackupStore {
    struct RestoreSummary: Equatable {
        let notes: Int
        let checklists: Int
        let ioLists: Int
        let skippedDuplicates: Int

        var message: String {
            var parts = ["Добавлено заметок: \(notes), чек-листов: \(checklists), списков сигналов: \(ioLists)."]
            if skippedDuplicates > 0 {
                parts.append("Уже были в приложении и пропущены: \(skippedDuplicates).")
            }
            return parts.joined(separator: " ")
        }
    }

    static func makeArchive(from context: ModelContext, now: Date = .now) throws -> BackupArchive {
        let notes = try context.fetch(FetchDescriptor<EngineerNote>(sortBy: [SortDescriptor(\.createdAt)]))
        let runs = try context.fetch(FetchDescriptor<ChecklistRun>(sortBy: [SortDescriptor(\.createdAt)]))
        let lists = try context.fetch(FetchDescriptor<IOList>(sortBy: [SortDescriptor(\.createdAt)]))
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
            checklists: runs.map(archived),
            ioLists: lists.map(archived)
        )
    }

    private static func archived(_ run: ChecklistRun) -> BackupArchive.Checklist {
        BackupArchive.Checklist(
            objectName: run.objectName,
            kind: run.kindRaw,
            createdAt: run.createdAt,
            entries: run.orderedEntries.map { entry in
                BackupArchive.Entry(
                    order: entry.order,
                    section: entry.section,
                    text: entry.text,
                    hint: entry.hint,
                    isDone: entry.isDone,
                    remark: entry.remark,
                    checkedAt: entry.checkedAt,
                    photos: entry.photos
                        .sorted { $0.createdAt < $1.createdAt }
                        .map { BackupArchive.Photo(data: $0.imageData, createdAt: $0.createdAt) }
                )
            }
        )
    }

    private static func archived(_ list: IOList) -> BackupArchive.SignalList {
        BackupArchive.SignalList(
            name: list.name,
            createdAt: list.createdAt,
            points: list.orderedPoints.map { point in
                BackupArchive.SignalPoint(
                    order: point.order,
                    record: point.record,
                    status: point.status,
                    remark: point.remark,
                    checkedAt: point.checkedAt
                )
            }
        )
    }

    /// Adds records missing from the store; existing ones are never overwritten.
    static func restore(_ archive: BackupArchive, into context: ModelContext) throws -> RestoreSummary {
        let existingNotes = try context.fetch(FetchDescriptor<EngineerNote>())
        let existingRuns = try context.fetch(FetchDescriptor<ChecklistRun>())
        let existingLists = try context.fetch(FetchDescriptor<IOList>())
        let plan = BackupMerge.plan(
            archive,
            existingNotes: Set(existingNotes.map { BackupMerge.noteKey(title: $0.title, createdAt: $0.createdAt) }),
            existingChecklists: Set(existingRuns.map {
                BackupMerge.checklistKey(objectName: $0.objectName, kind: $0.kindRaw, createdAt: $0.createdAt)
            }),
            existingSignalLists: Set(existingLists.map { BackupMerge.signalListKey(name: $0.name, createdAt: $0.createdAt) })
        )

        for item in plan.notes {
            let note = EngineerNote(title: item.title, body: item.body, createdAt: item.createdAt)
            note.categoryRaw = item.category
            note.updatedAt = item.updatedAt
            context.insert(note)
        }
        // Children are linked after their parent is inserted: see ChecklistRun.make.
        for item in plan.checklists {
            let run = ChecklistRun(objectName: item.objectName, kindRaw: item.kind, createdAt: item.createdAt)
            context.insert(run)
            for source in item.entries {
                let entry = ChecklistEntry(order: source.order, section: source.section, text: source.text, hint: source.hint)
                entry.isDone = source.isDone
                entry.remark = source.remark
                entry.checkedAt = source.checkedAt
                context.insert(entry)
                entry.run = run
                for item in source.photos ?? [] {
                    let photo = ChecklistPhoto(imageData: item.data, createdAt: item.createdAt)
                    context.insert(photo)
                    photo.entry = entry
                }
            }
        }
        for item in plan.ioLists {
            let list = IOList(name: item.name, createdAt: item.createdAt)
            context.insert(list)
            for source in item.points {
                let point = IOPoint(order: source.order, record: source.record)
                point.statusRaw = source.status.rawValue
                point.remark = source.remark
                point.checkedAt = source.checkedAt
                context.insert(point)
                point.list = list
            }
        }
        try context.save()
        return RestoreSummary(
            notes: plan.notes.count,
            checklists: plan.checklists.count,
            ioLists: plan.ioLists.count,
            skippedDuplicates: plan.skippedDuplicates
        )
    }
}
