import Foundation
import UserNotifications

// MARK: - 本地通知调度（待办 / 临期 / 客户需求）
// Apple 原生 UNUserNotificationCenter。
// 变更记录：
//   P1-6：通知标识改为稳定 UUID（SwiftData 模型 notificationID），
//         避免同一秒创建的记录 createdAt 前缀冲突。
//   P1-5：客户需求编辑时重新安排跟进通知；离开 pending 状态时立即取消原通知。

enum NotificationManager {
    private static let center = UNUserNotificationCenter.current()

    // MARK: 权限

    static func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: 待办（截止时间提醒）

    static func scheduleTodo(_ todo: Todo) {
        guard AppSettings.shared.todoReminderEnabled,
              let due = todo.dueDate,
              due > Date(),
              !todo.isCompleted else { return }
        let content = UNMutableNotificationContent()
        content.title = "待办提醒"
        content.body = todo.title
        content.sound = .default
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: due
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        add(id: todoNotificationID(todo), content: content, trigger: trigger)
    }

    static func cancelTodo(_ todo: Todo) {
        center.removePendingNotificationRequests(
            withIdentifiers: [todoNotificationID(todo)]
        )
    }

    // MARK: 临期退货提醒（到期日前 remindDaysBefore 天 9:00）

    static func scheduleExpiry(_ item: ExpiryItem) {
        guard AppSettings.shared.expiryReminderEnabled,
              item.status == .pending else { return }
        guard let remindDate = Calendar.current.date(
            byAdding: .day, value: -item.remindDaysBefore, to: item.expiryDate
        ) else { return }
        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: remindDate
        )
        components.hour = 9
        components.minute = 0
        guard let fireDate = Calendar.current.date(from: components),
              fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "临期退货提醒"
        let daysLeft = item.daysLeft(from: fireDate)
        content.body = daysLeft >= 0
            ? "「\(item.name)」还有 \(daysLeft) 天到期（\(item.quantity) 件）"
            : "「\(item.name)」已到期，尽快处理（\(item.quantity) 件）"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        add(id: expiryNotificationID(item), content: content, trigger: trigger)
    }

    static func cancelExpiry(_ item: ExpiryItem) {
        center.removePendingNotificationRequests(
            withIdentifiers: [expiryNotificationID(item)]
        )
    }

    // MARK: 客户需求跟进

    /// 新增或编辑后调用：仅 pending 状态安排；其他状态确保取消
    static func rescheduleCustomer(_ request: CustomerRequest) {
        cancelCustomer(request)
        scheduleCustomerFollowUp(request)
    }

    /// 新增时安排"1 小时后跟进"提醒（仅 pending）
    static func scheduleCustomerFollowUp(_ request: CustomerRequest) {
        guard request.statusEnum == .pending else { return }
        let content = UNMutableNotificationContent()
        content.title = "配送需求待跟进"
        content.body = [request.content, request.roomOrAddress]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        add(id: customerNotificationID(request, suffix: "followup"),
            content: content, trigger: trigger)
    }

    static func cancelCustomer(_ request: CustomerRequest) {
        // 取消全部后缀（followup / delivery / custom 等，防止未来扩展的遗留）
        let id = customerStableID(request)
        let allIDs = [
            id + "-followup", id + "-delivery", id + "-custom",
        ]
        center.removePendingNotificationRequests(withIdentifiers: allIDs)
    }

    // MARK: - 稳定标识（基于 SwiftData 模型 notificationID）

    private static func todoNotificationID(_ todo: Todo) -> String {
        "todo-\(stableID(todo.notificationID, fallbackSeed: String(describing: todo)))"
    }

    private static func expiryNotificationID(_ item: ExpiryItem) -> String {
        "expiry-\(stableID(item.notificationID, fallbackSeed: item.name + "|" + String(item.createdAt.timeIntervalSince1970)))"
    }

    private static func customerNotificationID(_ request: CustomerRequest, suffix: String) -> String {
        customerStableID(request) + "-" + suffix
    }

    private static func customerStableID(_ request: CustomerRequest) -> String {
        "customer-\(stableID(request.notificationID, fallbackSeed: request.content + "|" + String(request.createdAt.timeIntervalSince1970)))"
    }

    /// 兼容兜底：若旧数据未迁移出 notificationID（空字符串），
    /// 用传入的字符串哈希伪 UUID。SwiftData 给新字段默认值，
    /// 实际上该兜底极少被触发，但保留以保证升级平滑。
    private static func stableID(_ id: String, fallbackSeed: String) -> String {
        if !id.isEmpty { return id }
        return deterministicUUID(from: fallbackSeed)
    }

    private static func deterministicUUID(from seed: String) -> String {
        // FNV-1a 64 哈希种子，截断拼成 UUID 格式字符串（稳定、可重复）
        var hash: UInt64 = 14_695_981_039_346_656_037
        let fnvPrime: UInt64 = 1_099_511_628_211
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= fnvPrime
        }
        let a = String(format: "%08x", (hash >> 32) & 0xFFFFFFFF)
        let b = String(format: "%04x", (hash >> 16) & 0xFFFF)
        let c = String(format: "%04x", hash & 0xFFFF)
        let d = String(format: "%04x", (hash >> 48) & 0xFFFF)
        let e = String(format: "%012x", (hash << 16) | 0x000000000001)
        return "\(a)-\(b)-4\(c.dropFirst())-\(d)-\(e)"
    }

    // MARK: 内部

    private static func add(
        id: String,
        content: UNMutableNotificationContent,
        trigger: UNNotificationTrigger
    ) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}
