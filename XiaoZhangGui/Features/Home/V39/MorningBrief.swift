import SwiftUI
import UserNotifications

// MARK: - V3.9.2 PR-I · 掌柜晨报(开店前 30 秒的一站式总览)
//
// 定位:本地规则引擎,零云端依赖、零新数据表——全部由既有模型当场计算,
// 口径逐项复用 V3.9.1 HomeAggregates 的承诺(今日/昨日/本月/待办/逾期/配送),
// 不发明第二套统计规则;「建议」是确定性的规则排序,可单测复现。
//
// 组成:
// - `MorningBriefBuilder.build`:纯函数,输入既有模型 + now(可注入日历,可单测)
// - `MorningBriefStore`:已读状态(yyyy-MM-dd,跨天自动视为未读)
// - `MorningBriefNotifier`:可选每日 8:00 本地提醒(镜像 BackupReminder 的
//   授权纪律:被拒不置位,不做「开关开着却永远不响」的假承诺)
// - `MorningBriefCard` / `MorningBriefSheet`:首页卡 + 详情(V39 玻璃语言)

struct MorningBrief: Equatable {
    let generatedAt: Date
    let greeting: String
    let yesterdayRevenue: Double
    /// 昨日 vs 前日;前日无营业额时为 nil(不显示环比,不假装 0%)。
    let revenueChangePercent: Double?
    let todayTodoCount: Int
    let overdueCount: Int
    let expiringSoonCount: Int
    let deliveryCount: Int
    let monthRevenue: Double
    let monthGoal: Double
    /// 0...1;无目标时为 0。
    let monthProgress: Double
    /// 今日重点,最多 3 条("09:00 补货"/"全天 盘点"格式,与日历页同一时间标注)。
    let focusItems: [String]
    let advice: String

    /// 主句:昨日营收 + 环比(口径明示「较前日」,与首页 Hero「较昨日」区分)。
    var headlineText: String {
        var text = "昨日营业额 ¥" + Fmt.groupedAmount(yesterdayRevenue)
        if let change = revenueChangePercent {
            text += change >= 0
                ? ",较前日涨 \(String(format: "%.0f", abs(change)))%"
                : ",较前日跌 \(String(format: "%.0f", abs(change)))%"
        }
        return text
    }

    var progressText: String {
        guard monthGoal > 0 else { return "未设月目标" }
        return "本月 \(Int((monthProgress * 100).rounded()))% · ¥\(Fmt.groupedAmount(monthRevenue)) / ¥\(Fmt.groupedAmount(monthGoal))"
    }
}

enum MorningBriefBuilder {

    static func build(
        performances: [Performance],
        todos: [Todo],
        expiryItems: [ExpiryItem],
        customers: [CustomerRequest],
        monthGoal: Double,
        now: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> MorningBrief {
        let todayStart = now.startOfDay
        let todayEnd = now.endOfDay
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let dayBefore = calendar.date(byAdding: .day, value: -2, to: now) ?? now

        var yesterdayRevenue = 0.0
        var dayBeforeRevenue = 0.0
        var monthRevenue = 0.0
        for performance in performances {
            if performance.date.isSameDay(as: yesterday) { yesterdayRevenue += performance.amount }
            if performance.date.isSameDay(as: dayBefore) { dayBeforeRevenue += performance.amount }
            if performance.date >= now.startOfMonth && performance.date <= todayEnd {
                monthRevenue += performance.amount
            }
        }

        // 口径与 HomeAggregates 完全一致:
        // 今日待办 = 未完成且(无截止或截止今天);逾期 = 未完成且截止早于今日 0 点。
        var todayTodos: [Todo] = []
        var overdueCount = 0
        for todo in todos where !todo.isCompleted {
            if todo.dueDate == nil || (todo.dueDate! >= todayStart && todo.dueDate! <= todayEnd) {
                todayTodos.append(todo)
            }
            if let due = todo.dueDate, due < todayStart { overdueCount += 1 }
        }
        todayTodos.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        // 时间标注不直接用 DayTimeLabel(其 isToday 判断耦合真实时钟,与注入 now 分叉);
        // 此处谓词已保证全部是今日待办:有钟点 → HH:mm,无钟点/无截止 → 全天。
        let focusItems = todayTodos.prefix(3).map { todo in
            let time: String
            if let due = todo.dueDate, ScheduleAgenda.hasClock(due) {
                time = Fmt.time(due)
            } else {
                time = "全天"
            }
            return "\(time) \(DisplayText.visible(todo.title, fallback: "待办事项"))"
        }

        // 临期:待处理且 7 天内到期(含已临期);与首页 pendingExpiry 同一待处理口径。
        let expiringSoonCount = expiryItems.filter { item in
            item.status == .pending && item.daysLeft(from: now) <= 7
        }.count

        // 配送:全部未完成配送(与首页 chips「配送」同口径,不限今日,避免第二口径)。
        let deliveryCount = customers.filter { $0.statusEnum != .done }.count

        return MorningBrief(
            generatedAt: now,
            greeting: greeting(for: now, calendar: calendar),
            yesterdayRevenue: yesterdayRevenue,
            revenueChangePercent: dayBeforeRevenue > 0
                ? (yesterdayRevenue - dayBeforeRevenue) / dayBeforeRevenue * 100
                : nil,
            todayTodoCount: todayTodos.count,
            overdueCount: overdueCount,
            expiringSoonCount: expiringSoonCount,
            deliveryCount: deliveryCount,
            monthRevenue: monthRevenue,
            monthGoal: monthGoal,
            monthProgress: monthGoal > 0 ? min(max(monthRevenue / monthGoal, 0), 1) : 0,
            focusItems: Array(focusItems),
            advice: advice(
                overdueCount: overdueCount, expiringSoonCount: expiringSoonCount,
                deliveryCount: deliveryCount, monthGoal: monthGoal,
                monthRevenue: monthRevenue, yesterdayRevenue: yesterdayRevenue,
                now: now, calendar: calendar
            )
        )
    }

    private static func greeting(for now: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: now) {
        case ..<11: return "早上好,掌柜"
        case 11..<18: return "下午好,掌柜"
        default: return "晚上好,掌柜"
        }
    }

    /// 建议按确定性优先级取第一条命中:逾期 > 临期 > 配送 > 目标落后 > 目标达成 > 默认。
    private static func advice(
        overdueCount: Int, expiringSoonCount: Int, deliveryCount: Int,
        monthGoal: Double, monthRevenue: Double, yesterdayRevenue: Double,
        now: Date, calendar: Calendar
    ) -> String {
        if overdueCount > 0 {
            return "有 \(overdueCount) 件事已逾期,今天先把它们清掉,心里才踏实。"
        }
        if expiringSoonCount > 0 {
            return "有 \(expiringSoonCount) 件商品 7 天内到期,趁新鲜赶紧卖掉或处理。"
        }
        if deliveryCount > 0 {
            return "还有 \(deliveryCount) 单配送在路上,别忘了跟进。"
        }
        if monthGoal > 0 {
            let progress = min(max(monthRevenue / monthGoal, 0), 1)
            let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
            let dayOfMonth = calendar.component(.day, from: now)
            let timeProgress = Double(dayOfMonth) / Double(daysInMonth)
            if progress >= 1 {
                return "本月目标已达成,稳了,掌柜!"
            }
            if progress < timeProgress - 0.15 {
                return "本月目标完成 \(Int((progress * 100).rounded()))%,落后于时间,这两天加把劲。"
            }
        }
        if yesterdayRevenue > 0 {
            return "昨天进账不错,保持节奏。"
        }
        return "新的一天,记下第一笔生意就开始了。"
    }
}

// MARK: - 已读状态(跨天自动未读)

enum MorningBriefStore {
    static let readOnKey = "xzg.morningBrief.readOn"

    /// 稳定日期键(yyyy-MM-dd,本地时区),与日历页 UI 测试标识同一格式。
    /// P1:原实现每次调用都新建 DateFormatter(首页 body 每帧调用两次),改为静态缓存。
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        isoDayFormatter.string(from: date)
    }

    private static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func isRead(on date: Date, defaults: UserDefaults = .standard, calendar: Calendar = .current) -> Bool {
        defaults.string(forKey: readOnKey) == dayKey(date, calendar: calendar)
    }

    static func markRead(now: Date = Date(), defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        defaults.set(dayKey(now, calendar: calendar), forKey: readOnKey)
    }
}

// MARK: - 每日 8:00 提醒(授权纪律与 BackupReminder 一致)

enum MorningBriefNotifier {
    private static let enabledKey = "xzg.morningBrief.dailyReminderEnabled"
    private static let notificationID = "xzg.morningbrief.daily"

    /// 通知内容为固定引导文案(本地通知无法在触发时现算数据),
    /// 数据一律进 App 后由晨报卡当场计算,不做「推送里带数字」的假象。
    static func setDailyReminder(_ enabled: Bool, completion: ((Bool) -> Void)? = nil) {
        let defaults = UserDefaults.standard
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        func done(_ ok: Bool) {
            DispatchQueue.main.async { completion?(ok) }
        }
        guard enabled else {
            defaults.set(false, forKey: enabledKey)
            done(true)
            return
        }
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.scheduleDaily(center: center)
                defaults.set(true, forKey: enabledKey)
                done(true)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted {
                        self.scheduleDaily(center: center)
                        defaults.set(true, forKey: enabledKey)
                        done(true)
                    } else {
                        defaults.set(false, forKey: enabledKey)
                        done(false)
                    }
                }
            default: // .denied:不挂提醒、不置开关位,调用方提示去系统设置。
                defaults.set(false, forKey: enabledKey)
                done(false)
            }
        }
    }

    private static func scheduleDaily(center: UNUserNotificationCenter = .current()) {
        let content = UNMutableNotificationContent()
        content.title = "掌柜晨报已就绪"
        content.body = "昨日经营、今日安排、临期提醒,30 秒看完。"
        content.sound = .default
        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        center.add(request)
    }

    static var dailyReminderEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }
}

// MARK: - 首页晨报卡(V39 玻璃数据卡语言)

struct MorningBriefCard: View {
    let brief: MorningBrief
    let isRead: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            V38HomeGlassSurface(radius: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "sun.horizon.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(V39Style.gold)
                        Text(brief.greeting)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if !isRead {
                            // 未读金点(直径 7pt,非交互、不进无障碍树——状态由 label 播报)。
                            Circle()
                                .fill(V39Style.gold)
                                .frame(width: 7, height: 7)
                                .accessibilityHidden(true)
                        }
                        Spacer(minLength: 8)
                        Text(brief.generatedAt, format: .dateTime.month().day().locale(Locale(identifier: "zh_CN")))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    Text(brief.headlineText)
                        .font(.system(.headline, design: .rounded).monospacedDigit())
                        .foregroundStyle(V39Style.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    // 概览行:待办/逾期/临期/配送,口径与首页 chips 一字不差。
                    HStack(spacing: 12) {
                        briefMetric("待办", brief.todayTodoCount)
                        briefMetric("逾期", brief.overdueCount, isAlert: brief.overdueCount > 0)
                        briefMetric("临期", brief.expiringSoonCount, isAlert: brief.expiringSoonCount > 0)
                        briefMetric("配送", brief.deliveryCount)
                    }
                    Text(brief.advice)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(V39PressFeedbackStyle())
        .accessibilityIdentifier("v39.morningBrief.card")
        .accessibilityLabel("\(brief.greeting),\(brief.headlineText),\(accessibilitySummary)")
        .accessibilityHint("轻点查看今日晨报详情")
    }

    private var accessibilitySummary: String {
        var parts = [
            "今日待办\(brief.todayTodoCount)项",
            brief.overdueCount > 0 ? "逾期\(brief.overdueCount)项" : "",
            brief.expiringSoonCount > 0 ? "临期\(brief.expiringSoonCount)件" : "",
            brief.deliveryCount > 0 ? "配送\(brief.deliveryCount)单" : "",
        ].filter { !$0.isEmpty }
        parts.append(brief.advice)
        return parts.joined(separator: ",")
    }

    private func briefMetric(_ title: String, _ count: Int, isAlert: Bool = false) -> some View {
        HStack(spacing: 3) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(isAlert ? V371.Colors.red : .primary)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)\(count)")
    }
}

// MARK: - 晨报详情 Sheet

struct MorningBriefSheet: View {
    let brief: MorningBrief
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headlineCard
                    if !brief.focusItems.isEmpty { focusSection }
                    statSection
                    goalSection
                    adviceSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(V371.Colors.canvas)
            .navigationTitle("掌柜晨报")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var headlineCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(brief.greeting)
                .font(.headline)
                .foregroundStyle(V39Style.navy)
            Text(brief.headlineText)
                .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(V39Style.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("数据由账本当场计算,口径与首页一致")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private var focusSection: some View {
        briefSection("今日重点") {
            ForEach(Array(brief.focusItems.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(V39Style.gold)
                        .padding(.top, 5)
                        .accessibilityHidden(true)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if index < brief.focusItems.count - 1 { V371Divider() }
            }
        }
    }

    private var statSection: some View {
        briefSection("今日概览") {
            briefRow(label: "今日待办", value: "\(brief.todayTodoCount) 项")
            if brief.overdueCount > 0 {
                briefRow(label: "已逾期", value: "\(brief.overdueCount) 项", valueColor: V371.Colors.red)
            }
            if brief.expiringSoonCount > 0 {
                briefRow(label: "7 天内临期", value: "\(brief.expiringSoonCount) 件", valueColor: V371.Colors.orange)
            }
            if brief.deliveryCount > 0 {
                briefRow(label: "配送在路上", value: "\(brief.deliveryCount) 单")
            }
        }
    }

    private var goalSection: some View {
        briefSection("月目标") {
            VStack(alignment: .leading, spacing: 8) {
                Text(brief.progressText)
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(.primary)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(V39Style.gold)
                            .frame(width: max(proxy.size.width * brief.monthProgress, brief.monthGoal > 0 ? 4 : 0))
                    }
                }
                .frame(height: 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("月目标完成百分之\(Int((brief.monthProgress * 100).rounded()))")
            }
        }
    }

    private var adviceSection: some View {
        briefSection("掌柜建议") {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(V39Style.gold)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                Text(brief.advice)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func briefSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            V38HomeSectionHeader(title: title)
            GroupSurface {
                VStack(alignment: .leading, spacing: 10) {
                    content()
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func briefRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(valueColor)
        }
        .frame(minHeight: 32)
        .accessibilityElement(children: .combine)
    }
}
