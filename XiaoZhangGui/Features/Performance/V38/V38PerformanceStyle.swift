import SwiftUI

/// V4.0 Fusion 经营页视觉；类型名保留以兼容既有调用与图表。
enum V38PerformanceStyle {
    /// 低饱和经营绿（与 Home 统一，单一来源 V38HomeStyle）。
    static var accent: Color { V400Tokens.brandGreen }

    /// 本月营业额：54pt 衬线 等宽（页面最重点金额；展示型，保持固定，
    /// V3.8 PR-D C3 后续可用 @ScaledMetric 随动——本文件与 PR-B 改动文件解耦考虑暂不动调用点）。
    static let heroAmount: Font = V400Tokens.serifAmount(size: 54, relativeTo: .largeTitle).weight(.semibold)
    /// 分类汇总金额：30pt 衬线 等宽（展示型）。
    static let summaryAmount: Font = V400Tokens.serifAmount(size: 30, relativeTo: .title).weight(.semibold)
    /// 次级金额（今日 / 期间合计）：20pt 衬线 等宽（展示型）。
    static let secondaryAmount: Font = V400Tokens.serifAmount(size: 20, relativeTo: .title3).weight(.semibold)
    /// Hero 上方小标签（"本月营业额"）。V3.8 PR-D C3：15 → subheadline 语义缩放。
    static let heroLabel: Font = .subheadline.weight(.semibold)
    /// Chip 文案。V3.8 PR-D C3：14 → subheadline（默认 15pt，+1pt；同组 chip 同步缩放，
    /// 「chip 等高」UI 测试口径不受影响）。
    static let chipLabel: Font = .subheadline.weight(.semibold)
    /// 图表选中读数行文案（V3.8.1 P1-7）。保持固定：读数行有固定 18pt 高度防布局跳动
    /// （V38TrendBarChart，语义缩放在特大字号会截断；随动改造需连读数行一起，见交接说明）。
    static let readoutLabel: Font = .system(size: 13, weight: .semibold)
}
