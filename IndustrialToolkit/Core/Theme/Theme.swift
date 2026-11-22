import SwiftUI
import UIKit

/// Industrial palette: graphite surfaces, safety-amber accent, status colours tuned
/// for contrast on both sunlit (light) and control-room (dark) screens.
enum Theme {
    static let background = Color(light: 0xF2F3F5, dark: 0x0E1114)
    static let surface = Color(light: 0xFFFFFF, dark: 0x171B20)
    static let surfaceSunken = Color(light: 0xEBEDF0, dark: 0x111418)
    static let border = Color(light: 0xD5DAE1, dark: 0x2A313A)

    static let accent = Color(light: 0xA86400, dark: 0xFFB020)
    static let ok = Color(light: 0x1E7F4A, dark: 0x3CC47C)
    static let warning = Color(light: 0xC2410C, dark: 0xFF8A3D)
    static let fault = Color(light: 0xC62828, dark: 0xFF5A52)
    static let info = Color(light: 0x1F5FBF, dark: 0x5B9BFF)

    static let cornerRadius: CGFloat = 10
    static let fieldCornerRadius: CGFloat = 8
}

extension Font {
    static let readout = Font.system(.title, design: .monospaced, weight: .semibold)
    static let readoutLarge = Font.system(.largeTitle, design: .monospaced, weight: .semibold)
    static let monoBody = Font.system(.body, design: .monospaced)
    static let monoCaption = Font.system(.caption, design: .monospaced)
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
