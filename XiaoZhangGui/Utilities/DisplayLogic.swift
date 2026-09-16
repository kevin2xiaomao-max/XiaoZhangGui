import Foundation

enum DisplayText {
    static func visible(_ value: String, fallback: String = "") -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || isEncoded(trimmed) { return fallback }
        return trimmed
    }

    static func isEncoded(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.hasPrefix("xzg-") { return true }
        if lower.contains("xzg-delivery-v1:") { return true }
        if trimmed.count >= 32,
           trimmed.range(of: #"^[A-Za-z0-9+/=]+$"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    static func joined(_ parts: String..., separator: String = " · ") -> String {
        parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isEncoded($0) }
            .joined(separator: separator)
    }
}

enum Greeting {
    static func phrase(at date: Date = Date(), owner: String) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let prefix: String
        if hour < 11 {
            prefix = "早上好"
        } else if hour < 14 {
            prefix = "中午好"
        } else if hour < 18 {
            prefix = "下午好"
        } else {
            prefix = "晚上好"
        }
        let name = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? prefix : "\(prefix)，\(name)"
    }
}

// MARK: - 全天 / 时间统一语义（P1-3）
// 单一规则来源：ScheduleAgenda.hasClock（nil / 当天 00:00 = 全天）。
// 首页、待办、日历的时间标签一律通过本 helper 输出，
// 保证全天事项在任何页面都不会出现 00:00。
enum DayTimeLabel {
    /// 是否携带真实钟点（日期级 00:00 不算）
    static func hasClock(_ date: Date?) -> Bool {
        ScheduleAgenda.hasClock(date)
    }

    /// 统一时间标签：
    /// - nil → unscheduledText（各页面按自身语义传入，如「待安排」「全天」）
    /// - 当天无钟点 → 「全天」
    /// - 非当天无钟点 → 「M月d日」
    /// - 当天有钟点 → HH:mm
    /// - 非当天有钟点 → 「M月d日 HH:mm」
    static func label(_ date: Date?, unscheduledText: String) -> String {
        guard let date else { return unscheduledText }
        if hasClock(date) {
            return date.isToday ? Fmt.time(date) : Fmt.monthDayTime(date)
        }
        return date.isToday ? "全天" : Fmt.monthDay(date)
    }
}

enum RecordSourceLabel {
    static func display(
        importSource: String = "",
        paymentMethod: String = "",
        note: String = "",
        category: String? = nil
    ) -> String {
        let fields = [importSource, paymentMethod, note, category ?? ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let blob = fields.joined(separator: " ").lowercased()
        if blob.contains("扫呗") || blob.contains("saobei") { return "扫呗" }

        let banned: Set<String> = ["", "其他", "other", "收入", "营业额", "支出"]
        if let category {
            let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
            if !banned.contains(trimmed) && trimmed.lowercased() != "other" {
                return trimmed
            }
        }

        for field in fields where !banned.contains(field) && field.lowercased() != "other" {
            if field == "手动" { return "手动" }
            if field == "门店" || field == "美团" { return field }
        }

        return "手动"
    }

    static func display(performance: Performance) -> String {
        // P0-3：优先看独立 incomeSource 字段
        let stored = performance.incomeSource.trimmingCharacters(in: .whitespacesAndNewlines)
        if stored == "门店" || stored == "美团" {
            return stored
        }
        return display(
            importSource: performance.importSource,
            paymentMethod: performance.paymentMethod,
            note: performance.note
        )
    }

    static func display(expense: Expense) -> String {
        display(note: expense.note, category: expense.category)
    }
}

struct HomeInboxItem: Identifiable, Equatable {
    enum Route: String {
        case todo, customer, expiry
    }

    enum Tone: String {
        case normal, accent, warning, urgent
    }

    let id: String
    let date: Date
    let rank: Int
    let time: String
    let title: String
    let subtitle: String
    let tone: Tone
    let route: Route
}

enum HomeInbox {
    static func items(
        todos: [Todo],
        deliveries: [CustomerRequest],
        expiryItems: [ExpiryItem],
        limit: Int = 4,
        excludingDeliveryIDs: Set<String> = []
    ) -> [HomeInboxItem] {
        var items: [HomeInboxItem] = []

        for todo in todos {
            let high = todo.priority >= TodoPriority.high.rawValue
            items.append(
                HomeInboxItem(
                    id: "todo-\(todo.notificationID)",
                    date: todo.dueDate ?? todo.createdAt,
                    rank: high ? 1 : 4,
                    // P1-3：nil / 00:00 → 全天，不再出现 00:00
                    time: DayTimeLabel.label(todo.dueDate, unscheduledText: "全天"),
                    title: DisplayText.visible(todo.title, fallback: "待办事项"),
                    subtitle: DisplayText.visible(todo.detail, fallback: todo.priorityLevel.label),
                    tone: high ? .urgent : .normal,
                    route: .todo
                )
            )
        }

        for item in deliveries {
            let inboxID = "delivery-\(item.notificationID)"
            if excludingDeliveryIDs.contains(inboxID) { continue }
            let delivering = item.statusEnum == .delivering
            items.append(
                HomeInboxItem(
                    id: inboxID,
                    date: item.updatedAt,
                    rank: delivering ? 2 : 3,
                    time: delivering ? "配送中" : "配送",
                    title: item.displayTitle,
                    subtitle: item.displaySubtitle,
                    tone: delivering ? .accent : .normal,
                    route: .customer
                )
            )
        }

        for item in expiryItems {
            let days = item.daysLeft()
            let rank: Int
            let tone: HomeInboxItem.Tone
            if days < 0 {
                rank = 0
                tone = .urgent
            } else if days == 0 {
                rank = 0
                tone = .urgent
            } else if days <= 1 {
                rank = 2
                tone = .warning
            } else {
                rank = 5
                tone = .warning
            }
            items.append(
                HomeInboxItem(
                    id: "expiry-\(item.notificationID)",
                    date: item.expiryDate,
                    rank: rank,
                    time: days <= 0 ? "今天" : "\(days)天",
                    title: "\(DisplayText.visible(item.name, fallback: "临期商品")) × \(item.quantity)",
                    subtitle: days < 0 ? "已临期" : days == 0 ? "今天临期" : "即将临期",
                    tone: tone,
                    route: .expiry
                )
            )
        }

        return items
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                return lhs.date < rhs.date
            }
            .prefix(limit)
            .map { $0 }
    }
}
