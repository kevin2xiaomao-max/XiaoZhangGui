import SwiftUI
import UIKit

// MARK: - V32 / BusinessDesignSystem — 颜色 Token
// 暖色极简 · 墨绿主视觉 · 品牌绿强调 · 琥珀警示
// 每个语义色均提供 light / dark 双值，深色为独立暖调深灰方案，非简单反色。

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
    // MARK: 背景层级
    /// 页面暖灰白底（Light）/ 暖深灰黑（Dark）
    static let pageBG = Color.v32Dynamic(light: 0xF4F1E8, dark: 0x16181A)
    /// 页面次级底（分组嵌层、周条底）
    static let pageBGSecondary = Color.v32Dynamic(light: 0xECE8DB, dark: 0x1D201E)

    /// 普通卡片
    static let card = Color.v32Dynamic(light: 0xFFFFFF, dark: 0x1F2220)
    /// 抬高卡片（Sheet、浮层）
    static let cardElevated = Color.v32Dynamic(light: 0xFFFFFF, dark: 0x262A27)
    /// 卡片内浅嵌区（备注块、指标槽）
    static let cardInset = Color.v32Dynamic(light: 0xF4F1E8, dark: 0x2A2E2B)

    // MARK: 主视觉
    /// 深墨绿 hero 卡底
    static let hero = Color.v32Dynamic(light: 0x1F2B24, dark: 0x1B2A22)
    /// hero 卡上的柔和光斑（渐变端色）
    static let heroGlow = Color.v32Dynamic(light: 0x2C3E33, dark: 0x22352A)

    /// 品牌绿：浅色沉稳墨绿 / 深色提亮
    static let brand = Color.v32Dynamic(light: 0x2F6B4F, dark: 0x35D083)
    /// 深墨绿底（hero）上的亮绿强调
    static let brandOnHero = Color.v32Dynamic(light: 0x4FBF86, dark: 0x35D083)
    /// 品牌绿浅底（图标泡、选中底）
    static let brandSoft = Color.v32Dynamic(light: 0xE2EFE7, dark: 0x153225)
    /// hero 内的品牌绿浅底
    static let brandSoftOnHero = Color.v32Dynamic(light: 0x2A3D32, dark: 0x153225)

    // MARK: 功能色
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

    /// 中性灰（待处理、已完成弱化）
    static let neutral = Color.v32Dynamic(light: 0x8B9088, dark: 0x9AA098)
    static let neutralSoft = Color.v32Dynamic(light: 0xEEF0EA, dark: 0x2C302D)

    // MARK: 文本
    static let textPrimary = Color.v32Dynamic(light: 0x232623, dark: 0xF2F0E9)
    static let textSecondary = Color.v32Dynamic(light: 0x60655E, dark: 0xB8BDB4)
    static let textTertiary = Color.v32Dynamic(light: 0x94988F, dark: 0x898F87)

    /// hero 深底上的主文本
    static let textOnHero = Color.v32Dynamic(light: 0xFFFFFF, dark: 0xEDF3EE)
    /// hero 深底上的次级文本
    static let textOnHeroSecondary = Color.v32Dynamic(light: 0xFFFFFF, dark: 0xB5C2B8, lightAlpha: 0.66, darkAlpha: 1)

    // MARK: 描边 / 分割
    /// 卡片细描边
    static let cardOutline = Color.v32Dynamic(light: 0x232623, dark: 0xFFFFFF, lightAlpha: 0.07, darkAlpha: 0.08)
    static let divider = Color.v32Dynamic(light: 0x232623, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.08)
    static let dividerOnHero = Color.v32Dynamic(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.14, darkAlpha: 0.14)
}
