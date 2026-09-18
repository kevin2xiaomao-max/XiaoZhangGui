import Foundation
import SwiftData
import WidgetKit

// MARK: - 快照同步中心
// 查询 SwiftData → 计算 BusinessSnapshot → 写入 App Group UserDefaults
// → WidgetCenter 重载小组件 → Live Activity 状态更新
// 调用点：App scenePhase 变化、App Intents 写入后、数据恢复后

enum SnapshotSyncManager {
    /// 全量刷新（幂等，开销为若干次内存查询）
    static func refreshAll(context: ModelContext) {
        commit(snapshot: buildSnapshot(context: context))
    }

    /// App Intents 等已持有独立容器的场景：用容器构建上下文刷新
    static func refreshAll(container: ModelContainer) {
        let context = ModelContext(container)
        refreshAll(context: context)
    }

    /// 仅当快照构建成功才落盘 / 刷新 Widget / 更新 Live Activity。
    /// snapshot == nil（查询失败）时直接保留上一次有效快照，绝不用空数据清零。
    static func commit(snapshot: BusinessSnapshot?) {
        guard let snapshot else { return }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
        LiveActivityManager.update(with: snapshot)
    }

    // MARK: - 快照计算（对齐 HomeStats 口径）

    /// 快照所需的四类源数据（集中为一个值，便于注入失败路径做单元测试）
    struct SnapshotSource {
        let todos: [Todo]
        let performances: [Performance]
        let expiryItems: [ExpiryItem]
        let customers: [CustomerRequest]
    }

    /// 任一 fetch 失败即返回 nil；调用方必须保留旧快照，不得用空快照覆盖。
    static func buildSnapshot(context: ModelContext) -> BusinessSnapshot? {
        buildSnapshot {
            try SnapshotSource(
                todos: context.fetch(FetchDescriptor<Todo>()),
                performances: context.fetch(FetchDescriptor<Performance>()),
                expiryItems: context.fetch(FetchDescriptor<ExpiryItem>()),
                customers: context.fetch(FetchDescriptor<CustomerRequest>())
            )
        }
    }

    /// 可注入数据源的构建入口：source 抛错时返回 nil（失败路径可确定性单测）。
    static func buildSnapshot(fetchingSource: () throws -> SnapshotSource) -> BusinessSnapshot? {
        guard let source = try? fetchingSource() else { return nil }
        return makeSnapshot(
            todos: source.todos,
            performances: source.performances,
            expiryItems: source.expiryItems,
            customers: source.customers
        )
    }

    /// 纯计算门面：实际口径在 SnapshotBuilder（App 与 Widget Extension 共用同一份）。
    static func makeSnapshot(
        todos: [Todo],
        performances: [Performance],
        expiryItems: [ExpiryItem],
        customers: [CustomerRequest]
    ) -> BusinessSnapshot {
        SnapshotBuilder.makeSnapshot(
            todos: todos,
            performances: performances,
            expiryItems: expiryItems,
            customers: customers
        )
    }
}
