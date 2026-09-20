import Foundation

enum BusinessPeriod: Equatable, Sendable {
    case today
    case yesterday
    case lastSevenDays
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
        if t.contains("最近7天") || t.contains("最近七天") || t.contains("最近一周") || t.contains("近一周") || t.contains("过去一周") || t.contains("这一周") || t.contains("本周") { return .lastSevenDays }
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
        case .thisMonth: return calendar.dateInterval(of: .month, for: now)
        case .lastMonth:
            guard let month = calendar.date(byAdding: .month, value: -1, to: now) else { return nil }
            return calendar.dateInterval(of: .month, for: month)
        case .lastThreeMonths, .lastThreeMonthsComparedWithThisMonth:
            let start = calendar.date(byAdding: .month, value: -3, to: today) ?? today
            return DateInterval(start: start, end: today)
        case .lastSixMonths:
            let start = calendar.date(byAdding: .month, value: -6, to: today) ?? today
            return DateInterval(start: start, end: today)
        case .thisMonthComparedWithLastMonth: return calendar.dateInterval(of: .month, for: now)
        }
    }
}
