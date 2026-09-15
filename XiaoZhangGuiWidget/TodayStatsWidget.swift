import WidgetKit
import SwiftUI

// MARK: - 今日经营小组件
// 主屏：systemSmall / systemMedium
// 锁屏：accessoryInline / accessoryRectangular / accessoryCircular
// 数据源：App Group UserDefaults 中的 BusinessSnapshot（主 App 与 App Intents 写入后 reload）

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: BusinessSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: BusinessSnapshot.load() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = SnapshotEntry(date: .now, snapshot: BusinessSnapshot.load())
        // 0 点与次日 0 点各刷新一次（跨天数据归零），主 App 数据变化时会主动 reload
        var entries = [now]
        if let midnight = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) {
            entries.append(SnapshotEntry(date: midnight, snapshot: BusinessSnapshot.load()))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

extension BusinessSnapshot {
    /// 首次添加小组件 / 预览用示例数据（真实数据由主 App 快照覆盖）
    static let sample = BusinessSnapshot(
        todayRevenue: 1260,
        todayGoalPercent: 63,
        todayTodoCount: 3,
        overdueTodoCount: 1,
        nextTodoTitle: "下午去市场进货",
        nextTodoTime: Date.today(hour: 15),
        deliveringCustomerCount: 2,
        urgentExpiryCount: 4,
        nextExpiryName: "鲜牛奶",
        nextExpiryDays: 2
    )
}

private extension Date {
    static func today(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }
}

// MARK: - 品牌色（Widget target 内联定义，与主 App V21Color 对齐）

private enum WidgetBrand {
    static let green = Color(red: 0x27 / 255, green: 0xC5 / 255, blue: 0x6F / 255)
    static let warning = Color(red: 0xFF / 255, green: 0x9F / 255, blue: 0x0A / 255)
    static let danger = Color(red: 0xFF / 255, green: 0x6B / 255, blue: 0x6B / 255)
}

// MARK: - Widget 定义

struct TodayStatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayStatsWidget", provider: SnapshotProvider()) { entry in
            TodayStatsEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(white: 0.08).opacity(entry.snapshot == nil ? 0.0 : 1.0)
                }
                // 锁屏点击直达语音快速记录（iOS 安全限制下打开 App 后用户再点一次麦克风）
                .widgetURL(URL(string: "xzg://voice"))
        }
        .configurationDisplayName("今日经营")
        .description("今日营业额、待办数量、临期提醒和下一件事")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryInline, .accessoryCircular, .accessoryRectangular,
        ])
    }
}

// MARK: - 各尺寸视图

struct TodayStatsEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallView(snapshot: entry.snapshot)
        case .systemMedium:
            MediumView(snapshot: entry.snapshot)
        case .accessoryInline:
            InlineView(snapshot: entry.snapshot)
        case .accessoryCircular:
            CircularView(snapshot: entry.snapshot)
        default:
            RectangularView(snapshot: entry.snapshot)
        }
    }
}

/// systemSmall：营业额 + 待办/临期徽标
private struct SmallView: View {
    let snapshot: BusinessSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(WidgetBrand.green).frame(width: 6, height: 6)
                Text("今日营业额")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("待办 \(snapshot?.todayTodoCount ?? 0)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(snapshot != nil && snapshot!.overdueTodoCount > 0 ? WidgetBrand.danger : .secondary)
            }
            Text("¥\(formatAmount(snapshot?.todayRevenue ?? 0))")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if snapshot?.todayGoalPercent ?? 0 > 0 {
                ProgressView(value: Double(min(snapshot?.todayGoalPercent ?? 0, 100)), total: 100)
                    .tint(WidgetBrand.green)
            }
            Text(verbatim: nextEventLine)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var nextEventLine: String {
        guard let s = snapshot else { return "打开 App 同步数据" }
        if let todo = s.nextTodoTitle { return "下一件事：\(todo)" }
        if let expiry = s.nextExpiryName, let days = s.nextExpiryDays {
            return "临期：\(expiry) 还剩\(days)天"
        }
        return "今天没有待办"
    }
}

/// systemMedium：左营业额 / 右三行状态
private struct MediumView: View {
    let snapshot: BusinessSnapshot?

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日营业额")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("¥\(formatAmount(snapshot?.todayRevenue ?? 0))")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("今日目标 \(snapshot?.todayGoalPercent ?? 0)%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WidgetBrand.green)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                StatusRow(
                    icon: "checkmark.circle",
                    color: .secondary,
                    text: "待办 \(snapshot?.todayTodoCount ?? 0) 件"
                        + (snapshot?.overdueTodoCount ?? 0 > 0 ? "（逾期 \((snapshot?.overdueTodoCount ?? 0))）" : "")
                )
                StatusRow(
                    icon: "person.2",
                    color: .secondary,
                    text: "配送中 \(snapshot?.deliveringCustomerCount ?? 0) 单"
                )
                StatusRow(
                    icon: "calendar.badge.exclamationmark",
                    color: (snapshot?.urgentExpiryCount ?? 0) > 0 ? WidgetBrand.warning : .secondary,
                    text: "临期 \(snapshot?.urgentExpiryCount ?? 0) 件"
                )
                if let todo = snapshot?.nextTodoTitle {
                    Text(verbatim: "下一件事：\(todo)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StatusRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(verbatim: text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}

/// accessoryInline：单行文字
private struct InlineView: View {
    let snapshot: BusinessSnapshot?

    var body: some View {
        if let s = snapshot {
            Text(verbatim: "¥\(formatAmount(s.todayRevenue)) · 待办\(s.todayTodoCount) 临期\(s.urgentExpiryCount)")
        } else {
            Text("你的小掌柜")
        }
    }
}

/// accessoryCircular：营业额大数字
private struct CircularView: View {
    let snapshot: BusinessSnapshot?

    var body: some View {
        VStack(spacing: 0) {
            Text("今日")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text(verbatim: shortAmount(snapshot?.todayRevenue ?? 0))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
        }
    }
}

/// accessoryRectangular：锁屏信息块
private struct RectangularView: View {
    let snapshot: BusinessSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Circle().fill(WidgetBrand.green).frame(width: 5, height: 5)
                Text("你的小掌柜")
                    .font(.system(size: 10, weight: .semibold).smallCaps())
            }
            Text(verbatim: "今日 ¥\(formatAmount(snapshot?.todayRevenue ?? 0)) · 待办 \(snapshot?.todayTodoCount ?? 0)")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Text(verbatim: nextLine)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var nextLine: String {
        guard let s = snapshot else { return "打开 App 同步数据" }
        if let todo = s.nextTodoTitle { return "下一件事：\(todo)" }
        if let expiry = s.nextExpiryName, let days = s.nextExpiryDays {
            return "临期：\(expiry) 还剩\(days)天"
        }
        return "临期 \(s.urgentExpiryCount) 件"
    }
}

// MARK: - 数字格式化

private func formatAmount(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
        return grouped(value)
    }
    return String(format: "%.2f", value)
}

private func shortAmount(_ value: Double) -> String {
    if value >= 10000 {
        return String(format: "%.1f万", value / 10000)
    }
    return grouped(value)
}

private func grouped(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
}
