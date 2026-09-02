import Foundation

/// 经营助手只消费不可变快照，避免未来接入远端模型时直接暴露 SwiftData 对象。
struct BusinessAssistantInput {
    struct MoneyEntry {
        let amount: Double
        let date: Date
    }

    struct TodoEntry {
        let id: String
        let title: String
        let detail: String
        let dueDate: Date?
        let priority: Int
        let isCompleted: Bool
        let createdAt: Date
        let completedAt: Date?
    }

    struct MemoEntry {
        let id: String
        let title: String
        let content: String
        let createdAt: Date
    }

    struct CustomerEntry {
        let id: String
        let address: String
        let content: String
        let deliveryTime: Date?
        let createdAt: Date
        let status: CustomerStatus
    }

    struct ExpiryEntry {
        let id: String
        let name: String
        let quantity: Int
        let expiryDate: Date
        let status: ReturnStatus
    }

    let now: Date
    let monthGoal: Double
    let revenues: [MoneyEntry]
    let expenses: [MoneyEntry]
    let todos: [TodoEntry]
    let memos: [MemoEntry]
    let customers: [CustomerEntry]
    let expiryItems: [ExpiryEntry]
    let weather: WeatherSnapshot?

    init(
        now: Date = Date(),
        monthGoal: Double,
        performances: [Performance],
        expenses: [Expense],
        todos: [Todo],
        memos: [Memo],
        customers: [CustomerRequest],
        expiryItems: [ExpiryItem],
        weather: WeatherSnapshot?
    ) {
        self.now = now
        self.monthGoal = monthGoal
        revenues = performances.map { MoneyEntry(amount: $0.amount, date: $0.date) }
        self.expenses = expenses.map { MoneyEntry(amount: $0.amount, date: $0.date) }
        self.todos = todos.map {
            TodoEntry(
                id: $0.notificationID,
                title: $0.title,
                detail: $0.detail,
                dueDate: $0.dueDate,
                priority: $0.priority,
                isCompleted: $0.isCompleted,
                createdAt: $0.createdAt,
                completedAt: $0.completedAt
            )
        }
        self.memos = memos.map {
            MemoEntry(
                id: "\($0.createdAt.timeIntervalSince1970)-\($0.title)",
                title: $0.title,
                content: $0.content,
                createdAt: $0.createdAt
            )
        }
        self.customers = customers.map {
            let info = CustomerDeliveryStorage.decode($0.customer)
            return CustomerEntry(
                id: $0.notificationID,
                address: $0.roomOrAddress,
                content: $0.content,
                deliveryTime: info.deliveryTime,
                createdAt: $0.createdAt,
                status: $0.statusEnum
            )
        }
        self.expiryItems = expiryItems.map {
            ExpiryEntry(
                id: $0.notificationID,
                name: $0.name,
                quantity: $0.quantity,
                expiryDate: $0.expiryDate,
                status: $0.status
            )
        }
        self.weather = weather
    }
}

struct DailyBusinessSummary: Equatable {
    let statements: [String]

    var text: String {
        statements.isEmpty ? "今天还没有可总结的经营数据。" : statements.joined(separator: " ")
    }
}

enum BusinessInsightPriority: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: BusinessInsightPriority, rhs: BusinessInsightPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct BusinessInsight: Identifiable, Equatable {
    let id: String
    let message: String
    let priority: BusinessInsightPriority
    let symbolName: String
    let relevantDate: Date?
}

struct BusinessAssistantOutput: Equatable {
    let summary: DailyBusinessSummary
    let insights: [BusinessInsight]

    static let empty = BusinessAssistantOutput(
        summary: DailyBusinessSummary(statements: []),
        insights: []
    )
}

protocol DailyBusinessSummaryGenerating {
    func makeSummary(from input: BusinessAssistantInput) -> DailyBusinessSummary
}

protocol BusinessInsightGenerating {
    func makeInsights(from input: BusinessAssistantInput) -> [BusinessInsight]
}

/// 未来 OpenAI、其他 LLM 或本地模型可以实现此接口；V2.1 默认只使用本地实现。
protocol BusinessAssistantProviding {
    func analyze(_ input: BusinessAssistantInput) async throws -> BusinessAssistantOutput
}

struct LocalBusinessAssistantProvider: BusinessAssistantProviding {
    private let summaryEngine = LocalDailyBusinessSummaryEngine()
    private let insightEngine = LocalBusinessInsightEngine()

    func analyze(_ input: BusinessAssistantInput) async throws -> BusinessAssistantOutput {
        BusinessAssistantOutput(
            summary: summaryEngine.makeSummary(from: input),
            insights: insightEngine.makeInsights(from: input)
        )
    }
}

/// Home 只依赖统一门面；未来替换 provider 不需要修改 SwiftData 或页面结构。
struct BusinessAssistantEngine {
    private let provider: any BusinessAssistantProviding

    init(provider: any BusinessAssistantProviding = LocalBusinessAssistantProvider()) {
        self.provider = provider
    }

    func analyze(_ input: BusinessAssistantInput) async -> BusinessAssistantOutput {
        (try? await provider.analyze(input)) ?? .empty
    }
}

struct LocalDailyBusinessSummaryEngine: DailyBusinessSummaryGenerating {
    func makeSummary(from input: BusinessAssistantInput) -> DailyBusinessSummary {
        let calendar = Calendar.current
        let todayRevenue = input.revenues
            .filter { calendar.isDate($0.date, inSameDayAs: input.now) }
            .reduce(0) { $0 + $1.amount }
        let todayExpense = input.expenses
            .filter { calendar.isDate($0.date, inSameDayAs: input.now) }
            .reduce(0) { $0 + $1.amount }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: input.now) ?? input.now
        let yesterdayRevenue = input.revenues
            .filter { calendar.isDate($0.date, inSameDayAs: yesterday) }
            .reduce(0) { $0 + $1.amount }

        let completedTodos = input.todos.filter {
            $0.completedAt.map { calendar.isDate($0, inSameDayAs: input.now) } ?? false
        }.count
        let pendingTodayTodos = input.todos.filter {
            !$0.isCompleted && isTodayWork($0, now: input.now, calendar: calendar)
        }.count
        let pendingDeliveries = input.customers.filter {
            $0.status != .done && isTodayDelivery($0, now: input.now, calendar: calendar)
        }.count
        let urgentExpiry = input.expiryItems.filter {
            guard $0.status == .pending else { return false }
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: input.now),
                to: calendar.startOfDay(for: $0.expiryDate)
            ).day ?? Int.max
            return (0...1).contains(days)
        }.count
        let todayMemos = input.memos.filter { calendar.isDate($0.createdAt, inSameDayAs: input.now) }.count

        var statements: [String] = []

        if todayRevenue > 0 || todayExpense > 0 {
            var revenueText = "今日营业额 ¥\(Fmt.groupedInt(todayRevenue))"
            if yesterdayRevenue > 0 {
                let change = (todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100
                if abs(change) < 0.05 {
                    revenueText += "，与昨日基本持平"
                } else {
                    revenueText += String(format: "，较昨日%@ %.1f%%", change > 0 ? "增长" : "下降", abs(change))
                }
            }
            if todayExpense > 0 {
                revenueText += "，支出 ¥\(Fmt.groupedInt(todayExpense))，净额 ¥\(Fmt.groupedInt(todayRevenue - todayExpense))"
            }
            statements.append(revenueText + "。")
        }

        if completedTodos > 0 || pendingTodayTodos > 0 {
            var parts: [String] = []
            if completedTodos > 0 { parts.append("完成 \(completedTodos) 项待办") }
            if pendingTodayTodos > 0 { parts.append("还有 \(pendingTodayTodos) 项未完成") }
            statements.append(parts.joined(separator: "，") + "。")
        }

        if pendingDeliveries > 0 {
            statements.append("今天还有 \(pendingDeliveries) 单配送待处理。")
        }

        if urgentExpiry > 0 {
            statements.append("\(urgentExpiry) 件临时商品需要在明天前处理。")
        }

        if statements.count < 4, todayMemos > 0 {
            statements.append("今天新增了 \(todayMemos) 条经营记录。")
        }

        return DailyBusinessSummary(statements: Array(statements.prefix(4)))
    }

    private func isTodayWork(_ todo: BusinessAssistantInput.TodoEntry, now: Date, calendar: Calendar) -> Bool {
        if let dueDate = todo.dueDate { return calendar.isDate(dueDate, inSameDayAs: now) }
        return calendar.isDate(todo.createdAt, inSameDayAs: now)
    }

    private func isTodayDelivery(_ customer: BusinessAssistantInput.CustomerEntry, now: Date, calendar: Calendar) -> Bool {
        if let deliveryTime = customer.deliveryTime { return calendar.isDate(deliveryTime, inSameDayAs: now) }
        return calendar.isDate(customer.createdAt, inSameDayAs: now)
    }
}

struct LocalBusinessInsightEngine: BusinessInsightGenerating {
    func makeInsights(from input: BusinessAssistantInput) -> [BusinessInsight] {
        let calendar = Calendar.current
        var insights: [BusinessInsight] = []

        let overdue = input.todos.filter {
            guard !$0.isCompleted, let due = $0.dueDate else { return false }
            return due < input.now
        }
        if !overdue.isEmpty {
            insights.append(BusinessInsight(
                id: "todo-overdue",
                message: "有 \(overdue.count) 件待办已经逾期，可以优先处理。",
                priority: .high,
                symbolName: "clock.badge.exclamationmark",
                relevantDate: overdue.compactMap(\.dueDate).min()
            ))
        }

        let importantToday = input.todos.filter {
            !$0.isCompleted && $0.priority >= TodoPriority.high.rawValue && isToday($0.dueDate ?? $0.createdAt, input.now, calendar)
        }
        if !importantToday.isEmpty {
            insights.append(BusinessInsight(
                id: "todo-important-today",
                message: "今天还有 \(importantToday.count) 件重要待办未完成。",
                priority: .medium,
                symbolName: "checklist",
                relevantDate: importantToday.compactMap(\.dueDate).min()
            ))
        }

        if let upcomingTodo = input.todos
            .filter({
                guard !$0.isCompleted, let due = $0.dueDate else { return false }
                let interval = due.timeIntervalSince(input.now)
                return interval >= 0 && interval <= 2 * 60 * 60
            })
            .sorted(by: { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) })
            .first,
           let due = upcomingTodo.dueDate {
            insights.append(BusinessInsight(
                id: "todo-upcoming-\(upcomingTodo.id)",
                message: "\(Fmt.time(due)) 要做“\(upcomingTodo.title)”。",
                priority: .medium,
                symbolName: "timer",
                relevantDate: due
            ))
        }

        let activeDeliveries = input.customers.filter { $0.status != .done }
        var hasSpecificDeliveryInsight = false
        if let lateDelivery = activeDeliveries
            .filter({ ($0.deliveryTime ?? .distantFuture) < input.now })
            .sorted(by: { ($0.deliveryTime ?? .distantFuture) < ($1.deliveryTime ?? .distantFuture) })
            .first,
           let time = lateDelivery.deliveryTime {
            insights.append(BusinessInsight(
                id: "delivery-late-\(lateDelivery.id)",
                message: "\(nonEmpty(lateDelivery.address) ?? "一单配送") 已超过原定 \(Fmt.time(time))，可以确认一下进度。",
                priority: .high,
                symbolName: "shippingbox.and.arrow.backward.fill",
                relevantDate: time
            ))
            hasSpecificDeliveryInsight = true
        } else if let upcomingDelivery = activeDeliveries
            .filter({
                guard let time = $0.deliveryTime else { return false }
                let interval = time.timeIntervalSince(input.now)
                return interval >= 0 && interval <= 3 * 60 * 60
            })
            .sorted(by: { ($0.deliveryTime ?? .distantFuture) < ($1.deliveryTime ?? .distantFuture) })
            .first,
                  let time = upcomingDelivery.deliveryTime {
            insights.append(BusinessInsight(
                id: "delivery-upcoming-\(upcomingDelivery.id)",
                message: "\(Fmt.time(time)) 有一单 \(nonEmpty(upcomingDelivery.address) ?? "客户") 配送。",
                priority: .medium,
                symbolName: "shippingbox.fill",
                relevantDate: time
            ))
            hasSpecificDeliveryInsight = true
        }

        if !hasSpecificDeliveryInsight {
            let todayDeliveryCount = activeDeliveries.filter { customer in
                isToday(customer.deliveryTime ?? customer.createdAt, input.now, calendar)
            }.count
            if todayDeliveryCount > 0 {
                insights.append(BusinessInsight(
                    id: "delivery-today",
                    message: "今天还有 \(todayDeliveryCount) 单客户配送待处理。",
                    priority: .medium,
                    symbolName: "shippingbox.fill",
                    relevantDate: nil
                ))
            }
        }

        let pendingExpiry = input.expiryItems.filter { $0.status == .pending }
        if let urgentItem = pendingExpiry
            .map({ ($0, daysUntil($0.expiryDate, from: input.now, calendar: calendar)) })
            .filter({ $0.1 <= 1 })
            .sorted(by: { $0.1 < $1.1 })
            .first {
            let timing: String
            switch urgentItem.1 {
            case ..<0: timing = "已经到期"
            case 0: timing = "今天需要处理"
            default: timing = "明天需要退货或处理"
            }
            insights.append(BusinessInsight(
                id: "expiry-urgent-\(urgentItem.0.id)",
                message: "\(urgentItem.0.name)\(timing)。",
                priority: urgentItem.1 < 0 ? .high : .medium,
                symbolName: "exclamationmark.triangle.fill",
                relevantDate: urgentItem.0.expiryDate
            ))
        } else {
            let upcomingCount = pendingExpiry.filter {
                (2...3).contains(daysUntil($0.expiryDate, from: input.now, calendar: calendar))
            }.count
            if upcomingCount > 0 {
                insights.append(BusinessInsight(
                    id: "expiry-upcoming",
                    message: "未来 3 天有 \(upcomingCount) 件临时商品需要留意。",
                    priority: .medium,
                    symbolName: "calendar.badge.clock",
                    relevantDate: nil
                ))
            }
        }

        appendRevenueInsight(input: input, calendar: calendar, to: &insights)
        appendMemoInsight(input: input, calendar: calendar, to: &insights)
        appendWeatherInsight(input: input, to: &insights)

        var seenIDs = Set<String>()
        var seenMessages = Set<String>()
        return insights
            .sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return ($0.relevantDate ?? .distantFuture) < ($1.relevantDate ?? .distantFuture)
            }
            .filter { insight in
                seenIDs.insert(insight.id).inserted && seenMessages.insert(insight.message).inserted
            }
    }

    private func appendRevenueInsight(input: BusinessAssistantInput, calendar: Calendar, to insights: inout [BusinessInsight]) {
        guard input.monthGoal > 0,
              calendar.component(.hour, from: input.now) >= 18 else { return }

        let todayRevenue = input.revenues
            .filter { isToday($0.date, input.now, calendar) }
            .reduce(0) { $0 + $1.amount }
        let dailyGoal = input.monthGoal / 30
        guard todayRevenue < dailyGoal * 0.6 else { return }

        let recentDates = (1...7).compactMap { calendar.date(byAdding: .day, value: -$0, to: input.now) }
        let dailyValues = recentDates.map { date in
            input.revenues.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.amount }
        }.filter { $0 > 0 }
        let recentAverage = dailyValues.isEmpty ? nil : dailyValues.reduce(0, +) / Double(dailyValues.count)

        let message: String
        if let recentAverage, todayRevenue < recentAverage * 0.7 {
            message = "今天营业额低于近期平均，可以稍后再关注经营变化。"
        } else {
            message = "今天营业额与日均目标还有一些差距，可以稍后再关注。"
        }
        insights.append(BusinessInsight(
            id: "revenue-gap",
            message: message,
            priority: .low,
            symbolName: "chart.line.downtrend.xyaxis",
            relevantDate: nil
        ))
    }

    private func appendMemoInsight(input: BusinessAssistantInput, calendar: Calendar, to insights: inout [BusinessInsight]) {
        let keywords = ["重要", "注意", "记得", "维修", "调价", "供应商"]
        guard let memo = input.memos
            .filter({ isToday($0.createdAt, input.now, calendar) })
            .first(where: { item in
                let text = item.title + item.content
                return keywords.contains { text.contains($0) }
            }) else { return }

        let text = nonEmpty(memo.title) ?? memo.content
        insights.append(BusinessInsight(
            id: "memo-important-\(memo.id)",
            message: "今天的记录里提到：\(text)。",
            priority: .low,
            symbolName: "note.text",
            relevantDate: memo.createdAt
        ))
    }

    private func appendWeatherInsight(input: BusinessAssistantInput, to insights: inout [BusinessInsight]) {
        guard let weather = input.weather, !weather.isStale else { return }
        if weather.isRaining || (weather.precipitationProbability ?? 0) >= 0.6 {
            insights.append(BusinessInsight(
                id: "weather-rain-\(weather.observedAt.startOfDay.timeIntervalSince1970)",
                message: "当前有降雨，安排配送时可以多留意路况。",
                priority: .low,
                symbolName: "cloud.rain.fill",
                relevantDate: weather.observedAt
            ))
        } else if weather.temperature >= 34 {
            insights.append(BusinessInsight(
                id: "weather-heat-\(weather.observedAt.startOfDay.timeIntervalSince1970)",
                message: "今天气温较高，可以关注饮料和冰品销售。",
                priority: .low,
                symbolName: "thermometer.sun.fill",
                relevantDate: weather.observedAt
            ))
        }
    }

    private func isToday(_ date: Date, _ now: Date, _ calendar: Calendar) -> Bool {
        calendar.isDate(date, inSameDayAs: now)
    }

    private func daysUntil(_ date: Date, from now: Date, calendar: Calendar) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day ?? Int.max
    }

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
