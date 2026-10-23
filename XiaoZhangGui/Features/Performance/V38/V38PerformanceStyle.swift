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

    /// 本月营业额：54pt SF Rounded 等宽（页面最重点金额；展示型，保持固定，
    /// V3.8 PR-D C3 后续可用 @ScaledMetric 随动——本文件与 PR-B 改动文件解耦考虑暂不动调用点）。
    static let heroAmount: Font = .system(size: 54, weight: .semibold, design: .rounded).monospacedDigit()
    /// 分类汇总金额：30pt SF Rounded 等宽（展示型）。
    static let summaryAmount: Font = .system(size: 30, weight: .semibold, design: .rounded).monospacedDigit()
    /// 次级金额（今日 / 期间合计）：20pt SF Rounded 等宽（展示型）。
    static let secondaryAmount: Font = .system(size: 20, weight: .semibold, design: .rounded).monospacedDigit()
    /// Hero 上方小标签（"本月营业额"）。V3.8 PR-D C3：15 → subheadline 语义缩放。
    static let heroLabel: Font = .subheadline.weight(.semibold)
    /// Chip 文案。V3.8 PR-D C3：14 → subheadline（默认 15pt，+1pt；同组 chip 同步缩放，
    /// 「chip 等高」UI 测试口径不受影响）。
    static let chipLabel: Font = .subheadline.weight(.semibold)
    /// 图表选中读数行文案（V3.8.1 P1-7）。保持固定：读数行有固定 18pt 高度防布局跳动
    /// （V38TrendBarChart，语义缩放在特大字号会截断；随动改造需连读数行一起，见交接说明）。
    static let readoutLabel: Font = .system(size: 13, weight: .semibold)
}
