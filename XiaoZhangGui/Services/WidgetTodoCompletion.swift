import Foundation
import SwiftData

// MARK: - Widget 2.0 Interactive：在小组件上完成待办（App / Widget Extension 共用）
//
// 设计约束：
// - 只「置为完成」，绝不 toggle：重复点击/双发不会把已完成的待办又打开（幂等防重复）。
// - 不新建第二套 SwiftData：调用方必须传入指向同一 App Group store 的容器上下文。
// - 完成后用 SnapshotBuilder（与主 App 同一口径）重建快照并返回，
//   由调用方负责落 App Group + WidgetCenter.reload + Live Activity 刷新。
// - 找不到 ID 抛错；Widget 端据此显示失败，不假成功。

enum WidgetTodoCompletionError: LocalizedError, Equatable {
    case todoNotFound
    /// Widget 进程拿不到 App Group（主 App 处于本地回退 store 等异常场景）
    case sharedStoreUnavailable

    var errorDescription: String? {
        switch self {
        case .todoNotFound: return "这条待办不存在或已被删除"
        case .sharedStoreUnavailable: return "共享数据暂不可用，请先打开一次 App"
        }
    }
}

enum WidgetTodoCompletion {
    /// 把指定待办标记完成并返回最新快照（纯数据操作；不碰 UserDefaults / WidgetCenter）。
    /// - 已完成：幂等返回最新快照，completedAt 保持首次完成时间不变。
    /// - ID 不存在：抛 todoNotFound。
    @discardableResult
    static func complete(
        todoID: String,
        context: ModelContext,
        now: Date = Date()
    ) throws -> BusinessSnapshot {
        let todos = try context.fetch(FetchDescriptor<Todo>())
        guard let target = todos.first(where: { $0.notificationID == todoID }) else {
            throw WidgetTodoCompletionError.todoNotFound
        }

        if !target.isCompleted {
            target.isCompleted = true
            target.completedAt = now
            try context.save()
            // 与 TodoRepository.toggleComplete 完成分支一致：撤销待办通知
            NotificationManager.cancelTodo(target)
        }

        let performances = try context.fetch(FetchDescriptor<Performance>())
        let expiryItems = try context.fetch(FetchDescriptor<ExpiryItem>())
        let customers = try context.fetch(FetchDescriptor<CustomerRequest>())
        return SnapshotBuilder.makeSnapshot(
            todos: todos,
            performances: performances,
            expiryItems: expiryItems,
            customers: customers,
            now: now
        )
    }
}
