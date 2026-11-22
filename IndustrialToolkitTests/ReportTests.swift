import Foundation
import Testing
@testable import IndustrialToolkit
#if os(iOS)
import PDFKit
import UIKit
#endif

@Suite("PDF-протокол")
struct ReportTests {
    private let created = Date(timeIntervalSince1970: 1_790_000_000)
    private let signers = ReportSigners(performer: "Иванов И. И.", organization: "ООО «Наладка»", customer: "")

    private var lines: [ChecklistLine] {
        [
            ChecklistLine(section: "Подготовка", text: "Маркировка", isDone: true, remark: "", checkedAt: created),
            ChecklistLine(section: "Подготовка", text: "Изоляция", isDone: false, remark: "R = 0,3 МОм", checkedAt: nil),
            ChecklistLine(section: "Проверка", text: "4 мА", isDone: false, remark: "", checkedAt: nil),
        ]
    }

    @Test("Секции, статусы, фото и итог")
    func checklistDocument() {
        let photo = Data([0xFF, 0xD8])
        let document = ChecklistReport.document(
            objectName: "PT-101",
            kindTitle: "Loop check AI",
            createdAt: created,
            lines: lines,
            photos: [[photo], [], []],
            signers: signers,
            issuedAt: created
        )
        #expect(document.sections.map(\.title) == ["Подготовка", "Проверка"])
        #expect(document.sections[0].rows.map(\.status) == [.passed, .failed])
        #expect(document.sections[1].rows.first?.status == .pending)
        #expect(document.sections[0].rows[0].images == [photo])
        #expect(document.sections[0].rows[1].details.contains("Замечание: R = 0,3 МОм"))
        #expect(document.summaryLines.contains("Выполнено пунктов: 1 из 3"))
        #expect(document.summaryLines.contains("Замечаний: 1"))
        #expect(document.headerLines.contains("Организация: ООО «Наладка»"))
        #expect(document.signatures.map(\.role) == ["Выполнил", "Представитель заказчика"])
    }

    @Test("Имя файла без запрещённых символов")
    func fileName() {
        let name = ReportFileName.make(prefix: "Протокол", object: "КНС-2 / PT:101", date: created)
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
        #expect(name.hasPrefix("Протокол_КНС-2_-_PT-101_"))
        #expect(name.hasSuffix(".pdf"))
        #expect(ReportFileName.make(prefix: "Протокол", object: "  ", date: created).hasPrefix("Протокол_20"))
    }

    #if os(iOS)
    @Test("Рендер: длинный протокол разбивается на страницы, фото рисуются")
    func render() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        let jpeg = try #require(image.jpegData(compressionQuality: 0.7))
        let manyLines = (0..<120).map {
            ChecklistLine(section: "Раздел \($0 / 20)", text: "Пункт проверки номер \($0)", isDone: $0.isMultiple(of: 2), remark: "", checkedAt: nil)
        }
        let photos = (0..<120).map { $0 < 4 ? [jpeg, jpeg] : [] }
        let document = ChecklistReport.document(
            objectName: "PT-101",
            kindTitle: "Loop check AI",
            createdAt: created,
            lines: manyLines,
            photos: photos,
            signers: signers,
            issuedAt: created
        )
        let data = ReportPDFRenderer.render(document)
        let pdf = try #require(PDFDocument(data: data))
        #expect(pdf.pageCount >= 3)
        #expect(pdf.string?.contains("PT-101") == true)
        #expect(pdf.string?.contains("Иванов") == true)
    }
    #endif
}
