import Foundation

enum MotorSupply: String, CaseIterable, Identifiable {
    case threePhase
    case singlePhase

    var id: String { rawValue }

    var title: String {
        switch self {
        case .threePhase: "3~"
        case .singlePhase: "1~"
        }
    }

    /// I = P / (k·U·cos φ·η): k = √3 with line voltage, 1 for single phase.
    var currentFactor: Double {
        switch self {
        case .threePhase: 3.0.squareRoot()
        case .singlePhase: 1
        }
    }
}

/// Asynchronous motor from its nameplate: rated power is shaft (output) power.
struct MotorNameplate: Equatable {
    let power: Double
    let voltage: Double
    let cosPhi: Double
    let efficiency: Double
    let ratedSpeed: Double
    let frequency: Double
    let startingRatio: Double
    let supply: MotorSupply

    init?(
        power: Double,
        voltage: Double,
        cosPhi: Double,
        efficiency: Double,
        ratedSpeed: Double,
        frequency: Double = 50,
        startingRatio: Double = 7,
        supply: MotorSupply = .threePhase
    ) {
        guard power > 0, voltage > 0, frequency > 0, startingRatio >= 1,
              cosPhi > 0, cosPhi <= 1, efficiency > 0, efficiency <= 1,
              ratedSpeed > 0, ratedSpeed < 60 * frequency
        else { return nil }
        self.power = power
        self.voltage = voltage
        self.cosPhi = cosPhi
        self.efficiency = efficiency
        self.ratedSpeed = ratedSpeed
        self.frequency = frequency
        self.startingRatio = startingRatio
        self.supply = supply
    }

    /// Rated current, A (power in kW, voltage in V).
    var ratedCurrent: Double { power * 1_000 / (supply.currentFactor * voltage * cosPhi * efficiency) }

    /// Power drawn from the mains, kW.
    var inputPower: Double { power / efficiency }

    var apparentPower: Double { inputPower / cosPhi }

    var reactivePower: Double { (apparentPower * apparentPower - inputPower * inputPower).squareRoot() }

    /// Rated speed is just under synchronous, so p = ⌊60·f / n⌋.
    var polePairs: Int { max(1, Int((60 * frequency / ratedSpeed).rounded(.down))) }

    var synchronousSpeed: Double { 60 * frequency / Double(polePairs) }

    var slip: Double { (synchronousSpeed - ratedSpeed) / synchronousSpeed }

    var slipSpeed: Double { synchronousSpeed - ratedSpeed }

    /// M = 9550 · P[kW] / n[об/мин], Н·м.
    var ratedTorque: Double { 9_550 * power / ratedSpeed }

    var startingCurrent: Double { startingRatio * ratedCurrent }

    /// Star–delta start: line current and torque drop to one third of a direct start.
    var starDeltaStartingCurrent: Double { startingCurrent / 3 }

    /// Speed at another inverter frequency, assuming V/f control keeps the slip in rpm constant.
    func speed(atFrequency outputFrequency: Double) -> Double {
        max(0, 60 * outputFrequency / Double(polePairs) - slipSpeed)
    }

    /// Centrifugal pump or fan (affinity laws): Q ∝ n, H ∝ n², P ∝ n³.
    func affinityPower(atFrequency outputFrequency: Double) -> Double {
        let ratio = speed(atFrequency: outputFrequency) / ratedSpeed
        return power * ratio * ratio * ratio
    }

    /// Smallest preferred rating ≥ rated current and whether its instantaneous release
    /// stays below the starting current (ГОСТ IEC 60898-1: no trip below the lower multiple).
    func breakerCheck(curve: BreakerCurve) -> MotorBreakerCheck? {
        guard let rating = BreakerSelection.preferredRatings.first(where: { $0 >= ratedCurrent }) else { return nil }
        let breaker = BreakerSelection(curve: curve, rating: rating)
        return MotorBreakerCheck(breaker: breaker, survivesStart: startingCurrent < breaker.instantaneousLower)
    }
}

struct MotorBreakerCheck: Equatable {
    let breaker: BreakerSelection
    let survivesStart: Bool
}
