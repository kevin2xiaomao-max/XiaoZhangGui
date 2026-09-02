import Foundation

// MARK: - 日历派生数据（语义对齐 Android CalendarViewModel / CalendarDayData）
// 聚合：营业额 + 待办 + 临期 + 客户需求（02 文档要求）

struct CalendarDayData {
    let date: Date
    /// 当日未完成待办
    var todos: [Todo] = []
    var revenues: [Performance] = []
    var expenses: [Expense] = []
    /// 当日到期（待处理）
    var expiry: [ExpiryItem] = []
    /// 当日新增客户需求
    var customers: [CustomerRequest] = []
    var memos: [Memo] = []

    var revenueTotal: Double { revenues.reduce(0) { $0 + $1.amount } }
    var expenseTotal: Double { expenses.reduce(0) { $0 + $1.amount } }
}

enum CalendarAgenda {
    /// 汇总某日的所有业务数据
    static func dayData(
        date: Date,
        todos: [Todo],
        performances: [Performance],
        expenses: [Expense],
        expiryItems: [ExpiryItem],
        customers: [CustomerRequest],
        memos: [Memo] = []
    ) -> CalendarDayData {
        var data = CalendarDayData(date: date)
        data.todos = todos.filter { !$0.isCompleted && $0.dueDate?.isSameDay(as: date) == true }
        data.revenues = performances.filter { $0.date.isSameDay(as: date) }
        data.expenses = expenses.filter { $0.date.isSameDay(as: date) }
        data.expiry = expiryItems.filter { $0.status == .pending && $0.expiryDate.isSameDay(as: date) }
        data.customers = customers.filter {
            let deliveryDate = CustomerDeliveryStorage.decode($0.customer).deliveryTime ?? $0.createdAt
            return deliveryDate.isSameDay(as: date)
        }
        data.memos = memos.filter { $0.createdAt.isSameDay(as: date) }
        return data
    }

    /// 某日是否有事件（用于日期状态点）
    struct EventFlags {
        var hasRevenue = false   // 绿
        var hasTodo = false      // 蓝
        var hasExpiry = false    // 橙
        var hasCustomer = false  // 灰
        var hasMemo = false
    }

    static func eventFlags(
        date: Date,
        todos: [Todo],
        performances: [Performance],
        expenses: [Expense],
        expiryItems: [ExpiryItem],
        customers: [CustomerRequest],
        memos: [Memo]
    ) -> EventFlags {
        EventFlags(
            hasRevenue: performances.contains { $0.date.isSameDay(as: date) } || expenses.contains { $0.date.isSameDay(as: date) },
            hasTodo: todos.contains { $0.dueDate?.isSameDay(as: date) == true },
            hasExpiry: expiryItems.contains { $0.status == .pending && $0.expiryDate.isSameDay(as: date) },
            hasCustomer: customers.contains {
                let deliveryDate = CustomerDeliveryStorage.decode($0.customer).deliveryTime ?? $0.createdAt
                return deliveryDate.isSameDay(as: date)
            },
            hasMemo: memos.contains { $0.createdAt.isSameDay(as: date) }
        )
    }
}
