import Foundation

// MARK: - 日期扩展（业务日期判断）

extension Date {
    /// 当天 0 点
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? self
    }

    /// 本月 1 号 0 点
    var startOfMonth: Date {
        let c = Calendar.current
        let comps = c.dateComponents([.year, .month], from: self)
        return c.date(from: comps) ?? self
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    /// 与参考日期相差整天数（正 = 未来，负 = 过去）
    func days(from reference: Date = Date()) -> Int {
        Calendar.current.dateComponents(
            [.day],
            from: reference.startOfDay,
            to: startOfDay
        ).day ?? 0
    }

    /// 时间段分组（待办时间轴）：上午 0-12 / 下午 12-18 / 晚上 18-24
    enum DayPeriod {
        case morning, afternoon, evening
    }

    var dayPeriod: DayPeriod {
        let hour = Calendar.current.component(.hour, from: self)
        if hour < 12 { return .morning }
        if hour < 18 { return .afternoon }
        return .evening
    }
}

extension Date.DayPeriod {
    var label: String {
        switch self {
        case .morning: return "上午"
        case .afternoon: return "下午"
        case .evening: return "晚上"
        }
    }
}
