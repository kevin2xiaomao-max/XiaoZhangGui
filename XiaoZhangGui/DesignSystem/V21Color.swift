import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    static func v21Dynamic(light: UInt32, dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1) -> Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(hex: dark, alpha: darkAlpha)
            } else {
                return UIColor(hex: light, alpha: lightAlpha)
            }
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

enum V21 {
    static let brandGreen = Color(hex: 0x1FA971)
    static let brandGreenSoft = Color(hex: 0x1FA971)
    static let brandGreenDeep = Color(hex: 0x168B68)
    static let warning = Color(hex: 0xFF9F0A)
    static let danger = Color(hex: 0xE5484D)
    static let info = Color(hex: 0x0A84FF)

    static var brandGreenGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x2FBF71), Color(hex: 0x168B68)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let background = Color.v21Dynamic(light: 0xF3F8F5, dark: 0x0B0F0D)
    static let backgroundSecondary = Color.v21Dynamic(light: 0xEAF3EE, dark: 0x101614)

    static let surfacePrimary = Color.v21Dynamic(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let surfaceGlass = Color.v21Dynamic(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let surfaceElevated = Color.v21Dynamic(light: 0xFFFFFF, dark: 0x2C2C2E)

    static let textPrimary = Color.v21Dynamic(light: 0x1A1D21, dark: 0xF5F5F7)
    static let textSecondary = Color.v21Dynamic(light: 0x3A3F47, dark: 0xC7C7CC)
    static let textTertiary = Color.v21Dynamic(light: 0x6E7380, dark: 0x8E8E93)
    static let textQuaternary = Color.v21Dynamic(light: 0xB0B4BC, dark: 0x636366)

    static let divider = Color.v21Dynamic(light: 0x1E2328, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.08)
    static let dividerStrong = Color.v21Dynamic(light: 0x1E2328, dark: 0xFFFFFF, lightAlpha: 0.12, darkAlpha: 0.12)
    static let dividerHighlight = Color.v21Dynamic(light: 0x1E2328, dark: 0xFFFFFF, lightAlpha: 0.16, darkAlpha: 0.16)
    static let timeline = Color.v21Dynamic(light: 0x1E2328, dark: 0xFFFFFF, lightAlpha: 0.16, darkAlpha: 0.16)
    static let timelineDotBorder = Color.v21Dynamic(light: 0x1E2328, dark: 0xFFFFFF, lightAlpha: 0.25, darkAlpha: 0.24)

    static let groupTitle = Color.v21Dynamic(light: 0x6E7380, dark: 0x8E8E93)
    static let tabInactive = Color.v21Dynamic(light: 0x7C838D, dark: 0x8E8E93)
    static let glassHighlight = Color.v21Dynamic(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.8, darkAlpha: 0.06)
}

struct AppThemePalette {
    let name: String
    let accent: Color
    let accentSecondary: Color
    let heroGradient: LinearGradient
    let selectedBackground: Color

    static let mint = AppThemePalette(
        name: "Mint",
        accent: V21.brandGreen,
        accentSecondary: V21.brandGreenDeep,
        heroGradient: V21.brandGreenGradient,
        selectedBackground: V21.brandGreen.opacity(0.12)
    )
}

enum AppTheme {
    static let current = AppThemePalette.mint

    static func palette(named name: String) -> AppThemePalette {
        .mint
    }

    static let all: [AppThemePalette] = [.mint]
}
