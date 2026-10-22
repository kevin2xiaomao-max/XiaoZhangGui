import SwiftUI

/// V3.8 重建 R2 · Todo 视觉 Tokens（生产）。
///
/// 依据 `02_设计与交互升级说明.md` §正确的视觉 DNA，并与 R1 Home 对齐：
/// - Canvas Light 暖白 / Dark 墨绿黑（复用 `V371.Colors.canvas`）
/// - Accent 低饱和经营绿（与 `V38HomeStyle.businessGreen` 同一色值，单一来源）
/// - Page 16pt，Section 24pt，Group radius 20pt，行高 ≥60pt，触点 ≥44pt
/// - 统计数字 SF Rounded 等宽；不引入第三方字体
enum V38TodoStyle {
    /// 低饱和经营绿（Accent）：与 Home 同一来源，避免色值漂移。
    static var businessGreen: Color { V38HomeStyle.businessGreen }
    /// Hero 深墨绿（与 Home 同一来源，Todo 仅用于进度强调，不铺满屏）。
    static var heroBackground: Color { V38HomeStyle.heroBackground }

    /// Section 标题（与 Home 同规格：20pt bold）。
    static let sectionTitle: Font = V38HomeStyle.sectionTitle
    /// 进度大数字：SF Rounded 等宽。
    static let statNumber: Font = .system(size: 32, weight: .semibold, design: .rounded).monospacedDigit()
    /// 进度标签。
    static let statLabel: Font = .footnote

    /// V38 分组圆角（02 文档：20pt）。
    static let groupRadius: CGFloat = 20
    /// 待办行最小高度（02 文档：行高 ≥60pt）。
    static let rowMinHeight: CGFloat = 68
    /// 复选框命中区（≥44pt）。
    static let toggleHitSize: CGFloat = 44
    /// 行内文字起始偏移（命中区 44 + 间距 12），分割线与之对齐。
    static let dividerLeading: CGFloat = 56
}

/// V3.8 Todo 无障碍标识（V371 既有标识保持不变，此处只补 R2 新增元素）。
enum V38TodoAccessibilityID {
    /// 顶部进度区容器。
    static let progress = "v38.todo.progress"
    /// 失败行内「重试」按钮（与 alert 的 reliability.retry 区分，避免 firstMatch 混淆）。
    static let inlineRetry = "v38.todo.retry"
    /// 失败行内「放弃」按钮。
    static let inlineDismiss = "v38.todo.dismissFailure"
}

/// V3.8 Todo Section 标题行（与 `V38HomeSectionHeader` 同规格，功能域本地化命名）。
struct V38TodoSectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(V38TodoStyle.sectionTitle)
                .foregroundStyle(.primary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

/// 失败抖动（规格 §2：6pt ×2）。
///
/// `animatableData` 在整数位时 sin 归零（静止位），trigger 每 +1 播放一次完整抖动；
/// Reduce Motion 时 travel=0（静态呈现，改由红色圆点 + 行内文案传达失败）。
struct V38ShakeEffect: GeometryEffect {
    var travel: CGFloat = 6
    var shakesPerUnit: CGFloat = 2
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: travel * sin(animatableData * .pi * shakesPerUnit * 2),
                y: 0
            )
        )
    }
}
