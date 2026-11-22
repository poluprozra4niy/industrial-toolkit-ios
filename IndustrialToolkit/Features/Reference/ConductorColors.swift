import Foundation

enum WireColor: String, CaseIterable, Identifiable {
    case black
    case brown
    case red
    case orange
    case yellow
    case green
    case blue
    case violet
    case grey
    case white
    case pink
    case turquoise
    case yellowGreen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: "чёрный"
        case .brown: "коричневый"
        case .red: "красный"
        case .orange: "оранжевый"
        case .yellow: "жёлтый"
        case .green: "зелёный"
        case .blue: "синий (голубой)"
        case .violet: "фиолетовый"
        case .grey: "серый"
        case .white: "белый"
        case .pink: "розовый"
        case .turquoise: "бирюзовый"
        case .yellowGreen: "жёлто-зелёный"
        }
    }
}

/// Insulation colour with optional end/joint markings in another colour (PEN, PEL, PEM).
struct ConductorColoring: Equatable {
    let main: WireColor
    let marks: WireColor?
}

struct ConductorMarking: Identifiable {
    let designation: String
    let name: String
    let colorings: [ConductorColoring]
    let rule: String
    let clause: String

    var id: String { designation }
}

/// Identification of conductors by colour, ГОСТ Р 50462-2009 (МЭК 60446:2007).
enum ConductorColors {
    static let source = "ГОСТ Р 50462-2009 (МЭК 60446:2007)"
    static let currentStandardNote = "Заменён ГОСТ 33542-2015 (IEC 60445:2010). При спорных случаях сверяйтесь с действующим текстом."

    static let markings: [ConductorMarking] = [
        ConductorMarking(
            designation: "PE",
            name: "Защитный проводник",
            colorings: [ConductorColoring(main: .yellowGreen, marks: nil)],
            rule: "Жёлто-зелёный: на любом участке 15 мм один цвет занимает 30–70 % поверхности, другой — остальное",
            clause: "5.3.2"
        ),
        ConductorMarking(
            designation: "N",
            name: "Нейтральный проводник",
            colorings: [ConductorColoring(main: .blue, marks: nil)],
            rule: "Синий цвет не применяют для других проводников, кроме заземлённого фазного",
            clause: "5.2.2"
        ),
        ConductorMarking(
            designation: "M",
            name: "Средний проводник",
            colorings: [ConductorColoring(main: .blue, marks: nil)],
            rule: "Как нейтральный — синий",
            clause: "5.2.2"
        ),
        ConductorMarking(
            designation: "PEN",
            name: "Совмещённый PE + N",
            colorings: [
                ConductorColoring(main: .yellowGreen, marks: .blue),
                ConductorColoring(main: .blue, marks: .yellowGreen),
            ],
            rule: "Жёлто-зелёный по всей длине с синими метками на концах и в местах соединений, или наоборот",
            clause: "5.3.3"
        ),
        ConductorMarking(
            designation: "L",
            name: "Фаза однофазной цепи",
            colorings: [ConductorColoring(main: .brown, marks: nil)],
            rule: "Предпочтительно коричневый. Однофазное ответвление трёхфазной сети — цвет той фазы, от которой оно отходит",
            clause: "5.2.3"
        ),
        ConductorMarking(
            designation: "L1, L2, L3",
            name: "Фазы трёхфазной цепи",
            colorings: [
                ConductorColoring(main: .black, marks: nil),
                ConductorColoring(main: .brown, marks: nil),
                ConductorColoring(main: .grey, marks: nil),
            ],
            rule: "Предпочтительные цвета — чёрный, коричневый, серый. Цвета не обозначают чередование фаз",
            clause: "5.2.3, прим. 3"
        ),
        ConductorMarking(
            designation: "L+",
            name: "Положительный полюс DC",
            colorings: [ConductorColoring(main: .brown, marks: nil)],
            rule: "Предпочтительно коричневый",
            clause: "5.2.4"
        ),
        ConductorMarking(
            designation: "L−",
            name: "Отрицательный полюс DC",
            colorings: [ConductorColoring(main: .grey, marks: nil)],
            rule: "Предпочтительно серый",
            clause: "5.2.4"
        ),
        ConductorMarking(
            designation: "LE, LE+, LE−",
            name: "Заземлённая фаза или полюс",
            colorings: [ConductorColoring(main: .blue, marks: nil)],
            rule: "Синий; где возможна путаница с N/M — буквенно-цифровое обозначение на концах",
            clause: "5.2.3, прим. 1; 5.2.4"
        ),
        ConductorMarking(
            designation: "PEL, PEM",
            name: "Совмещённые PE + фаза / PE + средний",
            colorings: [ConductorColoring(main: .yellowGreen, marks: .blue)],
            rule: "Жёлто-зелёный по всей длине с синими метками на концах; обозначение PEL/PEM — где возможна путаница с PEN",
            clause: "5.3.4, 5.3.5"
        ),
        ConductorMarking(
            designation: "PB",
            name: "Защитное уравнивание потенциалов",
            colorings: [ConductorColoring(main: .yellowGreen, marks: nil)],
            rule: "Жёлто-зелёный",
            clause: "5.3.6"
        ),
    ]

    /// Permitted insulation colours (5.1).
    static let permittedColors: [WireColor] = [
        .black, .brown, .red, .orange, .yellow, .green, .blue, .violet, .grey, .white, .pink, .turquoise,
    ]

    static let rules = [
        "Жёлтый и зелёный по отдельности не применяют — только жёлто-зелёной комбинацией (5.2.1, 5.3.1).",
        "Где возможна путаница — буквенно-цифровые обозначения на концах и в местах соединений.",
        "Цифры 6 и 9, стоящие отдельно, подчёркивают (6.1).",
    ]
}
