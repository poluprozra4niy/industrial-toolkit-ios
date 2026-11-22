import Foundation

enum PowerSystem: String, CaseIterable, Identifiable {
    case dc
    case singlePhase
    case threePhase

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dc: "DC"
        case .singlePhase: "1~ AC"
        case .threePhase: "3~ AC"
        }
    }

    var subtitle: String {
        switch self {
        case .dc: "Постоянный"
        case .singlePhase: "Однофазная"
        case .threePhase: "Трёхфазная"
        }
    }

    var defaultVoltage: Double {
        switch self {
        case .dc: 24
        case .singlePhase: 230
        case .threePhase: 400
        }
    }

    /// Converts per-metre conductor impedance into the drop seen by the load:
    /// 2 for a go-and-return pair, √3 for the line-to-line drop of a balanced 3-phase load.
    var dropFactor: Double {
        switch self {
        case .dc, .singlePhase: 2
        case .threePhase: 3.squareRoot()
        }
    }

    /// Number of conductors carrying the full load current (heat loss).
    var lossFactor: Double {
        switch self {
        case .dc, .singlePhase: 2
        case .threePhase: 3
        }
    }

    var isAC: Bool { self != .dc }

    func current(fromPower watts: Double, voltage: Double, powerFactor: Double) -> Double {
        switch self {
        case .dc: watts / voltage
        case .singlePhase: watts / (voltage * powerFactor)
        case .threePhase: watts / (3.squareRoot() * voltage * powerFactor)
        }
    }
}

enum ConductorMaterial: String, CaseIterable, Identifiable {
    case copper
    case aluminium

    var id: String { rawValue }

    var title: String {
        switch self {
        case .copper: "Медь"
        case .aluminium: "Алюминий"
        }
    }

    /// Design resistivity at 20 °C, Ω·mm²/m.
    var resistivity20: Double {
        switch self {
        case .copper: 0.0175
        case .aluminium: 0.0282
        }
    }

    /// Temperature coefficient of resistance, 1/K.
    var temperatureCoefficient: Double {
        switch self {
        case .copper: 0.00393
        case .aluminium: 0.00403
        }
    }

    func resistivity(at celsius: Double) -> Double {
        resistivity20 * (1 + temperatureCoefficient * (celsius - 20))
    }
}

enum ConductorTemperature: Double, CaseIterable, Identifiable {
    case ambient = 20
    case pvc = 70
    case xlpe = 90

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .ambient: "20 °C"
        case .pvc: "70 °C"
        case .xlpe: "90 °C"
        }
    }

    var subtitle: String {
        switch self {
        case .ambient: "холодный"
        case .pvc: "ПВХ, макс."
        case .xlpe: "СПЭ, макс."
        }
    }
}

enum CableSections {
    /// Standard conductor cross-sections, mm².
    static let standard: [Double] = [
        0.5, 0.75, 1, 1.5, 2.5, 4, 6, 10, 16, 25, 35, 50, 70, 95, 120, 150, 185, 240, 300,
    ]

    static func nextStandard(atLeast section: Double) -> Double? {
        standard.first { $0 >= section - 1e-9 }
    }

    static func title(_ section: Double) -> String {
        Fmt.number(section, fractionDigits: 2)
    }
}

struct VoltageDropResult: Equatable {
    let current: Double
    let drop: Double
    let dropPercent: Double
    let loadVoltage: Double
    let powerLoss: Double
    let isWithinLimit: Bool
    /// Exact cross-section that meets the limit; nil when reactance alone already exceeds it.
    let minimumSection: Double?
    /// Smallest standard section ≥ `minimumSection`; nil when none up to 300 mm² is enough.
    let recommendedSection: Double?
    let maximumLength: Double
}

/// ΔU = k · I · L · (r·cos φ + x·sin φ), r = ρ(t)/S, with k from `PowerSystem.dropFactor`.
struct VoltageDropCalculation: Equatable {
    let system: PowerSystem
    let material: ConductorMaterial
    let conductorTemperature: Double
    let voltage: Double
    let powerFactor: Double
    let length: Double
    let section: Double
    /// Inductive reactance per metre, Ω/m (0 for DC).
    let reactance: Double
    let allowedDropPercent: Double

    init?(
        system: PowerSystem,
        material: ConductorMaterial,
        conductorTemperature: Double,
        voltage: Double,
        powerFactor: Double,
        length: Double,
        section: Double,
        reactancePerKm: Double,
        allowedDropPercent: Double
    ) {
        guard voltage > 0, length > 0, section > 0,
              powerFactor > 0, powerFactor <= 1,
              reactancePerKm >= 0,
              allowedDropPercent > 0, allowedDropPercent < 100
        else { return nil }
        self.system = system
        self.material = material
        self.conductorTemperature = conductorTemperature
        self.voltage = voltage
        self.powerFactor = system.isAC ? powerFactor : 1
        self.length = length
        self.section = section
        self.reactance = system.isAC ? reactancePerKm / 1000 : 0
        self.allowedDropPercent = allowedDropPercent
    }

    var resistivity: Double { material.resistivity(at: conductorTemperature) }

    private var sinPhi: Double { (1 - powerFactor * powerFactor).squareRoot() }

    private var allowedDrop: Double { voltage * allowedDropPercent / 100 }

    private func impedance(section: Double) -> Double {
        resistivity / section * powerFactor + reactance * sinPhi
    }

    func drop(current: Double, section: Double) -> Double {
        system.dropFactor * current * length * impedance(section: section)
    }

    func dropPercent(current: Double, section: Double) -> Double {
        drop(current: current, section: section) / voltage * 100
    }

    func result(current: Double) -> VoltageDropResult {
        let drop = drop(current: current, section: section)
        let dropPercent = drop / voltage * 100
        let perAmpMetre = system.dropFactor * current
        let resistiveBudget = allowedDrop / (perAmpMetre * length) - reactance * sinPhi
        let minimumSection: Double? = resistiveBudget > 0 ? resistivity * powerFactor / resistiveBudget : nil
        return VoltageDropResult(
            current: current,
            drop: drop,
            dropPercent: dropPercent,
            loadVoltage: voltage - drop,
            powerLoss: system.lossFactor * current * current * resistivity / section * length,
            isWithinLimit: dropPercent <= allowedDropPercent,
            minimumSection: minimumSection,
            recommendedSection: minimumSection.flatMap(CableSections.nextStandard(atLeast:)),
            maximumLength: allowedDrop / (perAmpMetre * impedance(section: section))
        )
    }
}
