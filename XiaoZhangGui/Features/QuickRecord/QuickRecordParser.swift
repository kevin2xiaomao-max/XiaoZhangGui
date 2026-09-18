import Foundation

enum QuickRecordKind: String, Equatable, CaseIterable {
    case performance
    case todo
    case customer
    case expiry
    case memo
}

struct QuickRecordDraft: Equatable {
    var kind: QuickRecordKind
    var title: String
    var amount: Double?
    var date: Date?
    var quantity: Int?
    var customer: String?
    var note: String
    var raw: String

    var summary: String {
        switch kind {
        case .performance:
            return "记入业绩 \(Fmt.money(amount ?? 0))"
        case .todo:
            return date.map { "待办 · \(Fmt.monthDayTime($0))" } ?? "待办"
        case .customer:
            return "客户配送 · \(customer ?? title)"
        case .expiry:
            return "临时商品 · \(title)"
        case .memo:
            return "备忘"
        }
    }
}

/// 本地规则解析。以后 AI 只需实现 `QuickRecordParsing`。
protocol QuickRecordParsing {
    func parse(_ text: String, now: Date) -> QuickRecordDraft
}

struct LocalQuickRecordParser: QuickRecordParsing {
    func parse(_ text: String, now: Date = Date()) -> QuickRecordDraft {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let date = DatePhraseParser.parse(trimmed, now: now)
        let amount = AmountPhraseParser.parse(trimmed)
        let quantity = QuantityPhraseParser.parse(trimmed)

        // V3.3 真机 hotfix 定稿的分流顺序：
        // 1) 营业额 → 2) 待办 → 3) 配送 → 4) 临时商品 → 5) 备忘兜底。
        // 任何规则都识别不了的非空句子一律落「备忘」，保证用户的每一句话都能保存。
        if isPerformance(trimmed, amount: amount) {
            return QuickRecordDraft(
                kind: .performance,
                title: "营业额",
                amount: amount,
                date: date ?? now,
                quantity: nil,
                customer: nil,
                note: trimmed,
                raw: trimmed
            )
        }
        if isTodo(trimmed) {
            return QuickRecordDraft(
                kind: .todo,
                title: trimmed,
                amount: nil,
                date: date,
                quantity: nil,
                customer: nil,
                note: trimmed,
                raw: trimmed
            )
        }
        if isCustomer(trimmed) {
            return QuickRecordDraft(
                kind: .customer,
                title: trimmed,
                amount: nil,
                date: date,
                quantity: nil,
                customer: customerName(from: trimmed) ?? "客户",
                note: trimmed,
                raw: trimmed
            )
        }
        if isExpiry(trimmed) {
            return QuickRecordDraft(
                kind: .expiry,
                title: expiryName(from: trimmed),
                amount: nil,
                date: date ?? Calendar.current.date(byAdding: .day, value: 1, to: now),
                quantity: quantity ?? 1,
                customer: nil,
                note: trimmed,
                raw: trimmed
            )
        }
        // 兜底：非空但无法识别（如「卡卡卡卡卡卡」「供应商周五过来」）→ 备忘
        return QuickRecordDraft(
            kind: .memo,
            title: String(trimmed.prefix(20)),
            amount: nil,
            date: date,
            quantity: nil,
            customer: nil,
            note: trimmed,
            raw: trimmed
        )
    }

    private func isPerformance(_ text: String, amount: Double?) -> Bool {
        amount != nil && Self.revenueSignals.contains(where: text.contains)
    }

    /// 金额 +（营收词 / 收款渠道词）即判定营业额，覆盖「今天美团680」这类口语。
    private static let revenueSignals = [
        "营业额", "营收", "收入", "卖了", "收款", "入账", "进账",
        "美团", "饿了么", "抖音", "团购", "外卖", "收钱吧",
    ]

    /// 明确的动作 / 待办信号（不含「送」：配送在下一步单独识别）。
    private static let todoSignals = [
        "联系", "打电话", "回电", "通话",
        "买", "进货", "进", "拿货", "提货", "订货", "下单", "补货", "上架",
        "整理", "打扫", "清理", "盘点", "对账", "核对", "清点",
        "催", "取货", "取件", "寄", "发货", "送修", "维修", "修一下",
        "预约", "安装", "搬", "交费", "交班", "带", "办理",
        "准备", "安排", "检查", "打印", "复印", "报名", "提醒",
    ]

    private func isTodo(_ text: String) -> Bool {
        Self.todoSignals.contains(where: text.contains)
    }

    private func isCustomer(_ text: String) -> Bool {
        if ["配送", "送货", "送到", "客户"].contains(where: text.contains) {
            return true
        }
        // 「给302送…」「给张老板送…」这类房号 / 人称配送口语
        return text.range(of: #"给[^，。；\s]{0,12}送"#, options: .regularExpression) != nil
    }

    private func isExpiry(_ text: String) -> Bool {
        ["退货", "临期", "过期", "到期"].contains(where: text.contains)
    }

    private func customerName(from text: String) -> String? {
        var cleaned = text
        for token in ["今天", "明天", "后天", "月底"] {
            cleaned = cleaned.replacingOccurrences(of: token, with: "")
        }
        // 优先：给302送… / 给张老板送…
        if let regex = try? NSRegularExpression(pattern: #"给\s*([^\s，。；]{1,12}?)\s*送"#),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           let range = Range(match.range(at: 1), in: cleaned) {
            return String(cleaned[range])
        }
        if let match = cleaned.range(of: #"([一-龥A-Za-z0-9]{1,8})(老板|别墅|房|店)"#, options: .regularExpression) {
            return String(cleaned[match])
        }
        return nil
    }

    private func expiryName(from text: String) -> String {
        let stripped = text
            .replacingOccurrences(of: "退货", with: "")
            .replacingOccurrences(of: "临期", with: "")
            .replacingOccurrences(of: "月底", with: "")
            .replacingOccurrences(of: "明天", with: "")
            .replacingOccurrences(of: "后天", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? "临时商品" : stripped
    }
}

enum AmountPhraseParser {
    static func parse(_ text: String) -> Double? {
        if let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)(?:元|块|块钱)?"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            if let value = Double(text[range]), value > 0 { return value }
        }
        if let chinese = text.range(of: #"[一二三四五六七八九十百千万两零]+"# , options: .regularExpression) {
            if let value = ChineseNumber.parse(String(text[chinese])), value > 0 {
                return Double(value)
            }
        }
        return nil
    }
}

enum QuantityPhraseParser {
    static func parse(_ text: String) -> Int? {
        if let regex = try? NSRegularExpression(pattern: #"(\d+)\s*(箱|件|瓶|袋|个|份)"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return Int(text[range])
        }
        if text.contains("两箱") { return 2 }
        return nil
    }
}

enum DatePhraseParser {
    static func parse(_ text: String, now: Date) -> Date? {
        let cal = Calendar.current
        var date = now
        var matched = false

        if text.contains("今天") { date = now; matched = true }
        if text.contains("明天") {
            date = cal.date(byAdding: .day, value: 1, to: now) ?? now
            matched = true
        }
        if text.contains("后天") {
            date = cal.date(byAdding: .day, value: 2, to: now) ?? now
            matched = true
        }
        if text.contains("月底") {
            let start = now.startOfMonth
            if let next = cal.date(byAdding: .month, value: 1, to: start),
               let last = cal.date(byAdding: .day, value: -1, to: next) {
                date = last
                matched = true
            }
        }
        if let weekday = weekdayOffset(in: text, from: now) {
            date = weekday
            matched = true
        }
        if let time = parseTime(text, on: date) {
            date = time
            matched = true
        }
        return matched ? date : nil
    }

    private static func weekdayOffset(in text: String, from now: Date) -> Date? {
        let map: [(String, Int)] = [
            ("周一", 2), ("星期一", 2), ("周二", 3), ("星期二", 3),
            ("周三", 4), ("星期三", 4), ("周四", 5), ("星期四", 5),
            ("周五", 6), ("星期五", 6), ("周六", 7), ("星期六", 7),
            ("周日", 1), ("周天", 1), ("星期日", 1),
        ]
        guard let pair = map.first(where: { text.contains($0.0) }) else { return nil }
        var cal = Calendar.current
        cal.firstWeekday = 1
        let current = cal.component(.weekday, from: now)
        var delta = pair.1 - current
        if delta < 0 { delta += 7 }
        if delta == 0 { delta = 7 }
        return cal.date(byAdding: .day, value: delta, to: now.startOfDay)
    }

    private static func parseTime(_ text: String, on date: Date) -> Date? {
        let cal = Calendar.current
        if let regex = try? NSRegularExpression(pattern: #"(上午|下午|晚上)?\s*(\d{1,2})(?:点|:|：)(\d{1,2})?"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let period = range(match.range(at: 1), in: text).map { String(text[$0]) } ?? ""
            guard let hourRange = range(match.range(at: 2), in: text),
                  var hour = Int(text[hourRange]) else { return nil }
            let minute = range(match.range(at: 3), in: text).flatMap { Int(text[$0]) } ?? 0
            if period.contains("下午") || period.contains("晚上"), hour < 12 { hour += 12 }
            if period.contains("上午"), hour == 12 { hour = 0 }
            var comps = cal.dateComponents([.year, .month, .day], from: date)
            comps.hour = hour
            comps.minute = minute
            return cal.date(from: comps)
        }
        return nil
    }

    private static func range(_ ns: NSRange, in text: String) -> Range<String.Index>? {
        guard ns.location != NSNotFound else { return nil }
        return Range(ns, in: text)
    }
}
