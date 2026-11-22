import Foundation

/// Power budget of a 2-wire 4–20 mA loop: the transmitter gets what the supply has left
/// after every series resistance and the barrier/isolator drop at the highest loop current.
struct LoopBudget: Equatable {
    /// HART needs a loop resistance of at least 230 Ω so the modem can read the signal (HCF FSK spec).
    static let hartMinimumResistance = 230.0

    let supplyVoltage: Double
    let transmitterMinimumVoltage: Double
    /// Highest current the loop must carry, A (20 mA nominal, up to ~22 mA for NAMUR NE43 alarms).
    let current: Double
    let loadResistance: Double
    let lineResistance: Double
    let barrierResistance: Double
    let barrierDrop: Double

    init?(
        supplyVoltage: Double,
        transmitterMinimumVoltage: Double,
        current: Double,
        loadResistance: Double,
        lineResistance: Double,
        barrierResistance: Double = 0,
        barrierDrop: Double = 0
    ) {
        let values = [supplyVoltage, transmitterMinimumVoltage, current, loadResistance, lineResistance, barrierResistance, barrierDrop]
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 }), supplyVoltage > 0, current > 0 else { return nil }
        self.supplyVoltage = supplyVoltage
        self.transmitterMinimumVoltage = transmitterMinimumVoltage
        self.current = current
        self.loadResistance = loadResistance
        self.lineResistance = lineResistance
        self.barrierResistance = barrierResistance
        self.barrierDrop = barrierDrop
    }

    var totalResistance: Double { loadResistance + lineResistance + barrierResistance }

    var terminalVoltage: Double { supplyVoltage - barrierDrop - current * totalResistance }

    var margin: Double { terminalVoltage - transmitterMinimumVoltage }

    var isSufficient: Bool { margin >= 0 }

    /// Largest total series resistance that still leaves the transmitter its minimum voltage.
    var maximumResistance: Double { max(0, (supplyVoltage - barrierDrop - transmitterMinimumVoltage) / current) }

    /// Lowest supply voltage that still works with the present resistances.
    var minimumSupplyVoltage: Double { transmitterMinimumVoltage + barrierDrop + current * totalResistance }

    var meetsHART: Bool { loadResistance + barrierResistance >= Self.hartMinimumResistance }

    func voltageAcrossLoad(at current: Double) -> Double { current * loadResistance }

    /// Both conductors of the pair: R = 2·ρ·L/S.
    static func lineResistance(length: Double, section: Double, material: ConductorMaterial, temperature: Double = 20) -> Double? {
        guard length >= 0, section > 0, length.isFinite, section.isFinite else { return nil }
        return 2 * material.resistivity(at: temperature) * length / section
    }

    /// Longest pair of the given section the remaining resistance allows.
    func maximumLineLength(section: Double, material: ConductorMaterial, temperature: Double = 20) -> Double? {
        guard section > 0 else { return nil }
        let available = maximumResistance - loadResistance - barrierResistance
        guard available > 0 else { return 0 }
        return available * section / (2 * material.resistivity(at: temperature))
    }
}
