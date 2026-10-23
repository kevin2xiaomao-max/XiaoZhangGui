import SwiftUI
import UIKit

// MARK: - V3.9 · 高级质感调色板（DesignSystem 层,全 App 单源）
//
// 用户定稿方向（2026-10-24）：夜蓝渐变 + 香槟金,替代 V3.8 默认暖白/经营绿。
// 层级约定:本文件只放颜色与渐变(DesignSystem 内部零 Feature 依赖);
// Home 侧 V39Style 与 v371Canvas 升级都从这里取值。
//
// 主题系统兼容(红线:不删除 V3.7.1 稳定能力):
// - 用户开了壁纸 → 壁纸原样生效(V371CanvasModifier 分支不变)
// - 用户选了非默认背景主题(纯净白/鼠尾草/雾霾蓝/中性灰/柔紫) → 原样生效
// - 仅「默认暖米」升级为 V3.9 渐变画布

enum V39Palette {
    // MARK: 单源自适应色(UIColor 动态提供者,明暗一套值)

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// 香槟金:Dark 暖金 #E7C983 / Light 深金 #A97E2F(对比度达标)。
    /// 语义:金额/目标/上涨/「钱」相关强调。状态色(成功绿/告警橙/错误红)不归它管。
    static let gold = adaptive(
        light: UIColor(red: 0.663, green: 0.494, blue: 0.184, alpha: 1),
        dark: UIColor(red: 0.906, green: 0.788, blue: 0.514, alpha: 1)
    )

    /// 夜蓝:Light 下为深蓝文字/柱色,Dark 下为浅蓝文字/柱色(同一语义双值)。
    static let navy = adaptive(
        light: UIColor(red: 0.11, green: 0.14, blue: 0.25, alpha: 1),
        dark: UIColor(red: 0.82, green: 0.85, blue: 0.94, alpha: 1)
    )

    // MARK: 渐变

    /// Dark 画布:夜蓝深邃。
    static var canvasGradientDark: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.11, blue: 0.20),
                Color(red: 0.043, green: 0.059, blue: 0.122),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    /// Light 画布:冰蓝珍珠。
    static var canvasGradientLight: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.943, green: 0.955, blue: 0.976),
                Color(red: 0.876, green: 0.897, blue: 0.933),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    /// Hero 主卡渐变(深空蓝,明暗通用)。
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.157, green: 0.184, blue: 0.325),
                Color(red: 0.078, green: 0.098, blue: 0.219),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    /// Hero 卡右上金色柔光(叠加层)。
    static var heroGlow: LinearGradient {
        LinearGradient(
            colors: [gold.opacity(0.22), .clear],
            startPoint: .topTrailing, endPoint: .center
        )
    }

    /// Hero 卡金色包边。
    static let heroStroke = gold.opacity(0.35)

    /// SectionHeader 金色小竖条(全 App 统一的「高级感签名」)。
    static let headerTick = gold.opacity(0.85)
}
