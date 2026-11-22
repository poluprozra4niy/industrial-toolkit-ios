import Foundation

struct ChecklistItemTemplate: Equatable {
    let text: String
    let hint: String

    init(_ text: String, hint: String = "") {
        self.text = text
        self.hint = hint
    }
}

struct ChecklistSectionTemplate: Equatable {
    let title: String
    let items: [ChecklistItemTemplate]
}

/// Built-in commissioning checklists. Norms (insulation test voltage, minimum resistance)
/// are deliberately referenced, not hard-coded: they depend on the project and the edition of ПТЭЭП/ПУЭ.
enum ChecklistKind: String, CaseIterable, Identifiable {
    case analogLoop
    case discreteIO
    case insulation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .analogLoop: "Loop check: аналоговый канал"
        case .discreteIO: "Дискретные каналы DI / DO"
        case .insulation: "Проверка изоляции кабелей"
        }
    }

    var subtitle: String {
        switch self {
        case .analogLoop: "4–20 мА: 0/25/50/75/100 %, обрыв, уставки"
        case .discreteIO: "Состояния входов, команды выходов, обратная связь"
        case .insulation: "Мегаомметр: жила–жила, жила–земля"
        }
    }

    var symbol: String {
        switch self {
        case .analogLoop: "gauge.with.dots.needle.50percent"
        case .discreteIO: "switch.2"
        case .insulation: "bolt.shield"
        }
    }

    var sections: [ChecklistSectionTemplate] {
        switch self {
        case .analogLoop: Self.analogLoopSections
        case .discreteIO: Self.discreteIOSections
        case .insulation: Self.insulationSections
        }
    }

    var itemCount: Int { sections.reduce(0) { $0 + $1.items.count } }

    private static let analogLoopSections = [
        ChecklistSectionTemplate(title: "Подготовка", items: [
            ChecklistItemTemplate("Прибор соответствует спецификации", hint: "Тег, диапазон, тип сигнала, исполнение"),
            ChecklistItemTemplate("Маркировка кабеля и клемм соответствует схеме"),
            ChecklistItemTemplate("Экран заземлён с одной стороны", hint: "Обычно со стороны шкафа"),
            ChecklistItemTemplate("Шкала в ПЛК и SCADA совпадает со шкалой прибора", hint: "НПИ / ВПИ / единицы"),
        ]),
        ChecklistSectionTemplate(title: "Проверка контура", items: [
            ChecklistItemTemplate("4 мА (0 %): значение в ПЛК и SCADA"),
            ChecklistItemTemplate("8 мА (25 %): значение в ПЛК и SCADA"),
            ChecklistItemTemplate("12 мА (50 %): значение в ПЛК и SCADA"),
            ChecklistItemTemplate("16 мА (75 %): значение в ПЛК и SCADA"),
            ChecklistItemTemplate("20 мА (100 %): значение в ПЛК и SCADA"),
            ChecklistItemTemplate("Обрыв линии: авария канала в ПЛК и SCADA", hint: "Сигнал ≤ 3,6 мА по NAMUR NE43"),
            ChecklistItemTemplate("Уставки сигнализации L / LL / H / HH срабатывают"),
        ]),
        ChecklistSectionTemplate(title: "Завершение", items: [
            ChecklistItemTemplate("Имитатор снят, штатное подключение восстановлено"),
            ChecklistItemTemplate("Текущее значение с реального датчика достоверно"),
            ChecklistItemTemplate("Результат внесён в протокол"),
        ]),
    ]

    private static let discreteIOSections = [
        ChecklistSectionTemplate(title: "Подготовка", items: [
            ChecklistItemTemplate("Маркировка кабеля и клемм соответствует схеме"),
            ChecklistItemTemplate("Тип контакта NO / NC соответствует спецификации"),
        ]),
        ChecklistSectionTemplate(title: "Дискретные входы (DI)", items: [
            ChecklistItemTemplate("Исходное состояние входа в ПЛК и SCADA верное"),
            ChecklistItemTemplate("Срабатывание полевого устройства меняет состояние", hint: "Концевик, реле, кнопка, датчик"),
            ChecklistItemTemplate("Текст и цвет сигнала в SCADA соответствуют событию"),
            ChecklistItemTemplate("Обрыв цепи отображается как авария", hint: "Если канал с контролем обрыва"),
        ]),
        ChecklistSectionTemplate(title: "Дискретные выходы (DO)", items: [
            ChecklistItemTemplate("Команда из SCADA включает исполнительный механизм"),
            ChecklistItemTemplate("Обратная связь (ответный DI) приходит в заданное время"),
            ChecklistItemTemplate("Выход переходит в безопасное состояние при STOP ПЛК"),
            ChecklistItemTemplate("Блокировки и защиты запрещают команду, когда должны"),
        ]),
        ChecklistSectionTemplate(title: "Завершение", items: [
            ChecklistItemTemplate("Принудительные значения (force) сняты"),
            ChecklistItemTemplate("Результат внесён в протокол"),
        ]),
    ]

    private static let insulationSections = [
        ChecklistSectionTemplate(title: "Безопасность", items: [
            ChecklistItemTemplate("Линия отключена, приняты меры против подачи напряжения"),
            ChecklistItemTemplate("Отсутствие напряжения проверено указателем"),
        ]),
        ChecklistSectionTemplate(title: "Подготовка", items: [
            ChecklistItemTemplate("Электронные устройства отсоединены от проверяемых жил", hint: "Модули ПЛК, датчики, преобразователи"),
            ChecklistItemTemplate("Напряжение мегаомметра выбрано по нормам", hint: "ПТЭЭП прил. 3 и проект"),
        ]),
        ChecklistSectionTemplate(title: "Измерения", items: [
            ChecklistItemTemplate("Сопротивление жила–жила измерено и записано"),
            ChecklistItemTemplate("Сопротивление жила–земля (экран) измерено и записано"),
            ChecklistItemTemplate("Значения не ниже нормы", hint: "Норма — по ПТЭЭП прил. 3 и проекту"),
        ]),
        ChecklistSectionTemplate(title: "Завершение", items: [
            ChecklistItemTemplate("Жилы разряжены на землю после измерения"),
            ChecklistItemTemplate("Штатное подключение восстановлено"),
            ChecklistItemTemplate("Протокол измерения сопротивления изоляции оформлен"),
        ]),
    ]
}
