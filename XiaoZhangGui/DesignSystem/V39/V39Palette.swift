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

    // MARK: V3.9.1 P0-2 · 深色卡面固定色(不随系统明暗漂移)
    //
    // 问题:月报卡/经营 Hero 本就是固定深色渐变,却用了 adaptive 的 gold:
    // Light 下金字偏深、Dark 下偏亮,分享图随系统模式导出两份不同配色,
    // 且金底白字分享按钮对比度仅约 1.6:1(WCAG AA 失败)。
    // 修复只动深色卡面:固定香槟金 + 深色墨字,用户自选主题色不受影响。

    /// 固定香槟金 #E7C983:深色卡面上的金字/金条/金底,深浅系统导出同一份。
    /// 在深蓝卡面(#14202E 附近)上对比度约 9:1,远超 WCAG AA 4.5:1。
    static let heroGold = Color(red: 0.906, green: 0.788, blue: 0.514)

    /// 金底上的深色墨字 #16233C:在 #E7C983 金底上对比度约 9:1(WCAG AA 通过)。
    static let heroInk = Color(red: 0.086, green: 0.137, blue: 0.235)

    /// 月报来源固定三色(深色卡面可辨):门店浅蓝 / 美团香槟金 / 其他浅灰。
    static let sourceStoreFixed = Color(red: 0.561, green: 0.659, blue: 0.847)
    static let sourceOtherFixed = Color(red: 0.722, green: 0.745, blue: 0.792)

    // MARK: WCAG 对比度纯函数(供单测锁定 P0-2,颜色值与上方常量一一对应)

    /// sRGB 通道线性化(WCAG 2.x 公式)。
    private static func linearized(_ c: Double) -> Double {
        c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// 两 sRGB 颜色的 WCAG 对比度(1–21);正文/重要按钮须 ≥ 4.5:1(AA)。
    static func wcagContrast(
        _ a: (r: Double, g: Double, b: Double),
        _ b: (r: Double, g: Double, b: Double)
    ) -> Double {
        let lum: ((r: Double, g: Double, b: Double)) -> Double = {
            0.2126 * linearized($0.r) + 0.7152 * linearized($0.g) + 0.0722 * linearized($0.b)
        }
        let l1 = lum(a), l2 = lum(b)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

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
