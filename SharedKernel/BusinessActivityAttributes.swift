import Foundation
import ActivityKit

// MARK: - Live Activity 属性（锁屏 / 灵动岛）
// 场景：今日经营实况 —— 下一条待办、配送中客户需求、临期提醒
// App 侧通过 LiveActivityManager 启动/更新；Widget Extension 提供锁屏与灵动岛 UI

struct BusinessActivityAttributes: ActivityAttributes {
    /// 当前活动代表的一天（0 点），用于活动命名与去重
    public struct ContentState: Codable, Hashable {
        /// 下一条待办标题（nil 显示"暂无待办"）
        var nextTodoTitle: String?
        /// 下一条待办时间
        var nextTodoTime: Date?
        /// 未完成待办数（可选以兼容旧活动状态）
        var todoCount: Int?
        /// 配送中客户需求数
        var deliveringCustomerCount: Int
        /// 7 天内临期数量
        var urgentExpiryCount: Int
        /// 状态更新时间
        var updatedAt: Date
    }

    /// 今日 0 点（同一 activityID 全天复用）
    var dayStart: Date

    var activityID: String {
        let c = Calendar.current
        let comps = c.dateComponents([.year, .month, .day], from: dayStart)
        return "today-\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }
}
