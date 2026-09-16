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
}

enum PerformanceTrend {
    static func last7Days(performances: [Performance], now: Date = Date()) -> [TrendPoint] {
        points(performances: performances, days: 7, now: now)
    }

    static func last30Days(performances: [Performance], now: Date = Date()) -> [TrendPoint] {
        points(performances: performances, days: 30, now: now)
    }

    static func points(for period: PerformanceChartPeriod, performances: [Performance], now: Date = Date()) -> [TrendPoint] {
        switch period {
        case .day, .week:
            return last7Days(performances: performances, now: now)
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
