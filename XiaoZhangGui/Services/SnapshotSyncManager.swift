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

    /// 任一 fetch 失败即返回 nil；调用方必须保留旧快照，不得用空快照覆盖。
    static func buildSnapshot(context: ModelContext) -> BusinessSnapshot? {
        do {
            let todos = try context.fetch(FetchDescriptor<Todo>())
            let performances = try context.fetch(FetchDescriptor<Performance>())
            let expiryItems = try context.fetch(FetchDescriptor<ExpiryItem>())
            let customers = try context.fetch(FetchDescriptor<CustomerRequest>())
            return makeSnapshot(
                todos: todos,
                performances: performances,
                expiryItems: expiryItems,
                customers: customers
            )
        } catch {
            return nil
        }
    }

    /// 纯计算（无数据库访问），由 buildSnapshot 调用，也便于单元测试。
    static func makeSnapshot(
        todos: [Todo],
        performances: [Performance],
        expiryItems: [ExpiryItem],
        customers: [CustomerRequest]
    ) -> BusinessSnapshot {
        var snapshot = BusinessSnapshot()

        // 今日营业额与目标（日均 = 月目标 / 30，与首页一致）
        let todayRevenue = performances.filter { $0.date.isToday }.reduce(0) { $0 + $1.amount }
        snapshot.todayRevenue = todayRevenue
        let dailyGoal = AppSettings.shared.monthGoal / 30
        snapshot.todayGoalPercent = dailyGoal > 0 ? Int(todayRevenue / dailyGoal * 100) : 0

        // 待办：今日待办 + 逾期 + 下一条（按截止时间）
        let pending = todos.filter { !$0.isCompleted }
        snapshot.todayTodoCount = pending.filter { $0.dueDate == nil || $0.dueDate!.isToday }.count
        snapshot.overdueTodoCount = pending.filter { todo in
            guard let due = todo.dueDate else { return false }
            return due < Date().startOfDay
        }.count
        let nextTodo = pending
            .filter({ $0.dueDate != nil && $0.dueDate! >= Date() })
            .min(by: { $0.dueDate! < $1.dueDate! }) ?? pending.first

        if let nextTodo, isMeaningfulActionTitle(nextTodo.title) {
            snapshot.nextTodoTitle = nextTodo.title
            snapshot.nextTodoTime = nextTodo.dueDate
        }

        // 客户需求：配送中
        let delivering = customers
            .filter { $0.statusEnum == .delivering }
            .sorted { $0.updatedAt > $1.updatedAt }
        snapshot.deliveringCustomerCount = delivering.count
        if snapshot.nextTodoTitle == nil, let delivery = delivering.first {
            let summary = [delivery.roomOrAddress, delivery.content]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            if !summary.isEmpty {
                snapshot.nextTodoTitle = summary
                snapshot.nextTodoTime = nil
            }
        }

        // 临期：7 天内到期且待处理；下一条最近到期
        let urgent = expiryItems
            .filter { $0.status == .pending && $0.daysLeft(from: Date()) >= 0 && $0.daysLeft(from: Date()) <= 7 }
            .sorted { $0.expiryDate < $1.expiryDate }
        snapshot.urgentExpiryCount = urgent.count
        if let nearest = urgent.first {
            snapshot.nextExpiryName = nearest.name
            snapshot.nextExpiryDays = nearest.daysLeft(from: Date())
        }

        return snapshot
    }

    private static func isMeaningfulActionTitle(_ title: String) -> Bool {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let genericTitles: Set<String> = ["记录", "待办", "提醒", "语音记录", "新建待办"]
        return !value.isEmpty && !genericTitles.contains(value)
    }
}
