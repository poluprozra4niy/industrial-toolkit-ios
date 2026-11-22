import Foundation

enum ControllerType: String, CaseIterable, Identifiable {
    case p
    case pi
    case pid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .p: "П"
        case .pi: "ПИ"
        case .pid: "ПИД"
        }
    }
}

/// Standard (ISA) form: u = Kp·(e + 1/Ti·∫e dt + Td·de/dt).
struct PIDParameters: Equatable {
    let kp: Double
    let ti: Double?
    let td: Double?

    /// Parallel form integral gain, 1/с.
    var ki: Double? { ti.map { kp / $0 } }

    /// Parallel form derivative gain, с.
    var kd: Double? { td.map { kp * $0 } }

    /// Proportional band Xp = 100 / Kp, % — the setting used by ОВЕН-style controllers.
    var proportionalBand: Double { 100 / kp }
}

/// Rules from the ultimate gain Ku and ultimate period Tu (sustained oscillation test).
enum ClosedLoopRule: String, CaseIterable, Identifiable {
    case zieglerNichols
    case someOvershoot
    case noOvershoot
    case tyreusLuyben

    var id: String { rawValue }

    var title: String {
        switch self {
        case .zieglerNichols: "Циглер–Николс"
        case .someOvershoot: "Небольшое перерегулирование"
        case .noOvershoot: "Без перерегулирования"
        case .tyreusLuyben: "Тайреус–Люйбен"
        }
    }

    var note: String {
        switch self {
        case .zieglerNichols: "Классика: быстро, с заметным перерегулированием (~¼ затухания)"
        case .someOvershoot: "Модификация Циглера–Николса"
        case .noOvershoot: "Модификация Циглера–Николса, самая мягкая по Kp"
        case .tyreusLuyben: "Мягче и устойчивее, хорошо для процессов с запаздыванием"
        }
    }

    func parameters(_ type: ControllerType, ku: Double, tu: Double) -> PIDParameters? {
        guard ku > 0, tu > 0 else { return nil }
        switch (self, type) {
        case (.zieglerNichols, .p): return PIDParameters(kp: 0.5 * ku, ti: nil, td: nil)
        case (.zieglerNichols, .pi): return PIDParameters(kp: 0.45 * ku, ti: tu / 1.2, td: nil)
        case (.zieglerNichols, .pid): return PIDParameters(kp: 0.6 * ku, ti: 0.5 * tu, td: 0.125 * tu)
        case (.someOvershoot, .pid): return PIDParameters(kp: 0.33 * ku, ti: 0.5 * tu, td: 0.33 * tu)
        case (.noOvershoot, .pid): return PIDParameters(kp: 0.2 * ku, ti: 0.5 * tu, td: 0.33 * tu)
        case (.tyreusLuyben, .pi): return PIDParameters(kp: ku / 3.2, ti: 2.2 * tu, td: nil)
        case (.tyreusLuyben, .pid): return PIDParameters(kp: ku / 2.2, ti: 2.2 * tu, td: tu / 6.3)
        default: return nil
        }
    }
}

/// First-order-plus-dead-time model of a step response: gain K, dead time L, time constant T.
struct ProcessModel: Equatable {
    let gain: Double
    let deadTime: Double
    let timeConstant: Double

    init?(gain: Double, deadTime: Double, timeConstant: Double) {
        guard gain != 0, gain.isFinite, deadTime > 0, timeConstant > 0 else { return nil }
        self.gain = gain
        self.deadTime = deadTime
        self.timeConstant = timeConstant
    }

    /// Two-point method: T = 1,5·(t63 − t28), L = t63 − T, K = Δy / Δu.
    init?(outputStep: Double, processChange: Double, t28: Double, t63: Double) {
        guard outputStep != 0, t28 > 0, t63 > t28 else { return nil }
        let timeConstant = 1.5 * (t63 - t28)
        self.init(gain: processChange / outputStep, deadTime: t63 - timeConstant, timeConstant: timeConstant)
    }

    /// L / T — how hard the loop is: < 0,1 easy, > 1 dead-time dominated.
    var controllability: Double { deadTime / timeConstant }
}

enum OpenLoopRule: String, CaseIterable, Identifiable {
    case zieglerNichols
    case cohenCoon
    case simc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .zieglerNichols: "Циглер–Николс"
        case .cohenCoon: "Коэн–Кун"
        case .simc: "SIMC (Скогестад)"
        }
    }

    var note: String {
        switch self {
        case .zieglerNichols: "По кривой разгона; агрессивно при L/T > 0,5"
        case .cohenCoon: "Учитывает L/T, подходит для большего запаздывания"
        case .simc: "Робастная ПИ-настройка, τc = L"
        }
    }

    func parameters(_ type: ControllerType, model: ProcessModel) -> PIDParameters? {
        let k = model.gain
        let l = model.deadTime
        let t = model.timeConstant
        let ratio = l / t
        switch (self, type) {
        case (.zieglerNichols, .p):
            return PIDParameters(kp: t / (k * l), ti: nil, td: nil)
        case (.zieglerNichols, .pi):
            return PIDParameters(kp: 0.9 * t / (k * l), ti: l / 0.3, td: nil)
        case (.zieglerNichols, .pid):
            return PIDParameters(kp: 1.2 * t / (k * l), ti: 2 * l, td: 0.5 * l)
        case (.cohenCoon, .p):
            return PIDParameters(kp: t / (k * l) * (1 + ratio / 3), ti: nil, td: nil)
        case (.cohenCoon, .pi):
            return PIDParameters(
                kp: t / (k * l) * (0.9 + ratio / 12),
                ti: l * (30 + 3 * ratio) / (9 + 20 * ratio),
                td: nil
            )
        case (.cohenCoon, .pid):
            return PIDParameters(
                kp: t / (k * l) * (4.0 / 3.0 + ratio / 4),
                ti: l * (32 + 6 * ratio) / (13 + 8 * ratio),
                td: 4 * l / (11 + 2 * ratio)
            )
        case (.simc, .pi):
            let closedLoopTime = l
            return PIDParameters(
                kp: t / (k * (closedLoopTime + l)),
                ti: min(t, 4 * (closedLoopTime + l)),
                td: nil
            )
        default:
            return nil
        }
    }
}
