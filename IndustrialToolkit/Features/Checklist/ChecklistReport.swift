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
}
