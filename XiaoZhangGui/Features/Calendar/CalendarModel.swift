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
        var revenueCount = 0
        var todoCount = 0
        var expiryCount = 0
        var customerCount = 0
        var memoCount = 0

        var hasRevenue: Bool { revenueCount > 0 }   // 绿
        var hasTodo: Bool { todoCount > 0 }         // 蓝
        var hasExpiry: Bool { expiryCount > 0 }     // 橙
        var hasCustomer: Bool { customerCount > 0 } // 灰
        var hasMemo: Bool { memoCount > 0 }

        var accessibilitySummary: String {
            var parts: [String] = []
            if revenueCount > 0 { parts.append("收支 \(revenueCount) 笔") }
            if todoCount > 0 { parts.append("待办 \(todoCount) 项") }
            if expiryCount > 0 { parts.append("临期 \(expiryCount) 项") }
            if customerCount > 0 { parts.append("配送 \(customerCount) 项") }
            if memoCount > 0 { parts.append("记录 \(memoCount) 条") }
            return parts.isEmpty ? "无事项" : parts.joined(separator: "，")
        }
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
            revenueCount: performances.filter { $0.date.isSameDay(as: date) }.count
                + expenses.filter { $0.date.isSameDay(as: date) }.count,
            todoCount: todos.filter { $0.dueDate?.isSameDay(as: date) == true }.count,
            expiryCount: expiryItems.filter { $0.status == .pending && $0.expiryDate.isSameDay(as: date) }.count,
            customerCount: customers.filter {
                let deliveryDate = CustomerDeliveryStorage.decode($0.customer).deliveryTime ?? $0.createdAt
                return deliveryDate.isSameDay(as: date)
            }.count,
            memoCount: memos.filter { $0.createdAt.isSameDay(as: date) }.count
        )
    }
}
