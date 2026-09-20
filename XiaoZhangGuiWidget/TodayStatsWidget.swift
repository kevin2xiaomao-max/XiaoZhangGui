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
        todayRevenue: 2680,
        todayGoalPercent: 63,
        todayTodoCount: 2,
        overdueTodoCount: 1,
        nextTodoTitle: "下午去市场进货",
        nextTodoTime: Date.today(hour: 15),
        deliveringCustomerCount: 2,
        urgentExpiryCount: 4,
        nextExpiryName: "鲜牛奶",
        nextExpiryDays: 2,
        focusItems: [
            WidgetFocusItem(
                id: "sample-overdue-1",
                kind: .todoOverdue,
                title: "给王姐回电话确认订单",
                detail: "逾期",
                completable: true
            ),
            WidgetFocusItem(
                id: "sample-delivery-1",
                kind: .delivery,
                title: "3 栋 502 鲜牛奶两箱",
                detail: "今晚配送",
                completable: false
            ),
        ]
    )
}

private extension Date {
    static func today(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }
}

// MARK: - 品牌色（Widget target 内联定义，与主 App V21Color 对齐）

private enum WidgetBrand {
    // Restrained Ocean fallback until signed App Group theme propagation is verified.
    static let green = Color(red: 0x3A / 255, green: 0x70 / 255, blue: 0xB7 / 255)
    static let warning = Color(red: 0xFF / 255, green: 0x9F / 255, blue: 0x0A / 255)
    static let danger = Color(red: 0xFF / 255, green: 0x6B / 255, blue: 0x6B / 255)
}

// MARK: - Widget 定义

struct TodayStatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayStatsWidget", provider: SnapshotProvider()) { entry in
            TodayStatsEntryView(entry: entry)
                // V3.3 Widget 2.0：系统材质底（浅=米白中性、深=暗材质；
                // Tinted 自动单色化、Clear/StandBy 下保证对比度）；锁屏 accessory 由系统忽略背景。
                .containerBackground(for: .widget) {
                    Rectangle().fill(.thinMaterial)
                }
        }
        .configurationDisplayName("小掌柜工作台")
        .description("一键问小掌柜、语音记录；今日营业额与现在最该做的两件事")
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
            // V3.3 Widget 2.0：Small = 问小掌柜 + 语音记录（不再是营业额仪表盘）
            SmallWorkbenchView(snapshot: entry.snapshot)
        case .systemMedium:
            // V3.3 Widget 2.0：Medium = 经营概览 + 快捷工作台（待办可勾选）
            MediumWorkbenchView(snapshot: entry.snapshot)
        case .accessoryInline:
            InlineView(snapshot: entry.snapshot)
        case .accessoryCircular:
            CircularView(snapshot: entry.snapshot)
        default:
            RectangularView(snapshot: entry.snapshot)
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
