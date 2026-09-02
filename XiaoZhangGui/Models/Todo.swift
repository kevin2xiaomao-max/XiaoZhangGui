import Foundation
import SwiftData

/// 待办（对齐 Android TodoEntity：title/detail/dueDate/priority/imagePaths/isCompleted/createdAt/completedAt）
@Model
final class Todo {
    var title: String = ""
    var detail: String = ""
    /// 截止时间，nil 表示无截止
    var dueDate: Date?
    /// 0 低 / 1 中 / 2 高
    var priority: Int = 0
    @Attribute(.externalStorage) var imageData: Data?
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date?
    /// 稳定通知/UI 标识（UUID v4）。
    /// 迁移安全：SwiftData 对新字段采用默认值（初始化时生成），旧数据读取时由 getter
    /// 懒填充并持久化，避免同一秒创建的记录 id 冲突（旧 createdAt 策略的问题）。
    var notificationID: String = UUID().uuidString

    init(
        title: String,
        detail: String = "",
        dueDate: Date? = nil,
        priority: Int = 0,
        imageData: Data? = nil,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        notificationID: String? = nil
    ) {
        self.title = title
        self.detail = detail
        self.dueDate = dueDate
        self.priority = priority
        self.imageData = imageData
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.notificationID = notificationID ?? UUID().uuidString
    }
}

/// 待办优先级展示
enum TodoPriority: Int, CaseIterable, Identifiable {
    case low = 0, medium = 1, high = 2

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .low: return "低优先级"
        case .medium: return "中优先级"
        case .high: return "高优先级"
        }
    }
    var shortLabel: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

extension Todo {
    var priorityLevel: TodoPriority {
        get { TodoPriority(rawValue: priority) ?? .low }
        set { priority = newValue.rawValue }
    }
}
