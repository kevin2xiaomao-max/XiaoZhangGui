import Observation

// MARK: - V3.9.1 P1-4 · 待办筛选导航状态(RootView 单例持有)
//
// 首页 chips 点击「逾期」必须进入待办「逾期」筛选,而不是仅切换 Tab:
// RootView 持有本对象并同时注入 HomeView 与 TodoView;HomeView 写 requestedTab,
// TodoView 在出现/变化时消费一次(置回 nil),普通 Tab 进入与深链进入不受影响。

@Observable
final class TodoNavigationState {
    var requestedTab: TodoTab?

    func request(_ tab: TodoTab) {
        requestedTab = tab
    }

    func consume() -> TodoTab? {
        defer { requestedTab = nil }
        return requestedTab
    }
}
