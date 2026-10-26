import SwiftUI
import UIKit

/// V4.0 Fusion 设计 Token。
/// 来源：design/v40-fusion/01-design-system.md §1/§9 + 04-swiftui-spec.md §2。
/// 落入仓库时：放 DesignSystem/ 下独立文件，逐页替换调用点，并跑全量 CI 验证；
/// 不得全局查找替换 businessGreen / heroGold（见 TOKEN-MAP）。
enum V400Tokens {
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
    private static func hex(_ v: UInt32) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 0xFF) / 255,
                green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    // MARK: - 日历金（定案，仅日历可用）
    /// 今日圆 #D4A017。浅底上必须带 1pt goldRing 环；金上只用 goldInk 文字，禁白字压金。
    static let goldToday = Color(hex: 0xD4A017)
    /// 选中环 #B8860B。
    static let goldRing = Color(hex: 0xB8860B)
    /// 金上唯一合法文字色 #1A1D21。
    static let goldInk = Color(hex: 0x1A1D21)

    // MARK: - 品牌绿（分流使用，禁混用）
    /// 图表 / 选中 / 图形专用 #1FA971。禁大面积、禁正文、禁浅底按钮。
    static let brandGreen = Color(hex: 0x1FA971)
    /// 绿色文本：Light #146B52 / Dark #2FBF71。
    static var greenInk: Color {
        adaptive(light: hex(0x146B52), dark: hex(0x2FBF71))
    }
    /// 主按钮实心底 #146B52（白字 6.45:1），Light/Dark 同值。
    static let primaryButton = Color(hex: 0x146B52)
    /// 大面积绿唯一合法形态：brandGreen 10%（Light）/ 14%（Dark）底 + 绿描边。
    static var greenTint: Color {
        Color(hex: 0x1FA971).opacity(0.10)
    }

    /// 首页 Hero 来自 fusion-kit 双主题表；不是品牌绿铺底。
    static var heroBackground: Color { adaptive(light: hex(0x10382A), dark: hex(0x12352B)) }
    static var heroInk: Color { adaptive(light: hex(0xEAF3EE), dark: hex(0xCBE9DA)) }
    static var warningInk: Color { adaptive(light: hex(0xB25000), dark: hex(0xFFB340)) }
    /// 日历操作文字：规范 §9 的可读金，区别于今日圆填充。
    static var calendarActionInk: Color { adaptive(light: hex(0x8A6400), dark: hex(0xD4A017)) }

    // MARK: - 页面与纸面
    static var pageBackground: Color {
        adaptive(light: hex(0xF3F8F5), dark: hex(0x0B0F0D))
    }
    /// A 质感表面（报表 / 确认卡局部）#FCFBF7。
    static let paper = Color(hex: 0xFCFBF7)
    /// 收据纸面来自设计提交 cde375c 的 fusion-kit.jsx 双主题表。
    /// Dark #131815；固定 #8E8E93 次文本对比度约 5.51:1（旧 elevated 底约 4.27:1）。
    static var paperAdaptive: Color {
        adaptive(light: hex(0xFCFBF7), dark: hex(0x131815))
    }
    static var surface: Color {
        adaptive(light: hex(0xFFFFFF), dark: hex(0x1C1C1E))
    }
    static var surfaceElevated: Color {
        adaptive(light: hex(0xFFFFFF), dark: hex(0x2C2C2E))
    }

    // MARK: - 气泡与语义
    /// 用户聊天气泡 #0A6ED1（白字达标；原 #0A84FF 仅 4.0，不用）。
    static let userBubble = Color(hex: 0x0A6ED1)
    /// 危险文本 #D03028（白底 4.94）。
    static let dangerText = Color(hex: 0xD03028)

    // MARK: - 金额衬线（仅金额 / 日报数值 / 确认卡金额 / 进度头数字）
    /// Georgia / Songti SC + tabular-nums；relativeTo 保证动态字体缩放。
    static func serifAmount(size: CGFloat, relativeTo: Font.TextStyle = .largeTitle) -> Font {
        Font.custom("Georgia", size: size, relativeTo: relativeTo)
            .monospacedDigit()
    }
}
