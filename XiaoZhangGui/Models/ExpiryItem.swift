import Foundation
import SwiftData
import SwiftUI

/// 临期/退货商品（对齐 Android ExpiryItemEntity 真实字段）
@Model
final class ExpiryItem {
    var name: String = ""
    var category: String = ""
    var quantity: Int = 1
    var productionDate: Date?
    var expiryDate: Date = Date()
    /// 提前提醒天数
    var remindDaysBefore: Int = 7
    var note: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date = Date()
    /// "待处理" / "已退货"
    var returnStatus: String = ReturnStatus.pending.rawValue
    var returnedAt: Date?
    /// 稳定通知标识（UUID v4）；SwiftData 给旧记录填充默认值，迁移安全。
    var notificationID: String = UUID().uuidString

    init(
        name: String,
        category: String = "",
        quantity: Int = 1,
        productionDate: Date? = nil,
        expiryDate: Date,
        remindDaysBefore: Int = 7,
        note: String = "",
        imageData: Data? = nil,
        createdAt: Date = Date(),
        returnStatus: String = ReturnStatus.pending.rawValue,
        returnedAt: Date? = nil,
        notificationID: String? = nil
    ) {
        self.name = name
        self.category = category
        self.quantity = quantity
        self.productionDate = productionDate
        self.expiryDate = expiryDate
        self.remindDaysBefore = remindDaysBefore
        self.note = note
        self.imageData = imageData
        self.createdAt = createdAt
        self.returnStatus = returnStatus
        self.returnedAt = returnedAt
        self.notificationID = notificationID ?? UUID().uuidString
    }
}

/// 退货状态
enum ReturnStatus: String {
    case pending = "待处理"
    case returned = "已退货"
}

extension ExpiryItem {
    var status: ReturnStatus {
        get { ReturnStatus(rawValue: returnStatus) ?? .pending }
        set {
            returnStatus = newValue.rawValue
            returnedAt = newValue == .returned ? Date() : nil
        }
    }

    /// 距到期天数（到期日 0 点计算，负数表示已过期）
    func daysLeft(from reference: Date = Date()) -> Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: reference),
            to: Calendar.current.startOfDay(for: expiryDate)
        ).day ?? 0
    }
}

/// 客户需求（对齐 Android CustomerRequestEntity 真实字段；不做 CRM）
@Model
final class CustomerRequest {
    var customer: String = ""
    var roomOrAddress: String = ""
    var phone: String = ""
    var content: String = ""
    /// "待处理" / "配送中" / "已完成"
    var status: String = CustomerStatus.pending.rawValue
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// 稳定通知标识（UUID v4）；SwiftData 给旧记录填充默认值，迁移安全。
    var notificationID: String = UUID().uuidString

    init(
        customer: String = "",
        roomOrAddress: String = "",
        phone: String = "",
        content: String,
        status: String = CustomerStatus.pending.rawValue,
        imageData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        notificationID: String? = nil
    ) {
        self.customer = customer
        self.roomOrAddress = roomOrAddress
        self.phone = phone
        self.content = content
        self.status = status
        self.imageData = imageData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.notificationID = notificationID ?? UUID().uuidString
    }
}

/// 客户需求状态流转：待处理 → 配送中 → 已完成
enum CustomerStatus: String, CaseIterable, Identifiable {
    case pending = "待处理"
    case delivering = "配送中"
    case done = "已完成"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .pending: return V21.warning
        case .delivering: return V21.info
        case .done: return V21.brandGreen
        }
    }

    /// 下一状态（已到终点返回自身）
    var next: CustomerStatus {
        switch self {
        case .pending: return .delivering
        case .delivering: return .done
        case .done: return .done
        }
    }
}

/// 状态字符串桥接（与模型同文件：App / Widget Extension 共享，避免仓储层编译耦合）
extension CustomerRequest {
    var statusEnum: CustomerStatus {
        get { CustomerStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }
}
