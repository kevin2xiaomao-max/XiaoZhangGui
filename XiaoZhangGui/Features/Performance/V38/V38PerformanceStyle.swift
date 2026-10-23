import SwiftUI

/// V3.8 重建 · Performance 经营页视觉 Tokens（生产）。
///
/// 依据 `02_设计与交互升级说明.md` §正确的视觉 DNA，并与 R1 Home 的
/// `V38HomeStyle` 保持统一：
/// - Canvas Light 暖白 / Dark 墨绿黑（复用 V371.Colors.canvas）
/// - Accent 低饱和经营绿（复用 V38HomeStyle.businessGreen，不另建同名 token）
/// - Page 16pt，Section 24pt，Group radius 20pt，行高 ≥60pt，触点 ≥44pt
/// - 本页最重点金额（本月营业额）54pt SF Rounded 等宽；不引入第三方字体
enum V38PerformanceStyle {
    /// 低饱和经营绿（与 Home 统一，单一来源 V38HomeStyle）。
    static var accent: Color { V38HomeStyle.businessGreen }

    /// 本月营业额：54pt SF Rounded 等宽（页面最重点金额）。
    static let heroAmount: Font = .system(size: 54, weight: .semibold, design: .rounded).monospacedDigit()
    /// 分类汇总金额：30pt SF Rounded 等宽。
    static let summaryAmount: Font = .system(size: 30, weight: .semibold, design: .rounded).monospacedDigit()
    /// 次级金额（今日 / 期间合计）：20pt SF Rounded 等宽。
    static let secondaryAmount: Font = .system(size: 20, weight: .semibold, design: .rounded).monospacedDigit()
    /// Hero 上方小标签（"本月营业额"）。
    static let heroLabel: Font = .system(size: 15, weight: .semibold)
    /// Chip 文案。
    static let chipLabel: Font = .system(size: 14, weight: .semibold)
    /// 图表选中读数行文案（V3.8.1 P1-7）。
    static let readoutLabel: Font = .system(size: 13, weight: .semibold)
}
