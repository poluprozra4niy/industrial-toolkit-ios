import Foundation
import SwiftData

@Model
final class ChecklistRun {
    var objectName: String
    var kindRaw: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ChecklistEntry.run)
    var entries: [ChecklistEntry] = []

    init(objectName: String, kind: ChecklistKind, createdAt: Date = .now) {
        self.objectName = objectName
        self.kindRaw = kind.rawValue
        self.createdAt = createdAt
    }

    /// Restores a run from a backup verbatim, including kinds this build no longer ships.
    init(objectName: String, kindRaw: String, createdAt: Date) {
        self.objectName = objectName
        self.kindRaw = kindRaw
        self.createdAt = createdAt
    }

    var kind: ChecklistKind? { ChecklistKind(rawValue: kindRaw) }

    var kindTitle: String { kind?.title ?? kindRaw }

    var orderedEntries: [ChecklistEntry] { entries.sorted { $0.order < $1.order } }

    var lines: [ChecklistLine] { orderedEntries.map(\.line) }

    var progress: ChecklistProgress { ChecklistReport.progress(of: lines) }

    var report: String {
        ChecklistReport.render(objectName: objectName, kindTitle: kindTitle, createdAt: createdAt, lines: lines)
    }

    func protocolDocument(signers: ReportSigners, issuedAt: Date = .now) -> ReportDocument {
        let entries = orderedEntries
        return ChecklistReport.document(
            objectName: objectName,
            kindTitle: kindTitle,
            createdAt: createdAt,
            lines: entries.map(\.line),
            photos: entries.map { $0.photos.sorted { $0.createdAt < $1.createdAt }.map(\.imageData) },
            signers: signers,
            issuedAt: issuedAt
        )
    }

    /// Entries are attached after the run is inserted: SwiftData relationships on
    /// not-yet-inserted models are not reliably persisted on iOS 17.
    @discardableResult
    static func make(in context: ModelContext, objectName: String, kind: ChecklistKind) -> ChecklistRun {
        let run = ChecklistRun(objectName: objectName, kind: kind)
        context.insert(run)
        var order = 0
        for section in kind.sections {
            for item in section.items {
                let entry = ChecklistEntry(order: order, section: section.title, text: item.text, hint: item.hint)
                context.insert(entry)
                entry.run = run
                order += 1
            }
        }
        return run
    }
}

@Model
final class ChecklistEntry {
    var order: Int
    var section: String
    var text: String
    var hint: String
    var isDone: Bool
    var remark: String
    var checkedAt: Date?
    var run: ChecklistRun?
    @Relationship(deleteRule: .cascade, inverse: \ChecklistPhoto.entry)
    var photos: [ChecklistPhoto] = []

    init(order: Int, section: String, text: String, hint: String) {
        self.order = order
        self.section = section
        self.text = text
        self.hint = hint
        self.isDone = false
        self.remark = ""
        self.checkedAt = nil
    }

    var line: ChecklistLine {
        ChecklistLine(section: section, text: text, isDone: isDone, remark: remark, checkedAt: checkedAt)
    }

    func toggle(now: Date = .now) {
        isDone.toggle()
        checkedAt = isDone ? now : nil
    }
}
