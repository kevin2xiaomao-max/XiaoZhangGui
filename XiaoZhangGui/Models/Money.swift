import Foundation
import SwiftData

/// 营业额记录（对齐 Android PerformanceEntity：amount/note/date）
/// 3.0：fingerprint 用于扫呗防重复；空字符串表示手工记录。
@Model
final class Performance {
    var amount: Double = 0
    var note: String = ""
    var date: Date = Date()
    var fingerprint: String = ""
    var paymentMethod: String = ""
    var orderNo: String = ""
    var importSource: String = ""

    init(
        amount: Double,
        note: String,
        date: Date,
        fingerprint: String = "",
        paymentMethod: String = "",
        orderNo: String = "",
        importSource: String = ""
    ) {
        self.amount = amount
        self.note = note
        self.date = date
        self.fingerprint = fingerprint
        self.paymentMethod = paymentMethod
        self.orderNo = orderNo
        self.importSource = importSource
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
