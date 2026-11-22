import Foundation

/// Laying conditions = columns of ПУЭ tables 1.3.4–1.3.7.
enum ConductorLaying: String, CaseIterable, Identifiable {
    case wiresOpen
    case wiresPipe2
    case wiresPipe3
    case wiresPipe4
    case wiresPipeTwoCore
    case wiresPipeThreeCore
    case cableSingleAir
    case cableTwoAir
    case cableTwoGround
    case cableThreeAir
    case cableThreeGround

    var id: String { rawValue }

    var isWire: Bool {
        switch self {
        case .wiresOpen, .wiresPipe2, .wiresPipe3, .wiresPipe4, .wiresPipeTwoCore, .wiresPipeThreeCore: true
        default: false
        }
    }

    /// Column index inside the row values of the matching table.
    var column: Int {
        switch self {
        case .wiresOpen, .cableSingleAir: 0
        case .wiresPipe2, .cableTwoAir: 1
        case .wiresPipe3, .cableTwoGround: 2
        case .wiresPipe4, .cableThreeAir: 3
        case .wiresPipeTwoCore, .cableThreeGround: 4
        case .wiresPipeThreeCore: 5
        }
    }

    var title: String {
        switch self {
        case .wiresOpen: "Открыто"
        case .wiresPipe2: "Труба: 2 одножильных"
        case .wiresPipe3: "Труба: 3 одножильных"
        case .wiresPipe4: "Труба: 4 одножильных"
        case .wiresPipeTwoCore: "Труба: 1 двухжильный"
        case .wiresPipeThreeCore: "Труба: 1 трёхжильный"
        case .cableSingleAir: "Одножильный, воздух"
        case .cableTwoAir: "Двухжильный, воздух"
        case .cableTwoGround: "Двухжильный, земля"
        case .cableThreeAir: "Трёхжильный, воздух"
        case .cableThreeGround: "Трёхжильный, земля"
        }
    }

    static let wires = allCases.filter(\.isWire)
    static let cables = allCases.filter { !$0.isWire }
}

/// Reduction for more than four simultaneously loaded wires in pipes, boxes or bundled on trays (ПУЭ 1.3.10).
enum WireBundle: String, CaseIterable, Identifiable {
    case upToFour
    case fiveToSix
    case sevenToNine
    case tenToTwelve

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upToFour: "≤ 4"
        case .fiveToSix: "5–6"
        case .sevenToNine: "7–9"
        case .tenToTwelve: "10–12"
        }
    }

    var factor: Double {
        switch self {
        case .upToFour: 1
        case .fiveToSix: 0.68
        case .sevenToNine: 0.63
        case .tenToTwelve: 0.6
        }
    }
}

struct AmpacityEntry: Identifiable, Equatable {
    let section: Double
    let ampacity: Double

    var id: Double { section }
}

/// Continuous current ratings for rubber/PVC insulated wires and cables, ПУЭ гл. 1.3, табл. 1.3.4–1.3.7.
/// Conditions: conductor +65 °C, air +25 °C, ground +15 °C (1.3.10).
enum CableAmpacity {
    struct Row {
        let section: Double
        let values: [Double?]
    }

    static let conditions = "Жила +65 °C, воздух +25 °C, земля +15 °C (ПУЭ 1.3.10)"

    /// Табл. 1.3.4: open | pipe 2×1 | 3×1 | 4×1 | 1×2-core | 1×3-core.
    static let copperWires: [Row] = [
        Row(section: 0.5, values: [11, nil, nil, nil, nil, nil]),
        Row(section: 0.75, values: [15, nil, nil, nil, nil, nil]),
        Row(section: 1, values: [17, 16, 15, 14, 15, 14]),
        Row(section: 1.2, values: [20, 18, 16, 15, 16, 14.5]),
        Row(section: 1.5, values: [23, 19, 17, 16, 18, 15]),
        Row(section: 2, values: [26, 24, 22, 20, 23, 19]),
        Row(section: 2.5, values: [30, 27, 25, 25, 25, 21]),
        Row(section: 3, values: [34, 32, 28, 26, 28, 24]),
        Row(section: 4, values: [41, 38, 35, 30, 32, 27]),
        Row(section: 5, values: [46, 42, 39, 34, 37, 31]),
        Row(section: 6, values: [50, 46, 42, 40, 40, 34]),
        Row(section: 8, values: [62, 54, 51, 46, 48, 43]),
        Row(section: 10, values: [80, 70, 60, 50, 55, 50]),
        Row(section: 16, values: [100, 85, 80, 75, 80, 70]),
        Row(section: 25, values: [140, 115, 100, 90, 100, 85]),
        Row(section: 35, values: [170, 135, 125, 115, 125, 100]),
        Row(section: 50, values: [215, 185, 170, 150, 160, 135]),
        Row(section: 70, values: [270, 225, 210, 185, 195, 175]),
        Row(section: 95, values: [330, 275, 255, 225, 245, 215]),
        Row(section: 120, values: [385, 315, 290, 260, 295, 250]),
        Row(section: 150, values: [440, 360, 330, nil, nil, nil]),
        Row(section: 185, values: [510, nil, nil, nil, nil, nil]),
        Row(section: 240, values: [605, nil, nil, nil, nil, nil]),
        Row(section: 300, values: [695, nil, nil, nil, nil, nil]),
        Row(section: 400, values: [830, nil, nil, nil, nil, nil]),
    ]

    /// Табл. 1.3.5: same columns, aluminium.
    static let aluminiumWires: [Row] = [
        Row(section: 2, values: [21, 19, 18, 15, 17, 14]),
        Row(section: 2.5, values: [24, 20, 19, 19, 19, 16]),
        Row(section: 3, values: [27, 24, 22, 21, 22, 18]),
        Row(section: 4, values: [32, 28, 28, 23, 25, 21]),
        Row(section: 5, values: [36, 32, 30, 27, 28, 24]),
        Row(section: 6, values: [39, 36, 32, 30, 31, 26]),
        Row(section: 8, values: [46, 43, 40, 37, 38, 32]),
        Row(section: 10, values: [60, 50, 47, 39, 42, 38]),
        Row(section: 16, values: [75, 60, 60, 55, 60, 55]),
        Row(section: 25, values: [105, 85, 80, 70, 75, 65]),
        Row(section: 35, values: [130, 100, 95, 85, 95, 75]),
        Row(section: 50, values: [165, 140, 130, 120, 125, 105]),
        Row(section: 70, values: [210, 175, 165, 140, 150, 135]),
        Row(section: 95, values: [255, 215, 200, 175, 190, 165]),
        Row(section: 120, values: [295, 245, 220, 200, 230, 190]),
        Row(section: 150, values: [340, 275, 255, nil, nil, nil]),
        Row(section: 185, values: [390, nil, nil, nil, nil, nil]),
        Row(section: 240, values: [465, nil, nil, nil, nil, nil]),
        Row(section: 300, values: [535, nil, nil, nil, nil, nil]),
        Row(section: 400, values: [645, nil, nil, nil, nil, nil]),
    ]

    /// Табл. 1.3.6: single-core air | two-core air | two-core ground | three-core air | three-core ground.
    static let copperCables: [Row] = [
        Row(section: 1.5, values: [23, 19, 33, 19, 27]),
        Row(section: 2.5, values: [30, 27, 44, 25, 38]),
        Row(section: 4, values: [41, 38, 55, 35, 49]),
        Row(section: 6, values: [50, 50, 70, 42, 60]),
        Row(section: 10, values: [80, 70, 105, 55, 90]),
        Row(section: 16, values: [100, 90, 135, 75, 115]),
        Row(section: 25, values: [140, 115, 175, 95, 150]),
        Row(section: 35, values: [170, 140, 210, 120, 180]),
        Row(section: 50, values: [215, 175, 265, 145, 225]),
        Row(section: 70, values: [270, 215, 320, 180, 275]),
        Row(section: 95, values: [325, 260, 385, 220, 330]),
        Row(section: 120, values: [385, 300, 445, 260, 385]),
        Row(section: 150, values: [440, 350, 505, 305, 435]),
        Row(section: 185, values: [510, 405, 570, 350, 500]),
        Row(section: 240, values: [605, nil, nil, nil, nil]),
    ]

    /// Табл. 1.3.7: same columns, aluminium cables.
    static let aluminiumCables: [Row] = [
        Row(section: 2.5, values: [23, 21, 34, 19, 29]),
        Row(section: 4, values: [31, 29, 42, 27, 38]),
        Row(section: 6, values: [38, 38, 55, 32, 46]),
        Row(section: 10, values: [60, 55, 80, 42, 70]),
        Row(section: 16, values: [75, 70, 105, 60, 90]),
        Row(section: 25, values: [105, 90, 135, 75, 115]),
        Row(section: 35, values: [130, 105, 160, 90, 140]),
        Row(section: 50, values: [165, 135, 205, 110, 175]),
        Row(section: 70, values: [210, 165, 245, 140, 210]),
        Row(section: 95, values: [250, 200, 295, 170, 255]),
        Row(section: 120, values: [295, 230, 340, 200, 295]),
        Row(section: 150, values: [340, 270, 390, 235, 335]),
        Row(section: 185, values: [390, 310, 440, 270, 385]),
        Row(section: 240, values: [465, nil, nil, nil, nil]),
    ]

    static func tableNumber(material: ConductorMaterial, laying: ConductorLaying) -> String {
        switch (laying.isWire, material) {
        case (true, .copper): "1.3.4"
        case (true, .aluminium): "1.3.5"
        case (false, .copper): "1.3.6"
        case (false, .aluminium): "1.3.7"
        }
    }

    private static func rows(material: ConductorMaterial, wires: Bool) -> [Row] {
        switch (wires, material) {
        case (true, .copper): copperWires
        case (true, .aluminium): aluminiumWires
        case (false, .copper): copperCables
        case (false, .aluminium): aluminiumCables
        }
    }

    /// Ratings for one column. Bundles of more than four wires use the "open" column times the 1.3.10 factor.
    static func entries(material: ConductorMaterial, laying: ConductorLaying, bundle: WireBundle = .upToFour) -> [AmpacityEntry] {
        let reduced = laying.isWire && bundle != .upToFour
        let column = reduced ? ConductorLaying.wiresOpen.column : laying.column
        let factor = reduced ? bundle.factor : 1
        return rows(material: material, wires: laying.isWire).compactMap { row in
            row.values[column].map { AmpacityEntry(section: row.section, ampacity: $0 * factor) }
        }
    }

    /// Smallest tabulated section whose continuous rating is at least `current`.
    static func minimumSection(for current: Double, material: ConductorMaterial, laying: ConductorLaying, bundle: WireBundle = .upToFour) -> AmpacityEntry? {
        guard current > 0 else { return nil }
        return entries(material: material, laying: laying, bundle: bundle).first { $0.ampacity >= current }
    }
}
