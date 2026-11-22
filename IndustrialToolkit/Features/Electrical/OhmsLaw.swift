import Foundation

// MARK: - Engineering notation

enum EngineeringNotation {
    private static let prefixes: [(factor: Double, symbol: String)] = [
        (1e6, "М"), (1e3, "к"), (1, ""), (1e-3, "м"), (1e-6, "мк"),
    ]

    /// Scales a value so its mantissa falls in 1…1000 with a Russian SI prefix (кОм, мА, кВт).
    static func scale(_ value: Double) -> (value: Double, prefix: String) {
        guard value.isFinite, value != 0 else { return (value, "") }
        let magnitude = abs(value)
        let chosen = prefixes.first { magnitude >= $0.factor } ?? prefixes[prefixes.count - 1]
        return (value / chosen.factor, chosen.symbol)
    }

    static func format(_ value: Double, unit: String, fractionDigits: Int = 3) -> (value: String, unit: String) {
        let scaled = scale(value)
        return (Fmt.number(scaled.value, fractionDigits: fractionDigits), scaled.prefix + unit)
    }
}

// MARK: - DC: Ohm's law

struct EngineeringUnit: Hashable {
    let symbol: String
    let factor: Double
}

enum OhmQuantity: String, CaseIterable, Identifiable {
    case voltage
    case current
    case resistance
    case power

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .voltage: "U"
        case .current: "I"
        case .resistance: "R"
        case .power: "P"
        }
    }

    var title: String {
        switch self {
        case .voltage: "Напряжение"
        case .current: "Ток"
        case .resistance: "Сопротивление"
        case .power: "Мощность"
        }
    }

    var baseUnit: String {
        switch self {
        case .voltage: "В"
        case .current: "А"
        case .resistance: "Ом"
        case .power: "Вт"
        }
    }

    var units: [EngineeringUnit] {
        let base = baseUnit
        switch self {
        case .voltage:
            return [.init(symbol: "м" + base, factor: 1e-3), .init(symbol: base, factor: 1), .init(symbol: "к" + base, factor: 1e3)]
        case .current:
            return [.init(symbol: "м" + base, factor: 1e-3), .init(symbol: base, factor: 1)]
        case .resistance:
            return [.init(symbol: base, factor: 1), .init(symbol: "к" + base, factor: 1e3), .init(symbol: "М" + base, factor: 1e6)]
        case .power:
            return [.init(symbol: "м" + base, factor: 1e-3), .init(symbol: base, factor: 1), .init(symbol: "к" + base, factor: 1e3)]
        }
    }

    var defaultUnit: EngineeringUnit { units.first { $0.factor == 1 } ?? units[0] }
}

/// Which two quantities the user knows.
enum OhmPair: String, CaseIterable, Identifiable {
    case voltageCurrent
    case voltageResistance
    case voltagePower
    case currentResistance
    case currentPower
    case resistancePower

    var id: String { rawValue }

    var quantities: (first: OhmQuantity, second: OhmQuantity) {
        switch self {
        case .voltageCurrent: (.voltage, .current)
        case .voltageResistance: (.voltage, .resistance)
        case .voltagePower: (.voltage, .power)
        case .currentResistance: (.current, .resistance)
        case .currentPower: (.current, .power)
        case .resistancePower: (.resistance, .power)
        }
    }

    var title: String { "\(quantities.first.symbol) и \(quantities.second.symbol)" }

    var formulas: [String] {
        switch self {
        case .voltageCurrent: ["R = U / I", "P = U · I"]
        case .voltageResistance: ["I = U / R", "P = U² / R"]
        case .voltagePower: ["I = P / U", "R = U² / P"]
        case .currentResistance: ["U = I · R", "P = I² · R"]
        case .currentPower: ["U = P / I", "R = P / I²"]
        case .resistancePower: ["U = √(P · R)", "I = √(P / R)"]
        }
    }

    func contains(_ quantity: OhmQuantity) -> Bool {
        quantities.first == quantity || quantities.second == quantity
    }
}

struct OhmsLawSolution: Equatable {
    let voltage: Double
    let current: Double
    let resistance: Double
    let power: Double

    func value(of quantity: OhmQuantity) -> Double {
        switch quantity {
        case .voltage: voltage
        case .current: current
        case .resistance: resistance
        case .power: power
        }
    }
}

enum OhmsLaw {
    /// Solves U = I·R and P = U·I from any two known quantities (base SI units, all > 0).
    static func solve(_ pair: OhmPair, first a: Double, second b: Double) -> OhmsLawSolution? {
        guard a.isFinite, b.isFinite, a > 0, b > 0 else { return nil }
        let voltageAndCurrent: (voltage: Double, current: Double) = switch pair {
        case .voltageCurrent: (a, b)
        case .voltageResistance: (a, a / b)
        case .voltagePower: (a, b / a)
        case .currentResistance: (a * b, a)
        case .currentPower: (b / a, a)
        case .resistancePower: ((b * a).squareRoot(), (b / a).squareRoot())
        }
        let u = voltageAndCurrent.voltage
        let i = voltageAndCurrent.current
        return OhmsLawSolution(voltage: u, current: i, resistance: u / i, power: u * i)
    }
}

// MARK: - AC power

enum ACPowerInput: String, CaseIterable, Identifiable {
    case voltageCurrent
    case activePower
    case activeReactive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .voltageCurrent: "U, I, cos φ"
        case .activePower: "P, U, cos φ"
        case .activeReactive: "P, Q, U"
        }
    }
}

struct ACPowerResult: Equatable {
    /// Apparent power S, В·А.
    let apparent: Double
    /// Active power P, Вт.
    let active: Double
    /// Reactive power Q, вар (inductive, positive).
    let reactive: Double
    /// Phase (line) current, А.
    let current: Double
    let powerFactor: Double

    var phiDegrees: Double { acos(powerFactor) * 180 / .pi }
}

/// S = k·U·I, P = S·cos φ, Q = S·sin φ; k = 1 for single-phase, √3 for three-phase with line voltage.
enum ACPower {
    private static func factor(_ system: PowerSystem) -> Double? {
        switch system {
        case .dc: nil
        case .singlePhase: 1
        case .threePhase: 3.squareRoot()
        }
    }

    private static func isValidPowerFactor(_ value: Double) -> Bool { value > 0 && value <= 1 }

    static func fromVoltageCurrent(system: PowerSystem, voltage: Double, current: Double, powerFactor: Double) -> ACPowerResult? {
        guard let k = factor(system), voltage > 0, current > 0, isValidPowerFactor(powerFactor) else { return nil }
        let apparent = k * voltage * current
        return result(apparent: apparent, powerFactor: powerFactor, current: current)
    }

    static func fromActivePower(system: PowerSystem, activePower: Double, voltage: Double, powerFactor: Double) -> ACPowerResult? {
        guard let k = factor(system), activePower > 0, voltage > 0, isValidPowerFactor(powerFactor) else { return nil }
        let apparent = activePower / powerFactor
        return result(apparent: apparent, powerFactor: powerFactor, current: apparent / (k * voltage))
    }

    static func fromActiveReactive(system: PowerSystem, activePower: Double, reactivePower: Double, voltage: Double) -> ACPowerResult? {
        guard let k = factor(system), activePower > 0, reactivePower >= 0, voltage > 0 else { return nil }
        let apparent = (activePower * activePower + reactivePower * reactivePower).squareRoot()
        return result(apparent: apparent, powerFactor: activePower / apparent, current: apparent / (k * voltage))
    }

    /// Reactive power of a capacitor bank raising cos φ: Qc = P·(tg φ₁ − tg φ₂). Zero when already at target.
    static func compensation(activePower: Double, from current: Double, to target: Double) -> Double? {
        guard activePower > 0, isValidPowerFactor(current), isValidPowerFactor(target) else { return nil }
        let tangent = { (pf: Double) -> Double in (1 - pf * pf).squareRoot() / pf }
        return max(0, activePower * (tangent(current) - tangent(target)))
    }

    private static func result(apparent: Double, powerFactor: Double, current: Double) -> ACPowerResult {
        let sinPhi = (1 - powerFactor * powerFactor).squareRoot()
        return ACPowerResult(
            apparent: apparent,
            active: apparent * powerFactor,
            reactive: apparent * sinPhi,
            current: current,
            powerFactor: powerFactor
        )
    }
}
