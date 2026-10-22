import SwiftUI

/// V3.8 重建 R3 · 日历视觉 Tokens（生产）。
///
/// 依据 `02_设计与交互升级说明.md` §正确的视觉 DNA，并与 R1 Home 保持统一：
/// - Accent 低饱和经营绿直接复用 `V38HomeStyle.businessGreen`（不另建同名 token）
/// - Canvas / 分组面继续使用 V371 语义色
/// - 日期格：大日期数字、选中环克制清晰、今日实心圆
enum V38ScheduleStyle {
    /// 低饱和经营绿（与 Home 同一 Accent）。
    static var accent: Color { V38HomeStyle.businessGreen }

    /// 日期格统一行高（月/周密度共用；锚点不变量的几何基础）。
    static let cellHeight: CGFloat = 48
    /// 日期数字字号（Editorial 大日期数字，替代 V3.7.1 的 rowSubtitle 小字）。
    static let dayNumberFont: Font = .system(size: 17, weight: .medium, design: .default)
    /// 选中/今日的日期数字字号（同号加粗，避免字宽变化引起格内抖动）。
    static let dayNumberFontEmphasized: Font = .system(size: 17, weight: .semibold, design: .default)

    /// 选中环动画：expand 意图无过冲变体（Spec §3：damping 1.0）。
    /// Reduce Motion 时为 nil（直接呈现终态）。
    static func selectionAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 1.0)
    }
}
