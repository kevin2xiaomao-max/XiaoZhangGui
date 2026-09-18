import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Widget 2.0「快捷工作台」视图（systemSmall / systemMedium）
//
// Small：问小掌柜 + 语音记录（两个 AppIntent 深链按钮，Small 也能各自响应）
// Medium：今日营业额 + 最重要 2 条事项（待办可勾选）+ 两个快捷入口
//
// 视觉：系统材质底 + .primary/.secondary 语义色 + 少量墨绿，
// 自动适配 Light / Dark / Tinted(accented) / Clear(StandBy 材质) / Dynamic Type。

/// 整体适配性由以下约定保证：
/// - 背景统一 thinMaterial（浅=米白中性、深=暗材质；tinted 由系统单色化；clear 下有材质保证对比）
/// - 文字一律 .primary / .secondary，标题/图标可被系统单色化，不会在 Tinted 下消失
/// - 金额与事项行均 minimumScaleFactor + lineLimit，大字号/窄屏不崩

private let workbenchInk = V21.brandGreen

// MARK: - Small

struct SmallWorkbenchView: View {
    let snapshot: BusinessSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(workbenchInk)
                Text("你的小掌柜")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 8)

            WorkbenchActionButton(
                icon: "sparkles",
                title: "问小掌柜",
                url: XZGWidgetLink.ai,
                emphasized: true
            )

            Spacer(minLength: 8)

            WorkbenchActionButton(
                icon: "mic.fill",
                title: "语音记录",
                url: XZGWidgetLink.voice,
                emphasized: false
            )

            Spacer(minLength: 8)

            Text(verbatim: statusText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var statusText: String {
        guard let s = snapshot else { return "轻点同步今日经营" }
        return WidgetDashboard.statusLine(
            overdueTodos: s.overdueTodoCount,
            todayTodos: s.todayTodoCount,
            deliveries: s.deliveringCustomerCount,
            urgentExpiry: s.urgentExpiryCount
        ) ?? "今天都安排好了"
    }
}

/// Small 两行大按钮（OpenURLIntent 在 iOS18 下由系统执行深链，Small 支持多按钮）
private struct WorkbenchActionButton: View {
    let icon: String
    let title: String
    let url: URL
    let emphasized: Bool

    var body: some View {
        Button(intent: OpenURLIntent(url)) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(
                        emphasized ? workbenchInk.opacity(0.14) : Color.secondary.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .foregroundStyle(emphasized ? workbenchInk : .primary)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Medium

struct MediumWorkbenchView: View {
    let snapshot: BusinessSnapshot?

    private var items: [WidgetFocusItem] {
        snapshot?.focusItems ?? []
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            revenueColumn
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                if items.isEmpty {
                    Spacer(minLength: 0)
                    Text(snapshot == nil ? "打开 App 同步数据" : "现在没有要紧事")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                } else {
                    ForEach(items) { item in
                        FocusRow(item: item)
                        if item.id != items.last?.id {
                            Spacer(minLength: 7)
                        }
                    }
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 6)

                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    WorkbenchPill(icon: "sparkles", title: "问小掌柜", url: XZGWidgetLink.ai)
                    WorkbenchPill(icon: "mic.fill", title: "语音记录", url: XZGWidgetLink.voice)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private var revenueColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("今日营业额")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("¥\(WidgetDashboard.formatRevenue(snapshot?.todayRevenue ?? 0))")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }
}

/// 一条焦点事项：待办圆圈是 AppIntent 按钮；配送/临期仅展示
private struct FocusRow: View {
    let item: WidgetFocusItem

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            leadingGlyph
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let detail = item.detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var leadingGlyph: some View {
        if item.completable {
            Button(intent: CompleteTodoIntent(todoID: item.id)) {
                Image(systemName: item.kind == .todoOverdue ? "exclamationmark.circle" : "circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(item.kind == .todoOverdue ? Color.orange : .secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Image(systemName: item.kind.sfSymbol)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }
}

/// Medium 右下快捷胶囊
private struct WorkbenchPill: View {
    let icon: String
    let title: String
    let url: URL

    var body: some View {
        Button(intent: OpenURLIntent(url)) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous).fill(Color.secondary.opacity(0.14))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
