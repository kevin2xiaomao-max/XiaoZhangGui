import Foundation

enum BusinessPeriod: Equatable, Sendable, Hashable {
    case today
    case yesterday
    case lastSevenDays
    /// 本周：周一起始的自然周，与 PerformanceTrend.last4Weeks 同口径。
    case thisWeek
    /// 上周：周一起始的自然周（本周往前一周）。
    case lastWeek
    case thisMonth
    case lastMonth
    case lastThreeMonths
    case lastSixMonths
    case thisMonthComparedWithLastMonth
    case lastThreeMonthsComparedWithThisMonth
}

struct BusinessPeriodParser {
    func parse(_ text: String) -> BusinessPeriod? {
        let t = text.replacingOccurrences(of: " ", with: "")
        if (t.contains("三个月") || t.contains("3个月")) && (t.contains("这个月") || t.contains("本月")) && t.contains("对比") { return .lastThreeMonthsComparedWithThisMonth }
        if (t.contains("这个月") || t.contains("本月")) && (t.contains("上个月") || t.contains("上月")) && t.contains("对比") { return .thisMonthComparedWithLastMonth }
        if t.contains("最近6个月") || t.contains("近6个月") || t.contains("近半年") { return .lastSixMonths }
        if t.contains("最近3个月") || t.contains("近三个月") || t.contains("三个月") { return .lastThreeMonths }
        if t.contains("上个月") || t.contains("上月") { return .lastMonth }
        if t.contains("这个月") || t.contains("本月") { return .thisMonth }
        // V3.9.3 口径修正：本周/上周走周一起始的自然周（与 Performance 页一致）；
        // 「最近一周 / 过去一周 / 过去 7 天」仍走过去 7 天（lastSevenDays），不混用。
        if t.contains("上周") || t.contains("上一周") { return .lastWeek }
        if t.contains("本周") || t.contains("这一周") || t.contains("这周") { return .thisWeek }
        if t.contains("最近7天") || t.contains("最近七天") || t.contains("最近一周") || t.contains("近一周") || t.contains("过去一周") || t.contains("过去7天") || t.contains("过去七天") { return .lastSevenDays }
        if t.contains("昨天") { return .yesterday }
        if t.contains("今天") { return .today }
        return nil
    }

    func bounds(for period: BusinessPeriod, now: Date, calendar: Calendar) -> DateInterval? {
        let today = calendar.startOfDay(for: now)
        switch period {
        case .today: return DateInterval(start: today, end: calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        case .yesterday:
            let start = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            return DateInterval(start: start, end: today)
        case .lastSevenDays:
            let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        case .thisWeek:
            var weekCalendar = calendar
            weekCalendar.firstWeekday = 2
            return weekCalendar.dateInterval(of: .weekOfYear, for: now)
        case .lastWeek:
            var weekCalendar = calendar
            weekCalendar.firstWeekday = 2
            guard let thisWeek = weekCalendar.dateInterval(of: .weekOfYear, for: now),
                  let start = weekCalendar.date(byAdding: .day, value: -7, to: thisWeek.start) else { return nil }
            return DateInterval(start: start, end: thisWeek.start)
        case .thisMonth: return calendar.dateInterval(of: .month, for: now)
        case .lastMonth:
            guard let month = calendar.date(byAdding: .month, value: -1, to: now) else { return nil }
            return calendar.dateInterval(of: .month, for: month)
        case .lastThreeMonths, .lastThreeMonthsComparedWithThisMonth:
            // V3.9.3 口径修正：end 由 today（当日 0 点）改为 tomorrow，含今日全天；
            // 此前「近 3 个月」恒漏今日。lastThreeMonthsComparedWithThisMonth 的
            // current 段仍由 Reader 特殊处理为「本月至今」，不受此 end 影响。
            let start = calendar.date(byAdding: .month, value: -3, to: today) ?? today
            return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        case .lastSixMonths:
            let start = calendar.date(byAdding: .month, value: -6, to: today) ?? today
            return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        case .thisMonthComparedWithLastMonth: return calendar.dateInterval(of: .month, for: now)
        }
    }
}
