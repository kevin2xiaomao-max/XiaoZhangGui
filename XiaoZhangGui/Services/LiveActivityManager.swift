import Foundation
import ActivityKit

// MARK: - Live Activity 生命周期管理（App 侧）
// 场景 1：锁屏/灵动岛展示"下一条待办 / 配送中客户需求 / 临期提醒"
// App 激活时启动当日活动，快照刷新时更新状态；跨天自动结束旧活动
// 需 Mac/Xcode：真机验证（ActivityAuthorizationInfo、灵动岛机型、NSSupportsLiveActivities）

enum LiveActivityManager {
    /// App 进入前台时调用：启动/复用今日活动
    static func startIfNeeded(snapshot: BusinessSnapshot) {
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        #if DEBUG
        print("[LiveActivity] areActivitiesEnabled = \(enabled)")
        #endif
        guard enabled else { return }
        let attributes = BusinessActivityAttributes(dayStart: Date().startOfDay)

        // 结束不属于今天的遗留活动（跨天清理）
        for running in Activity<BusinessActivityAttributes>.activities where running.attributes.activityID != attributes.activityID {
            Task { await running.end(dismissalPolicy: .immediate) }
        }

        if Activity<BusinessActivityAttributes>.activities.contains(where: { $0.attributes.activityID == attributes.activityID }) {
            update(with: snapshot)
            return
        }
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state(from: snapshot), staleDate: Calendar.current.date(byAdding: .day, value: 1, to: Date().startOfDay))
            )
            #if DEBUG
            print("[LiveActivity] Activity.request 成功, id = \(activity.id)")
            #endif
        } catch {
            #if DEBUG
            print("[LiveActivity] Activity.request 失败: \(error.localizedDescription) (\(error))")
            #endif
        }
    }

    /// 快照变化时调用
    static func update(with snapshot: BusinessSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for activity in Activity<BusinessActivityAttributes>.activities {
            Task {
                await activity.update(
                    ActivityContent(state: state(from: snapshot), staleDate: Calendar.current.date(byAdding: .day, value: 1, to: activity.attributes.dayStart))
                )
            }
        }
    }

    /// 手动结束全部活动（预留：设置页可提供开关）
    static func endAll() {
        for activity in Activity<BusinessActivityAttributes>.activities {
            Task { await activity.end(dismissalPolicy: .immediate) }
        }
    }

    private static func state(from snapshot: BusinessSnapshot) -> BusinessActivityAttributes.ContentState {
        let title = sanitizedTodoTitle(snapshot.nextTodoTitle)
        return .init(
            nextTodoTitle: title,
            nextTodoTime: title == nil ? nil : snapshot.nextTodoTime,
            todoCount: snapshot.todayTodoCount + snapshot.overdueTodoCount,
            deliveringCustomerCount: snapshot.deliveringCustomerCount,
            urgentExpiryCount: snapshot.urgentExpiryCount,
            updatedAt: Date()
        )
    }

    private static func sanitizedTodoTitle(_ title: String?) -> String? {
        guard let title else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("的天气") else { return nil }
        return trimmed
    }
}
