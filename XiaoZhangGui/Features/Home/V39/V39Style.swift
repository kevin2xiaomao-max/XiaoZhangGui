import SwiftUI
import UIKit

// MARK: - V3.9 · 高级质感设计令牌（Premium / 玻璃 + 渐变 + 大数字）
//
// 方向定稿（2026-10-24 掌柜确认）：现状"太素太单调、信息太少、配色不喜欢、首页空"。
// V3.9 首页走「高级质感风」——高端金融 App 的观感：
// - 夜蓝渐变画布 + 香槟金强调（替代 V3.8 暖白/经营绿的单色系）
// - 玻璃卡片浮于渐变之上（复用 V38HomeGlassSurface 三档降级：RT 实色 / 旧系统材质）
// - 数字排版全面 Rounded + 等宽（掌柜 App 的门面是数字）
// - 信息密度补齐：目标环 / 统计 chips / 近7日趋势 / 收入来源 一屏可见
//
// 约束（延续 V3.8 红线）：
// - 动态字体：文本用语义样式，展示型大数字由调用点 @ScaledMetric 随动
// - Reduce Motion / Reduce Transparency：玻璃走既有三档门控，动效只走 V38MotionTokens
// - 无障碍标识符契约不变（v38.home.* / home.* 全保留）

enum V39Style {
    // MARK: 配色（跨明暗单源：UIColor 动态提供者）

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// 香槟金：Dark #E7C983（暖金）/ Light #A97E2F（深金，保证对比度）。
    static let gold = adaptive(
        light: UIColor(red: 0.663, green: 0.494, blue: 0.184, alpha: 1),
        dark: UIColor(red: 0.906, green: 0.788, blue: 0.514, alpha: 1)
    )

    /// 夜蓝（Light 模式下作为主要文字/柱形色）。
    static let navy = adaptive(
        light: UIColor(red: 0.11, green: 0.14, blue: 0.25, alpha: 1),
        dark: UIColor(red: 0.82, green: 0.85, blue: 0.94, alpha: 1)
    )

    /// 画布渐变（页面背景）：Dark 夜蓝深邃 / Light 冰蓝珍珠。
    static var canvasGradient: LinearGradient {
        let dark = Color(red: 0.09, green: 0.11, blue: 0.20)
        let darkDeep = Color(red: 0.043, green: 0.059, blue: 0.122)
        let light = Color(red: 0.943, green: 0.955, blue: 0.976)
        let lightDeep = Color(red: 0.876, green: 0.897, blue: 0.933)
        return LinearGradient(
            colors: [dark, darkDeep],
            startPoint: .top, endPoint: .bottom
        )
    }

    /// Light 画布渐变（与 canvasGradient 按环境选择，见 V39Canvas）。
    static var canvasGradientLight: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.943, green: 0.955, blue: 0.976),
                Color(red: 0.876, green: 0.897, blue: 0.933),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    /// Hero 主卡渐变（深空蓝，明暗通用，数字/金字在其上高对比）。
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.157, green: 0.184, blue: 0.325),
                Color(red: 0.078, green: 0.098, blue: 0.219),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    /// 涨（金）/ 跌（沿用既有告警红语义）。
    static var changeUp: Color { gold }
    static var changeDown: Color { V371.Colors.red }

    /// 来源条配色：门店 = 夜蓝、美团 = 金、其他 = 灰。
    static var sourceStore: Color { navy }
    static var sourceMeituan: Color { gold }
    static var sourceOther: Color { V371.Colors.gray }

    /// 进度比例统一夹取 [0,1]（纯函数：Hero 目标环与单测共用同一口径）。
    static func clampedProgress(numerator: Double, denominator: Double) -> Double {
        guard denominator > 0 else { return 0 }
        return min(max(numerator / denominator, 0), 1)
    }
}

// MARK: - 页面画布（替换首页的 v371Canvas）

/// V3.9 首页画布：按明暗铺夜蓝/冰蓝渐变（等效 v371Canvas 的忽略安全区铺底）。
struct V39Canvas: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background(
            Group {
                if colorScheme == .dark {
                    V39Style.canvasGradient
                } else {
                    V39Style.canvasGradientLight
                }
            }
            .ignoresSafeArea()
        )
    }
}

extension View {
    func v39Canvas() -> some View { modifier(V39Canvas()) }
}
