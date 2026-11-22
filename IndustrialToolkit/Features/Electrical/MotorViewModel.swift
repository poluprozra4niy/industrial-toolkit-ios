import Foundation
import Observation

@MainActor
@Observable
final class MotorViewModel {
    struct FrequencyRow: Identifiable {
        let frequency: Double
        let speed: Double
        let percent: Double
        let pumpPower: Double

        var id: Double { frequency }
    }

    static let voltagePresets: [Double] = [230, 380, 400, 690]

    var supply: MotorSupply = .threePhase
    var powerText = "7.5"
    var voltageText = "380"
    var cosPhiText = "0.85"
    var efficiencyText = "88"
    var speedText = "1450"
    var frequencyText = "50"
    var startingRatioText = "7"
    var outputFrequencyText = "35"

    private func positive(_ text: String) -> Double? {
        guard let value = NumberParser.parse(text), value > 0 else { return nil }
        return value
    }

    func isInvalid(_ text: String) -> Bool { positive(text) == nil }

    func selectSupply(_ newSupply: MotorSupply) {
        supply = newSupply
        voltageText = newSupply == .threePhase ? "380" : "230"
    }

    var motor: MotorNameplate? {
        guard let power = positive(powerText),
              let voltage = positive(voltageText),
              let cosPhi = positive(cosPhiText),
              let efficiency = positive(efficiencyText),
              let speed = positive(speedText),
              let frequency = positive(frequencyText),
              let ratio = positive(startingRatioText)
        else { return nil }
        return MotorNameplate(
            power: power,
            voltage: voltage,
            cosPhi: cosPhi,
            efficiency: efficiency / 100,
            ratedSpeed: speed,
            frequency: frequency,
            startingRatio: ratio,
            supply: supply
        )
    }

    var validationHint: String {
        "cos φ — 0…1, КПД — 0…100 %, обороты ниже синхронных (60·f), кратность пуска ≥ 1."
    }

    var outputFrequency: Double? { positive(outputFrequencyText) }

    var frequencyRows: [FrequencyRow] {
        guard let motor else { return [] }
        let nominal = motor.frequency
        var frequencies = Array(stride(from: nominal, through: max(5, nominal * 0.3), by: -5))
        if let custom = outputFrequency, !frequencies.contains(custom) {
            frequencies.append(custom)
        }
        return frequencies.sorted(by: >).map { frequency in
            let speed = motor.speed(atFrequency: frequency)
            return FrequencyRow(
                frequency: frequency,
                speed: speed,
                percent: speed / motor.ratedSpeed * 100,
                pumpPower: motor.affinityPower(atFrequency: frequency)
            )
        }
    }

    var noteTitle: String { "Двигатель \(powerText) кВт, \(voltageText) В" }

    var summary: String? {
        guard let motor else { return nil }
        var lines = [
            "Двигатель \(Fmt.number(motor.power, fractionDigits: 2)) кВт, \(supply.title) \(Fmt.number(motor.voltage, fractionDigits: 0)) В, cos φ \(Fmt.number(motor.cosPhi, fractionDigits: 2)), КПД \(Fmt.number(motor.efficiency * 100, fractionDigits: 1)) %",
            "Номинальный ток: \(Fmt.number(motor.ratedCurrent, fractionDigits: 2)) А",
            "Пусковой ток: \(Fmt.number(motor.startingCurrent, fractionDigits: 1)) А (Y/Δ: \(Fmt.number(motor.starDeltaStartingCurrent, fractionDigits: 1)) А)",
            "Синхронная скорость \(Fmt.number(motor.synchronousSpeed, fractionDigits: 0)) об/мин, пар полюсов \(motor.polePairs), скольжение \(Fmt.number(motor.slip * 100, fractionDigits: 1)) %",
            "Момент: \(Fmt.number(motor.ratedTorque, fractionDigits: 1)) Н·м",
        ]
        for curve in BreakerCurve.allCases {
            if let check = motor.breakerCheck(curve: curve) {
                lines.append("Автомат \(check.breaker.name): \(check.survivesStart ? "пуск выдержит" : "возможно срабатывание при пуске")")
            }
        }
        return lines.joined(separator: "\n")
    }
}
