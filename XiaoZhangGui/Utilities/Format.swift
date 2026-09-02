import Foundation

// MARK: - 格式化工具（对齐 Android util/Format.kt）

enum Fmt {
    private static let moneyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        f.decimalSeparator = "."
        return f
    }()

    private static let intFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = ","
        return f
    }()

    /// ¥1,234.00
    static func money(_ value: Double) -> String {
        "¥" + (moneyFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value))
    }

    /// 千分位整数（Hero 大数字，如 11,500）
    static func groupedInt(_ value: Double) -> String {
        intFormatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    /// 千分位整数（Hero 大数字，如 11,500）
    static func groupedAmount(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? groupedInt(value)
            : (moneyFormatter.string(from: NSNumber(value: value)) ?? String(value))
    }

    static func formatDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN")))
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(Locale(identifier: "zh_CN")))
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().hour().minute().locale(Locale(identifier: "zh_CN")))
    }

    /// "X月X日 HH:mm"（待办截止等）
    static func monthDayTime(_ date: Date) -> String {
        let c = Calendar.current
        return "\(c.component(.month, from: date))月\(c.component(.day, from: date))日 \(time(date))"
    }

    /// "MM月dd日 HH:mm"（备忘卡片时间）
    static func memoTime(_ date: Date) -> String {
        let c = Calendar.current
        return String(format: "%02d月%02d日 %@", c.component(.month, from: date), c.component(.day, from: date), time(date))
    }

    /// "MM-dd HH:mm"（客户需求行）
    static func shortDateTime(_ date: Date) -> String {
        let c = Calendar.current
        return String(format: "%02d-%02d %@", c.component(.month, from: date), c.component(.day, from: date), time(date))
    }

    static func yyyyMMdd(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "zh_CN")))
    }
}
