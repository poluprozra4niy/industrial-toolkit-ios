import Foundation

/// Field input arrives as "12,5", "1 000.5", "−3" (Unicode minus from pasted docs)
/// or "1e-6" regardless of device locale; engineers mix notations constantly.
enum NumberParser {
    static func parse(_ text: String, allowNonFinite: Bool = false) -> Double? {
        let normalized = text
            .replacingOccurrences(of: "\u{2212}", with: "-")
            .replacingOccurrences(of: ",", with: ".")
            .filter { !$0.isWhitespace }
        guard !normalized.isEmpty, let value = Double(normalized) else { return nil }
        return allowNonFinite || value.isFinite ? value : nil
    }
}
