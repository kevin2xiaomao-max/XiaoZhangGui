import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Live Activity：今日经营实况
// 锁屏卡片 + 灵动岛（compact / minimal / expanded）
// 设计参考：Flighty（强数字 + 状态着色）、Citymapper（紧凑态单指标）、
// Things 3（空状态）、Apple WWDC23（品牌感带入灵动岛）

struct BusinessLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusinessActivityAttributes.self) { context in
            // 锁屏卡片
            LockScreenLiveActivityView(state: context.state)
                .activityBackgroundTint(BusinessLiveStyle.deepBackground)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandMetric(
                        icon: "checkmark.circle.fill",
                        iconTint: BusinessLiveStyle.green,
                        label: "待办",
                        value: "\(BusinessLiveStyle.todoCount(context.state)) 件",
                        alignment: .leading
                    )
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(BusinessLiveStyle.green, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text("今日经营")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 3) {
                        IslandMetric(
                            icon: "person.2.fill",
                            iconTint: .white.opacity(0.75),
                            label: "配送中",
                            value: "\(context.state.deliveringCustomerCount) 单",
                            alignment: .trailing
                        )
                        if context.state.urgentExpiryCount > 0 {
                            Label {
                                Text("临期 \(context.state.urgentExpiryCount)")
                                    .font(.system(size: 10, weight: .semibold))
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                            }
                            .foregroundStyle(BusinessLiveStyle.amber)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        if let todo = context.state.nextTodoTitle {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.badge.checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(BusinessLiveStyle.green)
                                Text(verbatim: "下一件：\(todo)\(BusinessLiveStyle.timeSuffix(context.state.nextTodoTime))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            Text("今天暂无待办")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BusinessLiveStyle.green)
            } compactTrailing: {
                CompactTrailing(state: context.state)
            } minimal: {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BusinessLiveStyle.green)
            }
            .keylineTint(BusinessLiveStyle.green.opacity(0.6))
        }
    }
}

// MARK: - 紧凑态尾部（按 临期 > 配送 > 待办 优先级显示单一指标）

private struct CompactTrailing: View {
    let state: BusinessActivityAttributes.ContentState

    var body: some View {
        if state.urgentExpiryCount > 0 {
            HStack(spacing: 2) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8, weight: .semibold))
                Text(verbatim: "\(state.urgentExpiryCount)")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(BusinessLiveStyle.amber)
        } else if state.deliveringCustomerCount > 0 {
            HStack(spacing: 2) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 9, weight: .semibold))
                Text(verbatim: "\(state.deliveringCustomerCount)")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(BusinessLiveStyle.green)
        } else {
            Text(verbatim: "\(BusinessLiveStyle.todoCount(state))")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - 灵动岛展开指标块

private struct IslandMetric: View {
    let icon: String
    let iconTint: Color
    let label: String
    let value: String
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Label {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            } icon: {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(iconTint)
            }
            Text(verbatim: value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

// MARK: - 锁屏卡片

private struct LockScreenLiveActivityView: View {
    let state: BusinessActivityAttributes.ContentState

    private var todoCount: Int { BusinessLiveStyle.todoCount(state) }

    var body: some View {
        ZStack {
            // 品牌深绿渐变 + 右上角微光
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.12, blue: 0.09),
                    Color(red: 0.02, green: 0.04, blue: 0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [BusinessLiveStyle.green.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 220
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                headerRow
                nextFocusCard
                metricStrip
            }
            .padding(14)
        }
    }

    // MARK: 头部：品牌砖 + 标题 + 更新时间

    private var headerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "storefront.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(
                        colors: [BusinessLiveStyle.green, Color(red: 0x12/255, green: 0xA0/255, blue: 0x58/255)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("今日经营")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(state.updatedAt, style: .time)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: 焦点卡：下一件 / 空状态

    @ViewBuilder
    private var nextFocusCard: some View {
        HStack(spacing: 10) {
            Group {
                if state.nextTodoTitle != nil {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BusinessLiveStyle.green)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 32, height: 32)
            .background(
                (state.nextTodoTitle != nil ? BusinessLiveStyle.green.opacity(0.16) : BusinessLiveStyle.green),
                in: Circle()
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(state.nextTodoTitle != nil ? "下一件" : "今日事项已清空")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(state.nextTodoTitle != nil ? BusinessLiveStyle.green : .white.opacity(0.75))
                Text(state.nextTodoTitle ?? "辛苦啦，记得盘点营业额")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            if let time = state.nextTodoTime {
                Text(time, style: .time)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(BusinessLiveStyle.green.opacity(0.22), in: Capsule())
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 0.5)
        }
    }

    // MARK: 底部指标条：待办 / 配送 / 临期

    private var metricStrip: some View {
        HStack(spacing: 0) {
            MetricCell(
                icon: "checkmark.circle.fill",
                value: todoCount,
                label: "待办",
                tint: .white
            )
            stripDivider
            MetricCell(
                icon: "person.2.fill",
                value: state.deliveringCustomerCount,
                label: "配送",
                tint: .white
            )
            stripDivider
            MetricCell(
                icon: "exclamationmark.triangle.fill",
                value: state.urgentExpiryCount,
                label: "临期",
                tint: state.urgentExpiryCount > 0 ? BusinessLiveStyle.amber : .white.opacity(0.4)
            )
        }
        .padding(.vertical, 9)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var stripDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.09))
            .frame(width: 0.5, height: 22)
    }
}

private struct MetricCell: View {
    let icon: String
    let value: Int
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(verbatim: "\(value)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 样式与辅助

enum BusinessLiveStyle {
    /// 品牌绿
    static let green = Color(red: 0x27/255, green: 0xC5/255, blue: 0x6F/255)
    /// 临期琥珀
    static let amber = Color(red: 0xFF/255, green: 0xB0/255, blue: 0x20/255)
    /// 锁屏背景兜底色（渐变覆盖其上）
    static let deepBackground = Color(red: 0.02, green: 0.04, blue: 0.03)

    /// todoCount 为可选字段，缺省时按有无下一件待办兜底为 1/0
    static func todoCount(_ state: BusinessActivityAttributes.ContentState) -> Int {
        state.todoCount ?? (state.nextTodoTitle != nil ? 1 : 0)
    }

    static func timeSuffix(_ date: Date?) -> String {
        guard let date else { return "" }
        return " · " + date.formatted(date: .omitted, time: .shortened)
    }
}
