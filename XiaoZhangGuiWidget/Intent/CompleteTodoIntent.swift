import AppIntents
import SwiftData
import WidgetKit

// MARK: - Widget 2.0 Interactive：勾选完成待办
//
// 进程模型：Intent 在 Widget Extension 内执行（Interactive Widget 标准路径），
// 直接打开与主 App 相同的 App Group 持久 store（不是第二套数据库），
// 复用 App target 共享编译的 WidgetTodoCompletion / SnapshotBuilder /
// NotificationManager / LiveActivityManager，业务逻辑零复制。
// 写库完成后：更新 App Group 快照 → reloadAllTimelines → Live Activity 同步。

struct CompleteTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "完成待办"
    static let description = IntentDescription("把小组件上的这条待办标记为已完成")

    /// 稳定待办标识（Todo.notificationID）。不用易变的 PersistentModelID。
    @Parameter(title: "待办 ID")
    var todoID: String

    init() {}

    init(todoID: String) {
        self.todoID = todoID
    }

    func perform() async throws -> some IntentResult {
        // App Group 不可用（主 App 曾本地回退等）：显式失败，UI 不假成功。
        guard let storeURL = AppDatabase.sharedStoreURL() else {
            throw WidgetTodoCompletionError.sharedStoreUnavailable
        }
        let container = try WidgetIntentStore.container(storeURL: storeURL)
        let snapshot = try WidgetTodoCompletion.complete(
            todoID: todoID,
            context: ModelContext(container)
        )
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
        LiveActivityManager.update(with: snapshot)
        return .result()
    }
}

/// 扩展进程内复用同一个 App Group 容器（首次构建后缓存，避免每次点击重建）。
private enum WidgetIntentStore {
    private static var cachedURL: URL?
    private static var cachedContainer: ModelContainer?

    static func container(storeURL: URL) throws -> ModelContainer {
        if let cachedContainer, cachedURL == storeURL { return cachedContainer }
        let container = try AppDatabase.makePersistentContainer(at: storeURL)
        cachedContainer = container
        cachedURL = storeURL
        return container
    }
}
