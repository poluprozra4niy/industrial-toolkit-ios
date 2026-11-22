import Foundation
import Testing
@testable import IndustrialToolkit

@Suite("Список сигналов: CSV и импорт")
struct IOListTests {
    @Test("CSV: кавычки, разделитель внутри поля, CRLF, пустые строки")
    func csvParsing() {
        let text = "Тег;Описание\r\n\"PT-1\";\"Давление; вход \"\"А\"\"\"\r\n\r\nTT-2;\"две\nстроки\"\r\n"
        let rows = CSVParser.parse(text, delimiter: ";")
        #expect(rows == [["Тег", "Описание"], ["PT-1", "Давление; вход \"А\""], ["TT-2", "две\nстроки"]])
    }

    @Test("Определение разделителя")
    func delimiter() {
        #expect(CSVParser.detectDelimiter(in: "Тег;Описание;Тип\nA;B;C") == ";")
        #expect(CSVParser.detectDelimiter(in: "Tag,Description,Type\n1,2,3") == ",")
        #expect(CSVParser.detectDelimiter(in: "Tag\tDescription\n1\t2") == "\t")
        #expect(CSVParser.detectDelimiter(in: "\"a,b\";c\n") == ";")
        #expect(CSVParser.detectDelimiter(in: "Tag") == ";")
    }

    @Test("Кодировки: UTF-8 с BOM и Windows-1251")
    func encodings() throws {
        let bom = Data([0xEF, 0xBB, 0xBF]) + Data("Тег".utf8)
        #expect(CSVParser.decodeText(bom) == "Тег")
        let cp1251 = try #require("Тег;Описание".data(using: .windowsCP1251))
        #expect(CSVParser.decodeText(cp1251) == "Тег;Описание")
    }

    @Test("Диапазоны: сигнал и шкала")
    func ranges() throws {
        #expect(IORangeParser.signalRange("4-20 мА") == .mA4to20)
        #expect(IORangeParser.signalRange("4…20mA") == .mA4to20)
        #expect(IORangeParser.signalRange("0-10 В") == .v0to10)
        #expect(IORangeParser.signalRange("2-10V") == .v2to10)
        #expect(IORangeParser.signalRange("0-20") == .mA0to20)
        #expect(IORangeParser.signalRange("1-5") == .v1to5)
        #expect(IORangeParser.signalRange("Pt100") == nil)
        #expect(IORangeParser.numbers(in: "-50…150") == [-50, 150])
        #expect(IORangeParser.numbers(in: "0,5 ÷ 2,5") == [0.5, 2.5])
        let scale = try #require(IORangeParser.scale("0…100 м³/ч"))
        #expect(scale.low == 0)
        #expect(scale.high == 100)
        #expect(scale.unit == "м³/ч")
    }

    @Test("Тип сигнала")
    func kinds() {
        #expect(IOSignalKind.parse("ai") == .ai)
        #expect(IOSignalKind.parse("АI") == .ai)
        #expect(IOSignalKind.parse("DO") == .dout)
        #expect(IOSignalKind.parse("DI-24V") == .di)
        #expect(IOSignalKind.parse("AIX") == nil)
    }

    @Test("Шаблон импортируется полностью")
    func template() throws {
        guard case .success(let outcome) = IOListImporter.importCSV(IOListImporter.templateCSV) else {
            Issue.record("шаблон должен импортироваться")
            return
        }
        #expect(outcome.records.map(\.kind) == [.ai, .ai, .ao, .di, .dout])
        let temperature = outcome.records[1]
        #expect(temperature.low == -50)
        #expect(temperature.high == 150)
        #expect(temperature.unit == "°C")
        #expect(temperature.address == "%IW66")
        #expect(outcome.records[3].signal == nil)
        #expect(outcome.columns.contains(.unit))
        let scale = try #require(outcome.records[0].scale)
        #expect(scale.loopCheckTable.map(\.processValue) == [0, 2.5, 5, 7.5, 10])
    }

    @Test("Excel-экспорт с другими заголовками, шкалой одной колонкой и пустыми строками")
    func alternateHeaders() {
        let text = """
        Позиция,Наименование,Тип сигнала,Диапазон измерения,Канал
        FT-201,Расход воды,4-20 мА,"0…100 м³/ч",AI3.1
        ,,,,
        GS-202,Концевик задвижки,,,DI1.4
        """
        guard case .success(let outcome) = IOListImporter.importCSV(text) else {
            Issue.record("импорт должен пройти")
            return
        }
        #expect(outcome.records.count == 2)
        let flow = outcome.records[0]
        #expect(flow.kind == .ai)
        #expect(flow.signal == .mA4to20)
        #expect(flow.high == 100)
        #expect(flow.unit == "м³/ч")
        #expect(flow.address == "AI3.1")
        #expect(outcome.records[1].kind == .di)
    }

    @Test("Ошибки импорта")
    func failures() {
        #expect(IOListImporter.importCSV("Описание;Тип\nДавление;AI") == .failure(.noTagColumn))
        #expect(IOListImporter.importCSV("Тег;Тип") == .failure(.empty))
    }

    @Test("Протокол группирует по типам и считает итог")
    func report() {
        let analog = IOSignalRecord(tag: "PT-1", details: "Давление", kind: .ai, signal: .mA4to20, low: 0, high: 10, unit: "бар", address: "%IW64")
        let discrete = IOSignalRecord(tag: "LS-2", details: "", kind: .di, signal: nil, low: nil, high: nil, unit: "", address: "")
        let points = [
            IOPointSnapshot(record: analog, status: .passed, remark: "", checkedAt: nil),
            IOPointSnapshot(record: discrete, status: .failed, remark: "Обрыв", checkedAt: nil),
        ]
        let document = IOListReport.document(
            name: "Шкаф 1",
            points: points,
            signers: ReportSigners(performer: "", organization: "", customer: ""),
            issuedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
        #expect(document.sections.map(\.title) == ["Аналоговые входы (AI)", "Дискретные входы (DI)"])
        #expect(document.sections[0].rows[0].text == "PT-1 — Давление")
        #expect(document.sections[1].rows[0].details.contains("Замечание: Обрыв"))
        #expect(document.summaryLines == ["Норма: 1", "С замечаниями: 1", "Не проверено: 0"])
        #expect(IOListReport.progress(of: points) == ChecklistProgress(done: 2, total: 2))
    }
}
