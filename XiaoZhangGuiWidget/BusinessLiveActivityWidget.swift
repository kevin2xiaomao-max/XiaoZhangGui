import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Live Activity：今日经营实况
// 锁屏卡片 + 灵动岛（compact / minimal / expanded）
// 场景 1：锁屏/灵动岛显示下一条待办、配送中的客户需求、临期提醒

struct BusinessLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusinessActivityAttributes.self) { context in
            // 锁屏 / 灵动岛全屏展开卡片
            LockScreenLiveActivityView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandColumn(
                        icon: "checkmark.circle",
                        label: "待办",
                        value: "\(context.state.todoCount ?? (context.state.nextTodoTitle != nil ? 1 : 0)) 件"
                    )
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 3) {
                        Image(systemName: "storefront")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(red: 0x27/255, green: 0xC5/255, blue: 0x6F/255))
                        Text("今日经营")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    IslandColumn(
                        icon: "person.2",
                        label: "配送中",
                        value: "\(context.state.deliveringCustomerCount) 单"
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        if let todo = context.state.nextTodoTitle {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.badge.checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(verbatim: "下一件：\(todo)\(timeSuffix(context.state.nextTodoTime))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            Text("今天暂无待办")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        if context.state.urgentExpiryCount > 0 {
                            Text(verbatim: "⚠️ \(context.state.urgentExpiryCount) 件商品临期，注意退货")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(red: 0xFF/255, green: 0x9F/255, blue: 0x0A/255))
                                .lineLimit(1)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0x27/255, green: 0xC5/255, blue: 0x6F/255))
            } compactTrailing: {
                if context.state.urgentExpiryCount > 0 {
                    Text(verbatim: "⚠️\(context.state.urgentExpiryCount)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0xFF/255, green: 0x9F/255, blue: 0x0A/255))
                } else if context.state.deliveringCustomerCount > 0 {
                    Text(verbatim: "🚚\(context.state.deliveringCustomerCount)")
                        .font(.system(size: 12, weight: .semibold))
                }
            } minimal: {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0x27/255, green: 0xC5/255, blue: 0x6F/255))
            }
            .keylineTint(.white)
        }
    }

    private func timeSuffix(_ date: Date?) -> String {
        guard let date else { return "" }
        return " · " + date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - 锁屏卡片视图

private struct LockScreenLiveActivityView: View {
    let state: BusinessActivityAttributes.ContentState

    private var green: Color { Color(red: 0x27/255, green: 0xC5/255, blue: 0x6F/255) }
    private var warning: Color { Color(red: 0xFF/255, green: 0x9F/255, blue: 0x0A/255) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("今日经营", systemImage: "storefront")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(green)
                Spacer()
                Text(state.updatedAt, style: .time)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let todo = state.nextTodoTitle {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(green)
                    Text(verbatim: "下一件：\(todo)\(timeSuffix(state.nextTodoTime))")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("今天暂无待办")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                HighlightPill(icon: "person.2", value: state.deliveringCustomerCount, label: "配送中")
                HighlightPill(icon: "calendar.badge.exclamationmark", value: state.urgentExpiryCount, label: "临期")
                    .foregroundStyle(state.urgentExpiryCount > 0 ? warning : .white)
                Spacer()
            }
        }
        .padding(14)
    }

    private func timeSuffix(_ date: Date?) -> String {
        guard let date else { return "" }
        return " · " + date.formatted(date: .omitted, time: .shortened)
    }
}

private struct HighlightPill: View {
    let icon: String
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(verbatim: "\(value) \(label)")
                .font(.system(size: 12, weight: .semibold))
        }
    }
}

// MARK: - 灵动岛展开列

private struct IslandColumn: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.system(size: 13, weight: .bold))
        }
    }
}
