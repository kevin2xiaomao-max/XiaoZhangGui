import Foundation
import SwiftData

// MARK: - 经营快照纯计算（App 与 Widget Extension 共用同一份业务口径）
//
// 从 SnapshotSyncManager 抽出的无副作用计算层：
// - App：SnapshotSyncManager 包一层，负责落 App Group / reload Widget / Live Activity
// - Widget：CompleteTodoIntent 写库后用同一函数重建快照，不复制第二套业务逻辑
// 任一调用方都不得在此处做 IO；失败语义（fetch 失败保留旧快照）仍由调用方处理。

enum SnapshotBuilder {
    /// 纯计算（无数据库访问）。
    static func makeSnapshot(
        todos: [Todo],
        performances: [Performance],
        expiryItems: [ExpiryItem],
        customers: [CustomerRequest],
        now: Date = Date()
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
            return due < now.startOfDay
        }.count
        let nextTodo = pending
            .filter({ $0.dueDate != nil && $0.dueDate! >= now })
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
            .filter { $0.status == .pending && $0.daysLeft(from: now) >= 0 && $0.daysLeft(from: now) <= 7 }
            .sorted { $0.expiryDate < $1.expiryDate }
        snapshot.urgentExpiryCount = urgent.count
        if let nearest = urgent.first {
            snapshot.nextExpiryName = nearest.name
            snapshot.nextExpiryDays = nearest.daysLeft(from: now)
        }

        // V3.3 Widget 2.0：最多 2 条焦点事项（逾期 → 今日 → 配送 → 临期）
        snapshot.focusItems = WidgetDashboard.selectFocusItems(
            overdueTodos: overdueFocusItems(pending, now: now),
            todayTodos: todayFocusItems(pending, now: now),
            deliveries: delivering.map(Self.deliveryFocusItem),
            expiries: urgent.map { Self.expiryFocusItem($0, now: now) }
        )

        return snapshot
    }

    // MARK: - Widget 2.0 焦点事项映射

    private static func overdueFocusItems(_ pending: [Todo], now: Date) -> [WidgetFocusItem] {
        pending
            .filter { $0.dueDate.map { $0 < now.startOfDay } ?? false }
            .sorted(by: todoDueDateAscending)
            .compactMap { todo in
                guard isMeaningfulActionTitle(todo.title) else { return nil }
                return WidgetFocusItem(
                    id: todo.notificationID,
                    kind: .todoOverdue,
                    title: todo.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    detail: "逾期",
                    completable: true
                )
            }
    }

    private static func todayFocusItems(_ pending: [Todo], now: Date) -> [WidgetFocusItem] {
        pending
            .filter { todo in
                guard let due = todo.dueDate else { return true } // 无截止 = 今天可做（与计数口径一致）
                return due >= now.startOfDay && due.isToday
            }
            .sorted(by: todoDueDateAscending)
            .compactMap { todo in
                guard isMeaningfulActionTitle(todo.title) else { return nil }
                return WidgetFocusItem(
                    id: todo.notificationID,
                    kind: .todoToday,
                    title: todo.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    detail: todo.dueDate.map(Self.todoDetail),
                    completable: true
                )
            }
    }

    private static func deliveryFocusItem(_ request: CustomerRequest) -> WidgetFocusItem {
        let title = [request.content, request.customer]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? "客户配送"
        let detail = request.roomOrAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return WidgetFocusItem(
            id: "delivery-\(request.notificationID)",
            kind: .delivery,
            title: title,
            detail: detail.isEmpty ? nil : detail,
            completable: false
        )
    }

    private static func expiryFocusItem(_ item: ExpiryItem, now: Date) -> WidgetFocusItem {
        let days = item.daysLeft(from: now)
        let detail = days <= 0 ? "今天到期" : "还剩\(days)天"
        return WidgetFocusItem(
            id: "expiry-\(item.notificationID)",
            kind: .expiry,
            title: item.name.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail,
            completable: false
        )
    }

    /// 有截止的在前按时间升序；无截止（全天）排最后
    private static func todoDueDateAscending(_ lhs: Todo, _ rhs: Todo) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (l?, r?): return l < r
        case (nil, _?): return false
        case (_?, nil): return true
        default: return lhs.createdAt < rhs.createdAt
        }
    }

    private static func todoDetail(_ due: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: due)
        if comps.hour == 0 && comps.minute == 0 { return "全天" }
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }

    static func isMeaningfulActionTitle(_ title: String) -> Bool {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let genericTitles: Set<String> = ["记录", "待办", "提醒", "语音记录", "新建待办"]
        return !value.isEmpty && !genericTitles.contains(value)
    }
}
