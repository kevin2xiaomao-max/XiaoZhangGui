import SwiftUI

// MARK: - V32 / Theme · 调色板（b28 T23）
//
// 设计依据：spec FR-22.2 / FR-22.5 / FR-22.6 / AC-20
// - BackgroundPalette 含背景层级 + 中性文本 + divider + neutral，每套双模式
// - AccentPalette 含 accent / accentSoft / onAccent，每套双模式
// - Hero / amber / danger / 配送状态色固定不在此处
// - 默认 warmCream + emerald 取值与 b27 V32 色值逐一对齐

/// 背景调色板（可主题化的背景层级 + 中性文本 + divider + neutral）
struct BackgroundPalette: Sendable {
    let pageBG: Color
    let pageBGSecondary: Color
    let card: Color
    let cardElevated: Color
    let cardInset: Color
    let cardOutline: Color
    let divider: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textQuaternary: Color
    let neutral: Color
    let neutralSoft: Color
}

/// Accent 调色板（点缀 / 主按钮 / 选中 / 进度 / 通用图标泡）
struct AccentPalette: Sendable {
    let accent: Color          // 对应 V32.brand 的交互用途
    let accentSoft: Color      // 对应 V32.brandSoft
    let onAccent: Color        // 按钮 / 胶囊上的前景色
}

// MARK: - 默认调色板（等同 b27，light/dark 双值与 V32Color.swift 一致）

extension BackgroundTheme {
    var palette: BackgroundPalette {
        switch self {
        case .warmCream:
            // 等同 b27：暖米浅 + 暖深灰黑深
            return BackgroundPalette(
                pageBG: Color.v32Dynamic(light: 0xF4F1E8, dark: 0x16181A),
                pageBGSecondary: Color.v32Dynamic(light: 0xECE8DB, dark: 0x1D201E),
                card: Color.v32Dynamic(light: 0xFFFFFF, dark: 0x1F2220),
                cardElevated: Color.v32Dynamic(light: 0xFFFFFF, dark: 0x262A27),
                cardInset: Color.v32Dynamic(light: 0xF4F1E8, dark: 0x2A2E2B),
                cardOutline: Color.v32Dynamic(light: 0x232623, dark: 0xFFFFFF, lightAlpha: 0.07, darkAlpha: 0.08),
                divider: Color.v32Dynamic(light: 0x232623, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.08),
                textPrimary: Color.v32Dynamic(light: 0x232623, dark: 0xF2F0E9),
                textSecondary: Color.v32Dynamic(light: 0x60655E, dark: 0xB8BDB4),
                textTertiary: Color.v32Dynamic(light: 0x94988F, dark: 0x898F87),
                textQuaternary: Color.v32Dynamic(light: 0xAFB3AA, dark: 0x6B7169),
                neutral: Color.v32Dynamic(light: 0x8B9088, dark: 0x9AA098),
                neutralSoft: Color.v32Dynamic(light: 0xEEF0EA, dark: 0x2C302D)
            )
        case .pureWhite:
            // 纯净白：浅色更白净，深色维持暖深灰
            return BackgroundPalette(
                pageBG: Color.v32Dynamic(light: 0xFCFCFD, dark: 0x131516),
                pageBGSecondary: Color.v32Dynamic(light: 0xF2F2F5, dark: 0x1A1C1E),
                card: Color.v32Dynamic(light: 0xFFFFFF, dark: 0x1C1E20),
                cardElevated: Color.v32Dynamic(light: 0xFFFFFF, dark: 0x232628),
                cardInset: Color.v32Dynamic(light: 0xF7F7F9, dark: 0x272A2C),
                cardOutline: Color.v32Dynamic(light: 0x1D1D1F, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.10),
                divider: Color.v32Dynamic(light: 0x1D1D1F, dark: 0xFFFFFF, lightAlpha: 0.10, darkAlpha: 0.10),
                textPrimary: Color.v32Dynamic(light: 0x1D1D1F, dark: 0xF5F5F7),
                textSecondary: Color.v32Dynamic(light: 0x5A5A60, dark: 0xC0C0C6),
                textTertiary: Color.v32Dynamic(light: 0x8A8A90, dark: 0x8A8A90),
                textQuaternary: Color.v32Dynamic(light: 0xAEAEB4, dark: 0x68686E),
                neutral: Color.v32Dynamic(light: 0x8E8E93, dark: 0x9A9AA0),
                neutralSoft: Color.v32Dynamic(light: 0xF0F0F2, dark: 0x2A2A2D)
            )
        case .sageGreen:
            // 鼠尾草浅绿：浅色淡鼠尾草，深色暖墨绿灰
            return BackgroundPalette(
                pageBG: Color.v32Dynamic(light: 0xEDEFE7, dark: 0x14181A),
                pageBGSecondary: Color.v32Dynamic(light: 0xE3E6DA, dark: 0x1B201D),
                card: Color.v32Dynamic(light: 0xF7F8F2, dark: 0x1E2320),
                cardElevated: Color.v32Dynamic(light: 0xFBFCF6, dark: 0x252B27),
                cardInset: Color.v32Dynamic(light: 0xECEEE3, dark: 0x293025),
                cardOutline: Color.v32Dynamic(light: 0x2A3328, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.08),
                divider: Color.v32Dynamic(light: 0x2A3328, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.08),
                textPrimary: Color.v32Dynamic(light: 0x232825, dark: 0xECF1EA),
                textSecondary: Color.v32Dynamic(light: 0x5A6359, dark: 0xB5C0B6),
                textTertiary: Color.v32Dynamic(light: 0x8B948A, dark: 0x888F87),
                textQuaternary: Color.v32Dynamic(light: 0xA8B0A6, dark: 0x6A726A),
                neutral: Color.v32Dynamic(light: 0x8A9388, dark: 0x9AA298),
                neutralSoft: Color.v32Dynamic(light: 0xE6E9DC, dark: 0x2A3025)
            )
        case .hazeBlue:
            // 雾霾浅蓝：浅色冷淡蓝灰，深色暖蓝灰
            return BackgroundPalette(
                pageBG: Color.v32Dynamic(light: 0xECF0F3, dark: 0x141719),
                pageBGSecondary: Color.v32Dynamic(light: 0xE0E6EA, dark: 0x1A1E22),
                card: Color.v32Dynamic(light: 0xF8FBFC, dark: 0x1D2226),
                cardElevated: Color.v32Dynamic(light: 0xFBFEFE, dark: 0x242A2F),
                cardInset: Color.v32Dynamic(light: 0xEDF1F4, dark: 0x282F34),
                cardOutline: Color.v32Dynamic(light: 0x1A2A35, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.08),
                divider: Color.v32Dynamic(light: 0x1A2A35, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.08),
                textPrimary: Color.v32Dynamic(light: 0x1F2830, dark: 0xEAF0F4),
                textSecondary: Color.v32Dynamic(light: 0x566270, dark: 0xB0BCC6),
                textTertiary: Color.v32Dynamic(light: 0x83909A, dark: 0x808E98),
                textQuaternary: Color.v32Dynamic(light: 0xA2AFB8, dark: 0x62707A),
                neutral: Color.v32Dynamic(light: 0x88969F, dark: 0x96A4AD),
                neutralSoft: Color.v32Dynamic(light: 0xE2E7EC, dark: 0x262D32)
            )
        case .neutralGray:
            // 中性浅灰：浅色纯灰阶，深色暖中灰
            return BackgroundPalette(
                pageBG: Color.v32Dynamic(light: 0xF1F1F2, dark: 0x151617),
                pageBGSecondary: Color.v32Dynamic(light: 0xE7E7E9, dark: 0x1B1C1E),
                card: Color.v32Dynamic(light: 0xFBFBFC, dark: 0x1E1F21),
                cardElevated: Color.v32Dynamic(light: 0xFFFFFF, dark: 0x252628),
                cardInset: Color.v32Dynamic(light: 0xF2F2F3, dark: 0x292A2C),
                cardOutline: Color.v32Dynamic(light: 0x232325, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.08),
                divider: Color.v32Dynamic(light: 0x232325, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.08),
                textPrimary: Color.v32Dynamic(light: 0x1F2022, dark: 0xF1F1F3),
                textSecondary: Color.v32Dynamic(light: 0x5A5B5E, dark: 0xB8B9BE),
                textTertiary: Color.v32Dynamic(light: 0x8A8B8F, dark: 0x898A8E),
                textQuaternary: Color.v32Dynamic(light: 0xA8A9AD, dark: 0x6A6B6F),
                neutral: Color.v32Dynamic(light: 0x8E8F93, dark: 0x9AA0A4),
                neutralSoft: Color.v32Dynamic(light: 0xECEEED, dark: 0x2A2B2D)
            )
        case .softLilac:
            // 柔和浅紫 / 浅粉：浅色淡紫，深色暖紫灰
            return BackgroundPalette(
                pageBG: Color.v32Dynamic(light: 0xF1ECF3, dark: 0x161418),
                pageBGSecondary: Color.v32Dynamic(light: 0xE7E0EC, dark: 0x1C1A20),
                card: Color.v32Dynamic(light: 0xFBF8FC, dark: 0x201D24),
                cardElevated: Color.v32Dynamic(light: 0xFEFBFF, dark: 0x272329),
                cardInset: Color.v32Dynamic(light: 0xF3EEF4, dark: 0x2B2630),
                cardOutline: Color.v32Dynamic(light: 0x2E2535, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.08),
                divider: Color.v32Dynamic(light: 0x2E2535, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.08),
                textPrimary: Color.v32Dynamic(light: 0x251F2C, dark: 0xF1ECF4),
                textSecondary: Color.v32Dynamic(light: 0x5F5570, dark: 0xBAB0C6),
                textTertiary: Color.v32Dynamic(light: 0x8E849A, dark: 0x8A8096),
                textQuaternary: Color.v32Dynamic(light: 0xAB9FB6, dark: 0x6A5F76),
                neutral: Color.v32Dynamic(light: 0x9088A0, dark: 0x9C92AC),
                neutralSoft: Color.v32Dynamic(light: 0xE5DEEC, dark: 0x2A2532)
            )
        }
    }
}

extension AccentTheme {
    var palette: AccentPalette {
        switch self {
        case .emerald:
            // 默认墨绿：等同 b27 V32.brand
            return AccentPalette(
                accent: Color.v32Dynamic(light: 0x2F6B4F, dark: 0x35D083),
                accentSoft: Color.v32Dynamic(light: 0xE2EFE7, dark: 0x153225),
                onAccent: Color.v32Dynamic(light: 0xFFFFFF, dark: 0x0F1F18)
            )
        case .blue:
            return AccentPalette(
                accent: Color.v32Dynamic(light: 0x3A6FB8, dark: 0x6CA6F0),
                accentSoft: Color.v32Dynamic(light: 0xE2EBF6, dark: 0x152638),
                onAccent: Color.v32Dynamic(light: 0xFFFFFF, dark: 0x0A1A2E)
            )
        case .purple:
            return AccentPalette(
                accent: Color.v32Dynamic(light: 0x7C5BC9, dark: 0xB08CE0),
                accentSoft: Color.v32Dynamic(light: 0xECDEF6, dark: 0x251938),
                onAccent: Color.v32Dynamic(light: 0xFFFFFF, dark: 0x1A0E2A)
            )
        case .coral:
            return AccentPalette(
                accent: Color.v32Dynamic(light: 0xE0654A, dark: 0xFF8466),
                accentSoft: Color.v32Dynamic(light: 0xFBE4DC, dark: 0x381F18),
                onAccent: Color.v32Dynamic(light: 0xFFFFFF, dark: 0x2A0E06)
            )
        case .graphite:
            return AccentPalette(
                accent: Color.v32Dynamic(light: 0x3A3F45, dark: 0xC4C9CF),
                accentSoft: Color.v32Dynamic(light: 0xE3E5E8, dark: 0x25282C),
                onAccent: Color.v32Dynamic(light: 0xFFFFFF, dark: 0x101316)
            )
        }
    }
}
