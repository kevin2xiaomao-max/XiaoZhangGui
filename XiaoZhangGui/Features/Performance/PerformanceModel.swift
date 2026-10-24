import Foundation

// MARK: - 业绩派生数据（语义对齐 Android PerformanceViewModel）
// P0-3：新增独立 incomeSource 字段后，优先读 incomeSource；空则 fallback 到 note 关键词派生

enum PerformancePeriod: String, CaseIterable, Identifiable, Hashable {
    case today = "今日"
    case week = "本周"
    case month = "本月"
    case custom = "自定义"

    var id: String { rawValue }

    /// 时间段范围（start...end，含当天）
    func range(customStart: Date, customEnd: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        switch self {
        case .today:
            return (Date().startOfDay, Date().endOfDay)
        case .week:
            // 近 7 天（对齐 Android minusDays(6)）
            let start = cal.date(byAdding: .day, value: -6, to: Date().startOfDay) ?? Date()
            return (start.startOfDay, Date().endOfDay)
        case .month:
            return (Date().startOfMonth, cal.date(byAdding: DateComponents(month: 1, second: -1), to: Date().startOfMonth) ?? Date())
        case .custom:
            return (customStart.startOfDay, customEnd.endOfDay)
        }
    }
}

struct PerformanceStats {
    let totalRevenue: Double
    let totalExpense: Double
    let net: Double

    static func compute(
        performances: [Performance],
        expenses: [Expense],
        period: PerformancePeriod,
        customStart: Date,
        customEnd: Date
    ) -> PerformanceStats {
        let range = period.range(customStart: customStart, customEnd: customEnd)
        let rev = performances
            .filter { $0.date >= range.start && $0.date <= range.end }
            .reduce(0) { $0 + $1.amount }
        let exp = expenses
            .filter { $0.date >= range.start && $0.date <= range.end }
            .reduce(0) { $0 + $1.amount }
        return PerformanceStats(totalRevenue: rev, totalExpense: exp, net: rev - exp)
    }
}

struct PeriodComparison {
    let percentage: Double?

    static func compute(
        performances: [Performance],
        currentRange: (start: Date, end: Date)
    ) -> PeriodComparison {
        let duration = currentRange.end.timeIntervalSince(currentRange.start)
        guard duration > 0 else { return PeriodComparison(percentage: nil) }

        let previousEnd = currentRange.start.addingTimeInterval(-1)
        let previousStart = previousEnd.addingTimeInterval(-duration)
        let current = performances
            .filter { $0.date >= currentRange.start && $0.date <= currentRange.end }
            .reduce(0) { $0 + $1.amount }
        let previous = performances
            .filter { $0.date >= previousStart && $0.date <= previousEnd }
            .reduce(0) { $0 + $1.amount }

        guard previous > 0 else { return PeriodComparison(percentage: nil) }
        return PeriodComparison(percentage: (current - previous) / previous * 100)
    }
}

enum IncomeSource: String, CaseIterable, Identifiable {
    case store = "门店"
    case meituan = "美团"
    case other = "其他"

    var id: String { rawValue }

    static func from(note: String) -> IncomeSource {
        let normalized = note.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("美团") { return .meituan }
        if normalized.contains("门店") || normalized.contains("到店") { return .store }
        return .other
    }

    /// P0-3：优先用独立 incomeSource 字段（用户在编辑器里选择）；
    /// 空字符串 fallback 到 note 关键词派生（兼容旧记录）。
    static func from(performance: Performance) -> IncomeSource {
        let stored = performance.incomeSource.trimmingCharacters(in: .whitespacesAndNewlines)
        if let matched = IncomeSource(rawValue: stored) {
            return matched
        }
        // 兼容扫呗导入：扫呗 paymentMethod 可能含 "美团"
        if stored.isEmpty {
            let pay = performance.paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
            if pay == "美团" || pay.lowercased() == "meituan" {
                return .meituan
            }
            if pay == "门店" || pay.lowercased() == "store" {
                return .store
            }
        }
        return IncomeSource.from(note: performance.note)
    }
}

struct IncomeSourceSummary: Identifiable {
    let source: IncomeSource
    let amount: Double
    let ratio: Double
    var id: IncomeSource { source }

    /// 展示用整百分比(最大余数法):逐项四舍五入会使合计 101% 或 99%,
    /// 本函数保证合计恒为 100%(总额 > 0 时)。条宽仍用原始 ratio,不受影响。
    static func displayPercents(for summaries: [IncomeSourceSummary]) -> [Int] {
        guard !summaries.isEmpty else { return [] }
        let total = summaries.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return summaries.map { _ in 0 } }
        let raw = summaries.map { $0.ratio * 100 }
        var result = raw.map { Int($0.rounded(.down)) }
        var leftover = 100 - result.reduce(0, +)
        let order = raw.enumerated()
            .sorted { ($0.element - Double(Int($0.element))) > ($1.element - Double(Int($1.element))) }
            .map(\.offset)
        var i = 0
        while leftover > 0, !order.isEmpty {
            result[order[i % order.count]] += 1
            leftover -= 1
            i += 1
        }
        return result
    }

    static func compute(performances: [Performance], range: (start: Date, end: Date)) -> [IncomeSourceSummary] {
        let filtered = performances.filter { $0.date >= range.start && $0.date <= range.end }
        let total = filtered.reduce(0) { $0 + $1.amount }
        return IncomeSource.allCases.map { source in
            let amount = filtered
                .filter { IncomeSource.from(performance: $0) == source }
                .reduce(0) { $0 + $1.amount }
            return IncomeSourceSummary(
                source: source,
                amount: amount,
                ratio: total > 0 ? amount / total : 0
            )
        }
    }
}

/// V3.9.1 P1-7 · 经营页头部统计单次遍历(今日/昨日/本月/本年各一遍 filter 的替代)。
/// 谓词与 PerformanceView 旧计算逐项一致;本年 = 当年 1 月 1 日...今日终了。
/// 注意:经营记录列表仍只展示近期 30 天(展示截断),本月/本年累计一律用全量 performances,
/// 严禁把列表截断误读为统计口径(见 records 注释)。
struct PerformanceHeaderAggregates {
    let today: Double
    let yesterday: Double
    let month: Double
    let year: Double

    var changePercent: Double? {
        guard yesterday > 0 else { return nil }
        return (today - yesterday) / yesterday * 100
    }

    static func build(performances: [Performance], now: Date = Date()) -> PerformanceHeaderAggregates {
        let cal = Calendar.current
        let todayStart = now.startOfDay
        let todayEnd = now.endOfDay
        let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
        let monthStart = now.startOfMonth
        let yearStart = cal.date(from: cal.dateComponents([.year], from: now)) ?? now
        var today = 0.0, yesterdaySum = 0.0, month = 0.0, year = 0.0
        for performance in performances {
            let date = performance.date
            // 今日/昨日沿用旧 isToday / isSameDay 口径(生产 now 即今天时等价于区间判定)。
            if date.isToday { today += performance.amount }
            if date.isSameDay(as: yesterday) { yesterdaySum += performance.amount }
            if date >= monthStart && date <= todayEnd { month += performance.amount }
            if date >= yearStart && date <= todayEnd { year += performance.amount }
        }
        _ = todayStart
        return PerformanceHeaderAggregates(today: today, yesterday: yesterdaySum, month: month, year: year)
    }
}

/// 近 7 天真实收入趋势点
struct TrendPoint: Identifiable {
    let id: Int
    let label: String   // "M/d"
    let value: Double
    let date: Date
}

enum PerformanceChartPeriod: String, CaseIterable, Identifiable, Hashable {
    case day = "日"
    case week = "周"
    case month = "月"

    var id: String { rawValue }

    var statsPeriod: PerformancePeriod {
        switch self {
        case .day: return .today
        case .week: return .week
        case .month: return .month
        }
    }

    /// V3.8 P1-B2：图表合计行文案与周期口径一一对应（周 ≠ 近7日）。
    var trendTotalLabel: String {
        switch self {
        case .day: return "近7日合计"
        case .week: return "近4周合计"
        case .month: return "近30日合计"
        }
    }
}

enum PerformanceTrend {
    static func last7Days(performances: [Performance], now: Date = Date()) -> [TrendPoint] {
        points(performances: performances, days: 7, now: now)
    }

    static func last30Days(performances: [Performance], now: Date = Date()) -> [TrendPoint] {
        points(performances: performances, days: 30, now: now)
    }

    /// V3.8 P1-B2：周口径真实化——近 4 周逐周汇总（周一起始，与日历页一致）。
    /// 修复前「周」与「日」都返回 last7Days，两档展示完全相同的数据。
    /// 标签用「本周/上周/前2周/前3周」；value 为该自然周内全部营业额合计。
    static func last4Weeks(performances: [Performance], now: Date = Date()) -> [TrendPoint] {
        var cal = Calendar.current
        cal.firstWeekday = 2 // 周一起始
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: now) else { return [] }
        let labels = ["本周", "上周", "前2周", "前3周"]
        return (0..<4).reversed().enumerated().compactMap { index, weeksAgo in
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weeksAgo, to: thisWeek.start),
                  let week = cal.dateInterval(of: .weekOfYear, for: weekStart) else { return nil }
            let rev = performances
                .filter { $0.date >= week.start && $0.date < week.end }
                .reduce(0) { $0 + $1.amount }
            return TrendPoint(id: index, label: labels[weeksAgo], value: rev, date: week.start)
        }
    }

    /// 各周期唯一且真实的统计口径（V3.8 P1-B2）：
    /// - 日：近 7 日逐日（日粒度）
    /// - 周：近 4 周逐周汇总（周粒度）
    /// - 月：近 30 日逐日（日粒度 · 长窗口）
    static func points(for period: PerformanceChartPeriod, performances: [Performance], now: Date = Date()) -> [TrendPoint] {
        switch period {
        case .day:
            return last7Days(performances: performances, now: now)
        case .week:
            return last4Weeks(performances: performances, now: now)
        case .month:
            return last30Days(performances: performances, now: now)
        }
    }

    private static func points(performances: [Performance], days: Int, now: Date) -> [TrendPoint] {
        let cal = Calendar.current
        return (0..<days).reversed().enumerated().map { index, offset in
            let date = cal.date(byAdding: .day, value: -(days - 1 - index), to: now.startOfDay) ?? now
            let end = date.endOfDay
            let rev = performances.filter { $0.date >= date.startOfDay && $0.date <= end }.reduce(0) { $0 + $1.amount }
            let c = cal.dateComponents([.month, .day], from: date)
            return TrendPoint(
                id: index,
                label: "\(c.month ?? 0)/\(c.day ?? 0)",
                value: rev,
                date: date
            )
        }
    }
}


/// 合并记录行（营业额 + 支出，按日期倒序）
struct MoneyRecord: Identifiable {
    enum Kind { case income, expense }
    let id: ObjectIdentifier
    let kind: Kind
    let title: String
    let amount: Double
    let date: Date
    let source: String
    let performance: Performance?
    let expense: Expense?

    static func merged(performances: [Performance], expenses: [Expense], range: (start: Date, end: Date)) -> [MoneyRecord] {
        var records: [MoneyRecord] = []
        for p in performances where p.date >= range.start && p.date <= range.end {
            records.append(MoneyRecord(
                id: ObjectIdentifier(p),
                kind: .income,
                title: p.note.isBlank ? "营业额" : p.note,
                amount: p.amount,
                date: p.date,
                source: RecordSourceLabel.display(performance: p),
                performance: p,
                expense: nil
            ))
        }
        for e in expenses where e.date >= range.start && e.date <= range.end {
            records.append(MoneyRecord(
                id: ObjectIdentifier(e),
                kind: .expense,
                title: e.note.isBlank ? e.category : e.note,
                amount: e.amount,
                date: e.date,
                source: RecordSourceLabel.display(expense: e),
                performance: nil,
                expense: e
            ))
        }
        return records.sorted { $0.date > $1.date }
    }
}

extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
