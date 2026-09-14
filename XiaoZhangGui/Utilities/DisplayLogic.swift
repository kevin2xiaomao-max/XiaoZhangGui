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
        display(
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
        limit: Int = 5
    ) -> [HomeInboxItem] {
        var items: [HomeInboxItem] = []

        for todo in todos {
            let high = todo.priority >= TodoPriority.high.rawValue
            items.append(
                HomeInboxItem(
                    id: "todo-\(todo.notificationID)",
                    date: todo.dueDate ?? todo.createdAt,
                    rank: high ? 1 : 4,
                    time: todo.dueDate.map(Fmt.time) ?? "今天",
                    title: DisplayText.visible(todo.title, fallback: "待办事项"),
                    subtitle: DisplayText.visible(todo.detail, fallback: todo.priorityLevel.label),
                    tone: high ? .urgent : .normal,
                    route: .todo
                )
            )
        }

        for item in deliveries {
            let delivering = item.statusEnum == .delivering
            items.append(
                HomeInboxItem(
                    id: "delivery-\(item.notificationID)",
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
