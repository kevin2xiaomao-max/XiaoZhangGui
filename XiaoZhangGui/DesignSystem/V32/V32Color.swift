import SwiftUI
import UIKit

// MARK: - V32 / BusinessDesignSystem — 颜色 Token
// 暖色极简 · 墨绿主视觉 · 品牌绿强调 · 琥珀警示
//
// b28 T24：将"可主题化"的语义 token 改为 @MainActor 计算属性，派生自
// ThemeStore.shared.backgroundPalette / accentPalette，主题切换即时生效。
// "固定不随主题"的色（Hero 深墨绿体系 / 临期琥珀 / 危险红 / 信息提示 /
// Hero 内的描边与文本）保留 static let，避免破坏 spec 的语义色锁定约束。

extension Color {
    static func v32Dynamic(light: UInt32, dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1) -> Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(hex: dark, alpha: CGFloat(darkAlpha))
            } else {
                return UIColor(hex: light, alpha: CGFloat(lightAlpha))
            }
        })
    }
}

enum V32 {
    // MARK: 背景层级（可主题化）
    /// 页面暖灰白底（Light）/ 暖深灰黑（Dark）— 接入 ThemeStore.backgroundPalette
    @MainActor static var pageBG: Color { ThemeStore.shared.backgroundPalette.pageBG }
    /// 页面次级底（分组嵌层、周条底）— 接入 ThemeStore.backgroundPalette
    @MainActor static var pageBGSecondary: Color { ThemeStore.shared.backgroundPalette.pageBGSecondary }

    /// 普通卡片 — 接入 ThemeStore.backgroundPalette
    @MainActor static var card: Color { ThemeStore.shared.backgroundPalette.card }
    /// 抬高卡片（Sheet、浮层）— 接入 ThemeStore.backgroundPalette
    @MainActor static var cardElevated: Color { ThemeStore.shared.backgroundPalette.cardElevated }
    /// 卡片内浅嵌区（备注块、指标槽）— 接入 ThemeStore.backgroundPalette
    @MainActor static var cardInset: Color { ThemeStore.shared.backgroundPalette.cardInset }

    // MARK: 主视觉（Hero 固定不随主题）
    /// 深墨绿 hero 卡底
    static let hero = Color.v32Dynamic(light: 0x1F2B24, dark: 0x1B2A22)
    /// hero 卡上的柔和光斑（渐变端色）
    static let heroGlow = Color.v32Dynamic(light: 0x2C3E33, dark: 0x22352A)

    // MARK: Accent（可主题化，对应 b27 brand / brandSoft）
    /// 品牌绿 / Accent：浅色沉稳墨绿 / 深色提亮 — 接入 ThemeStore.accentPalette
    @MainActor static var brand: Color { ThemeStore.shared.accentPalette.accent }
    /// 深墨绿底（hero）上的亮绿强调（Hero 内固定，不随 Accent 变）
    static let brandOnHero = Color.v32Dynamic(light: 0x4FBF86, dark: 0x35D083)
    /// 品牌绿浅底（图标泡、选中底）— 接入 ThemeStore.accentPalette
    @MainActor static var brandSoft: Color { ThemeStore.shared.accentPalette.accentSoft }
    /// hero 内的品牌绿浅底（Hero 内固定，不随 Accent 变）
    static let brandSoftOnHero = Color.v32Dynamic(light: 0x2A3D32, dark: 0x153225)

    // MARK: 功能色（语义固定不随主题）
    /// 临期琥珀
    static let amber = Color.v32Dynamic(light: 0xC08A2E, dark: 0xF2A93B)
    /// 琥珀浅底
    static let amberSoft = Color.v32Dynamic(light: 0xF7EDD9, dark: 0x382C17)
    /// hero 上的琥珀
    static let amberOnHero = Color.v32Dynamic(light: 0xF0B04C, dark: 0xF2A93B)

    static let danger = Color.v32Dynamic(light: 0xC9483E, dark: 0xFF6359)
    static let dangerSoft = Color.v32Dynamic(light: 0xF8E5E1, dark: 0x3A201D)
    static let info = Color.v32Dynamic(light: 0x4A79A8, dark: 0x6AA9E0)
    static let infoSoft = Color.v32Dynamic(light: 0xE6EEF6, dark: 0x182A3A)

    // MARK: 中性（可主题化）
    /// 中性灰（待处理、已完成弱化）— 接入 ThemeStore.backgroundPalette
    @MainActor static var neutral: Color { ThemeStore.shared.backgroundPalette.neutral }
    @MainActor static var neutralSoft: Color { ThemeStore.shared.backgroundPalette.neutralSoft }

    // MARK: 文本（可主题化）
    @MainActor static var textPrimary: Color { ThemeStore.shared.backgroundPalette.textPrimary }
    @MainActor static var textSecondary: Color { ThemeStore.shared.backgroundPalette.textSecondary }
    @MainActor static var textTertiary: Color { ThemeStore.shared.backgroundPalette.textTertiary }
    @MainActor static var textQuaternary: Color { ThemeStore.shared.backgroundPalette.textQuaternary }

    // MARK: Hero 内文本（固定不随主题）
    /// hero 深底上的主文本
    static let textOnHero = Color.v32Dynamic(light: 0xFFFFFF, dark: 0xEDF3EE)
    /// hero 深底上的次级文本
    static let textOnHeroSecondary = Color.v32Dynamic(light: 0xFFFFFF, dark: 0xB5C2B8, lightAlpha: 0.66, darkAlpha: 1)

    // MARK: 描边 / 分割
    /// 卡片细描边（可主题化）— 接入 ThemeStore.backgroundPalette
    @MainActor static var cardOutline: Color { ThemeStore.shared.backgroundPalette.cardOutline }
    @MainActor static var divider: Color { ThemeStore.shared.backgroundPalette.divider }
    /// hero 内分割线（固定不随主题）
    static let dividerOnHero = Color.v32Dynamic(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.14, darkAlpha: 0.14)
}
