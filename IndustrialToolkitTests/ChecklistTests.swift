import Foundation
import Testing
@testable import IndustrialToolkit

@Suite("Чек-листы ПНР")
struct ChecklistTests {
    @Test("Шаблоны непустые, пункты с текстом, разделы не повторяются", arguments: ChecklistKind.allCases)
    func templatesAreWellFormed(kind: ChecklistKind) {
        #expect(!kind.sections.isEmpty)
        #expect(kind.itemCount > 0)
        #expect(kind.sections.allSatisfy { !$0.items.isEmpty })
        #expect(kind.sections.flatMap(\.items).allSatisfy { !$0.text.isEmpty })
        let titles = kind.sections.map(\.title)
        #expect(Set(titles).count == titles.count)
    }

    @Test("Loop check содержит все 5 точек шкалы")
    func analogLoopHasFivePoints() {
        let texts = ChecklistKind.analogLoop.sections.flatMap(\.items).map(\.text)
        for point in ["4 мА", "8 мА", "12 мА", "16 мА", "20 мА"] {
            #expect(texts.contains { $0.hasPrefix(point) })
        }
    }

    @Test("Прогресс считает выполненные пункты")
    func progress() {
        let lines = [
            ChecklistLine(section: "A", text: "1", isDone: true, remark: "", checkedAt: nil),
            ChecklistLine(section: "A", text: "2", isDone: true, remark: "", checkedAt: nil),
            ChecklistLine(section: "B", text: "3", isDone: false, remark: "", checkedAt: nil),
        ]
        let progress = ChecklistReport.progress(of: lines)
        #expect(progress == ChecklistProgress(done: 2, total: 3))
        #expect(abs(progress.fraction - 2.0 / 3.0) < 1e-12)
        #expect(!progress.isComplete)
        #expect(ChecklistReport.progress(of: []).fraction == 0)
        #expect(!ChecklistReport.progress(of: []).isComplete)
    }

    @Test("Отчёт: заголовок раздела один раз, отметки и замечания")
    func reportText() {
        let lines = [
            ChecklistLine(section: "Подготовка", text: "Маркировка", isDone: true, remark: " проверить бирку ", checkedAt: nil),
            ChecklistLine(section: "Подготовка", text: "Экран", isDone: false, remark: "", checkedAt: nil),
            ChecklistLine(section: "Завершение", text: "Протокол", isDone: false, remark: "", checkedAt: nil),
        ]
        let report = ChecklistReport.render(
            objectName: "PT-101",
            kindTitle: ChecklistKind.analogLoop.title,
            createdAt: Date(timeIntervalSince1970: 0),
            lines: lines
        )
        #expect(report.contains("Объект / тег: PT-101"))
        #expect(report.contains("Выполнено: 1 из 3"))
        #expect(report.contains("[x] Маркировка"))
        #expect(report.contains("    Замечание: проверить бирку\n"))
        #expect(report.contains("[ ] Экран"))
        #expect(report.components(separatedBy: "[Подготовка]").count == 2)
        #expect(report.contains("[Завершение]"))
    }
}
