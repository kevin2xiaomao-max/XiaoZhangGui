import Foundation

// MARK: - 日程时间轴派生层（V32）
//
// 设计约束（spec FR-14 / AC-5）：
// - timedEvents 只放真正需要按时间执行/查看的事项：
//   ① dueDate 含真实钟点（hour/minute 非全 0）的 Todo
//   ② CustomerDeliveryStorage 中真实存在 deliveryTime 的配送
// - 无具体时间的数据全部进全天分组（nil / 当天 00:00 的 Todo、临期、备忘、无配送时间客户单）
// - Performance / Expense 永不逐笔进入时间轴，只聚合为当日收入/支出/净额摘要
// - 本文件不包含任何常量钟点，也不新建数据库模型。

/// 定时事件
enum ScheduleEvent: Identifiable {
    case todo(Todo)
    case delivery(CustomerRequest, date: Date)

    var date: Date {
        switch self {
        case .todo(let todo): return todo.dueDate ?? .distantPast
        case .delivery(_, let date): return date
        }
    }

    var id: String {
        switch self {
        case .todo(let todo): return "todo-\(todo.notificationID)"
        case .delivery(let request, _): return "delivery-\(request.notificationID)"
        }
    }
}

/// 全天事项分组（无具体钟点）
struct ScheduleAllDay {
    var todos: [Todo]
    var deliveries: [CustomerRequest]
    var expiry: [ExpiryItem]
    var memos: [Memo]

    var isEmpty: Bool {
        todos.isEmpty && deliveries.isEmpty && expiry.isEmpty && memos.isEmpty
    }
}

/// 当日经营摘要（流水只聚合计数，不列明细）
struct ScheduleDaySummary {
    let revenue: Double
    let expense: Double
    var net: Double { revenue - expense }
}

struct ScheduleDay {
    let date: Date
    var timedEvents: [ScheduleEvent]
    var allDay: ScheduleAllDay
    let summary: ScheduleDaySummary

    var isEmpty: Bool {
        timedEvents.isEmpty && allDay.isEmpty
    }
}

enum ScheduleAgenda {
    /// 判断日期是否携带真实钟点（日期级 00:00 不算）
    static func hasClock(_ date: Date?) -> Bool {
        guard let date else { return false }
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) != 0 || (c.minute ?? 0) != 0
    }

    /// 由 CalendarAgenda.dayData 的聚合结果派生日程视图数据。
    /// - Parameters:
    ///   - data: 当天聚合数据（复用现有 CalendarAgenda，禁止另建模型）
    ///   - undatedTodos: 全部未完成且无截止时间的 Todo；仅在查看「今天」时由调用方传入，归入今天全天
    static func make(from data: CalendarDayData, undatedTodos: [Todo] = []) -> ScheduleDay {
        // 定时 / 全天 Todo
        var timedTodos: [Todo] = []
        var dayLevelTodos: [Todo] = []
        for todo in data.todos {
            if hasClock(todo.dueDate) {
                timedTodos.append(todo)
            } else {
                dayLevelTodos.append(todo)
            }
        }
        if data.date.isToday {
            dayLevelTodos.append(contentsOf: undatedTodos.filter { !$0.isCompleted && $0.dueDate == nil })
        }

        // 配送：有真实 deliveryTime 才定时；仅 createdAt 落在当天的归全天
        var timedDeliveries: [ScheduleEvent] = []
        var allDayDeliveries: [CustomerRequest] = []
        for request in data.customers {
            if let deliveryTime = CustomerDeliveryStorage.decode(request.customer).deliveryTime {
                timedDeliveries.append(.delivery(request, date: deliveryTime))
            } else {
                allDayDeliveries.append(request)
            }
        }

        let timedEvents = (timedTodos.map(ScheduleEvent.todo) + timedDeliveries)
            .sorted { $0.date < $1.date }

        let allDay = ScheduleAllDay(
            todos: dayLevelTodos.sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.createdAt < rhs.createdAt
            },
            deliveries: allDayDeliveries,
            expiry: data.expiry,
            memos: data.memos
        )

        return ScheduleDay(
            date: data.date,
            timedEvents: timedEvents,
            allDay: allDay,
            summary: ScheduleDaySummary(revenue: data.revenueTotal, expense: data.expenseTotal)
        )
    }

    /// b27 T20：把「当天的已完成 Todo」纯派生分类为 timed / all-day。
    /// 只看传入数据，不读数据库、不改 CalendarAgenda.dayData / eventFlags 口径。
    /// - 有真实钟点且与 selectedDate 同日 → timed
    /// - 日期级（00:00）且同日 → all-day
    /// - 无 dueDate → 仅当 selectedDate 是今天时进 all-day
    /// - 非当天一律不返回（不混入）；同一项只落一个桶，不重复
    static func completedTodosForDay(
        _ completedTodos: [Todo],
        date selectedDate: Date,
        calendar: Calendar = .current
    ) -> (timed: [ScheduleEvent], allDay: [Todo]) {
        var timed: [ScheduleEvent] = []
        var allDay: [Todo] = []
        for todo in completedTodos {
            if let due = todo.dueDate {
                if hasClock(due) {
                    if calendar.isDate(due, inSameDayAs: selectedDate) {
                        timed.append(.todo(todo))
                    }
                } else if calendar.isDate(due, inSameDayAs: selectedDate) {
                    allDay.append(todo)
                }
            } else if calendar.isDate(selectedDate, inSameDayAs: Date()) {
                allDay.append(todo)
            }
        }
        return (timed, allDay)
    }
}
