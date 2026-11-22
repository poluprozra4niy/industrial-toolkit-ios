import Foundation

enum Fmt {
    /// Locale-aware number without grouping; values that would print as "-0" collapse to 0.
    static func number(_ value: Double, fractionDigits: Int) -> String {
        guard value.isFinite else { return "—" }
        let threshold = 0.5 * pow(10, -Double(fractionDigits))
        let displayed = abs(value) < threshold ? 0 : value
        return displayed.formatted(.number.precision(.fractionLength(0...fractionDigits)).grouping(.never))
    }

    static func fixed(_ value: Double, fractionDigits: Int) -> String {
        guard value.isFinite else { return "—" }
        let threshold = 0.5 * pow(10, -Double(fractionDigits))
        let displayed = abs(value) < threshold ? 0 : value
        return displayed.formatted(.number.precision(.fractionLength(fractionDigits)).grouping(.never))
    }

    static func float(_ value: Float) -> String {
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value < 0 ? "−∞" : "+∞" }
        return value.description
    }

    static func double(_ value: Double) -> String {
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value < 0 ? "−∞" : "+∞" }
        return value.description
    }
}

extension BinaryInteger {
    func hexString(digits: Int) -> String {
        let raw = String(self, radix: 16, uppercase: true)
        return String(repeating: "0", count: Swift.max(0, digits - raw.count)) + raw
    }

    func binaryString(digits: Int) -> String {
        let raw = String(self, radix: 2)
        return String(repeating: "0", count: Swift.max(0, digits - raw.count)) + raw
    }
}
