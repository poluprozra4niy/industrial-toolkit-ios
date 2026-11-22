import Foundation

/// Persistence-free snapshot of one checklist entry, so report text and progress
/// can be produced and tested without SwiftData.
struct ChecklistLine: Equatable {
    let section: String
    let text: String
    let isDone: Bool
    let remark: String
    let checkedAt: Date?
}

struct ChecklistProgress: Equatable {
    let done: Int
    let total: Int

    var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
    var isComplete: Bool { total > 0 && done == total }
}

enum ChecklistReport {
    static func progress(of lines: [ChecklistLine]) -> ChecklistProgress {
        ChecklistProgress(done: lines.filter(\.isDone).count, total: lines.count)
    }

    static func render(objectName: String, kindTitle: String, createdAt: Date, lines: [ChecklistLine]) -> String {
        let progress = progress(of: lines)
        var output = [
            "Чек-лист: \(kindTitle)",
            "Объект / тег: \(objectName)",
            "Начат: \(createdAt.formatted(date: .numeric, time: .shortened))",
            "Выполнено: \(progress.done) из \(progress.total)",
        ]
        var currentSection: String?
        for line in lines {
            if line.section != currentSection {
                output += ["", "[\(line.section)]"]
                currentSection = line.section
            }
            let mark = line.isDone ? "[x]" : "[ ]"
            let time = line.checkedAt.map { " (\($0.formatted(date: .numeric, time: .shortened)))" } ?? ""
            output.append("\(mark) \(line.text)\(time)")
            let remark = line.remark.trimmingCharacters(in: .whitespacesAndNewlines)
            if !remark.isEmpty {
                output.append("    Замечание: \(remark)")
            }
        }
        return output.joined(separator: "\n")
    }

    /// Printable protocol; `photos[i]` belong to `lines[i]`. An open item with a remark
    /// is reported as a finding, an open item without one as not checked.
    static func document(
        objectName: String,
        kindTitle: String,
        createdAt: Date,
        lines: [ChecklistLine],
        photos: [[Data]],
        signers: ReportSigners,
        issuedAt: Date
    ) -> ReportDocument {
        let progress = progress(of: lines)
        var sections: [ReportSection] = []
        for (index, line) in lines.enumerated() {
            let remark = line.remark.trimmingCharacters(in: .whitespacesAndNewlines)
            var details: [String] = []
            if let checkedAt = line.checkedAt {
                details.append("Отмечено: \(checkedAt.formatted(date: .numeric, time: .shortened))")
            }
            if !remark.isEmpty {
                details.append("Замечание: \(remark)")
            }
            let status: ReportStatus = line.isDone ? .passed : (remark.isEmpty ? .pending : .failed)
            let row = ReportRow(
                status: status,
                text: line.text,
                details: details,
                images: index < photos.count ? photos[index] : []
            )
            if let last = sections.last, last.title == line.section {
                sections[sections.count - 1].rows.append(row)
            } else {
                sections.append(ReportSection(title: line.section, rows: [row]))
            }
        }
        let findings = lines.filter { !$0.isDone && !$0.remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        var header = [
            "Объект / тег: \(objectName)",
            "Вид проверки: \(kindTitle)",
            "Начато: \(createdAt.formatted(date: .numeric, time: .shortened))",
            "Протокол сформирован: \(issuedAt.formatted(date: .numeric, time: .shortened))",
        ]
        if let organization = signers.organizationLine {
            header.append(organization)
        }
        return ReportDocument(
            title: "Протокол: \(kindTitle)",
            headerLines: header,
            sections: sections,
            summaryLines: [
                "Выполнено пунктов: \(progress.done) из \(progress.total)",
                "Замечаний: \(findings)",
                progress.isComplete ? "Все пункты проверки выполнены." : "Проверка не завершена: \(progress.total - progress.done) пункт(ов) не отмечено.",
            ],
            signatures: signers.signatures
        )
    }
}
