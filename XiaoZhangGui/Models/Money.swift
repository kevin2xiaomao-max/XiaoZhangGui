import Foundation
import SwiftData

/// 营业额记录（对齐 Android PerformanceEntity：amount/note/date）
/// 注意：无"门店/美团来源"字段，禁止伪造渠道拆分
@Model
final class Performance {
    var amount: Double = 0
    var note: String = ""
    var date: Date = Date()

    init(amount: Double, note: String, date: Date) {
        self.amount = amount
        self.note = note
        self.date = date
    }
}

/// 支出记录（对齐 Android ExpenseEntity：amount/category/note/date/createdAt）
@Model
final class Expense {
    var amount: Double = 0
    var category: String = "其他"
    var note: String = ""
    var date: Date = Date()
    var createdAt: Date = Date()

    init(amount: Double, category: String = "其他", note: String = "", date: Date, createdAt: Date = Date()) {
        self.amount = amount
        self.category = category
        self.note = note
        self.date = date
        self.createdAt = createdAt
    }
}
