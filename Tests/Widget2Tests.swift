import XCTest
import SwiftData
@testable import XiaoZhangGui

/// V3.3 Widget 2.0 Lite 专项测试
/// 覆盖：Small/Medium deeplink 常量、Medium 事项选取（优先级/最多2/去重）、
/// 状态行、金额格式、快照向后兼容、Interactive 完成待办（防重复/失败不假成功）。
/// UI 的 Light/Dark/Tinted/Clear/缩放为编译期 + 全尺寸 CI 编译覆盖。
final class Widget2Tests: XCTestCase {

    // MARK: - 焦点事项选取

    private func item(_ id: String, _ kind: WidgetFocusKind = .todoToday) -> WidgetFocusItem {
        WidgetFocusItem(id: id, kind: kind, title: id, completable: kind == .todoOverdue || kind == .todoToday)
    }

    func testFocusPriorityOverdueTodayDeliveryExpiry() {
        let picked = WidgetDashboard.selectFocusItems(
            overdueTodos: [item("o1", .todoOverdue)],
            todayTodos: [item("t1", .todoToday)],
            deliveries: [item("d1", .delivery)],
            expiries: [item("e1", .expiry)]
        )
        XCTAssertEqual(picked.map(\.id), ["o1", "t1"])
        XCTAssertEqual(picked.map(\.kind), [.todoOverdue, .todoToday])
    }

    func testFocusFallsThroughToDeliveryAndExpiryWhenNoTodos() {
        let picked = WidgetDashboard.selectFocusItems(
            overdueTodos: [],
            todayTodos: [],
            deliveries: [item("d1", .delivery), item("d2", .delivery)],
            expiries: [item("e1", .expiry)]
        )
        XCTAssertEqual(picked.map(\.id), ["d1", "d2"])
    }

    func testFocusLimitedToTwoAcrossCategories() {
        let picked = WidgetDashboard.selectFocusItems(
            overdueTodos: [item("o1", .todoOverdue), item("o2", .todoOverdue), item("o3", .todoOverdue)],
            todayTodos: [item("t1", .todoToday)],
            deliveries: [item("d1", .delivery)],
            expiries: [item("e1", .expiry)]
        )
        XCTAssertEqual(picked.count, 2)
        XCTAssertEqual(picked.map(\.id), ["o1", "o2"])
    }

    func testFocusDeduplicatedByStableIDAcrossCategories() {
        // 同一稳定 ID 不应重复占位（防御跨类别重复）
        let same = item("same-id", .todoToday)
        let picked = WidgetDashboard.selectFocusItems(
            overdueTodos: [same],
            todayTodos: [same],
            deliveries: [],
            expiries: []
        )
        XCTAssertEqual(picked.map(\.id), ["same-id"])
        XCTAssertEqual(picked.count, 1)
    }

    func testFocusPreservesOrderWithinCategory() {
        let picked = WidgetDashboard.selectFocusItems(
            overdueTodos: [item("a"), item("b"), item("c")],
            todayTodos: [],
            deliveries: [],
            expiries: [],
            limit: 3
        )
        XCTAssertEqual(picked.map(\.id), ["a", "b", "c"])
    }

    func testFocusZeroLimitReturnsEmpty() {
        let picked = WidgetDashboard.selectFocusItems(
            overdueTodos: [item("a")],
            todayTodos: [],
            deliveries: [],
            expiries: [],
            limit: 0
        )
        XCTAssertTrue(picked.isEmpty)
    }

    func testLongTitlePassesThroughUncut() {
        // 截断是 UI 层 lineLimit 的职责；逻辑层必须原样保留长标题
        let long = String(repeating: "超长标题", count: 20)
        let picked = WidgetDashboard.selectFocusItems(
            overdueTodos: [WidgetFocusItem(id: "x", kind: .todoOverdue, title: long, completable: true)],
            todayTodos: [], deliveries: [], expiries: []
        )
        XCTAssertEqual(picked.first?.title, long)
    }

    // MARK: - Small 状态行

    func testStatusLinePrecedence() {
        XCTAssertEqual(
            WidgetDashboard.statusLine(overdueTodos: 1, todayTodos: 5, deliveries: 3, urgentExpiry: 2),
            "1 个逾期待办"
        )
        XCTAssertEqual(
            WidgetDashboard.statusLine(overdueTodos: 0, todayTodos: 2, deliveries: 3, urgentExpiry: 2),
            "2 个待办"
        )
        XCTAssertEqual(
            WidgetDashboard.statusLine(overdueTodos: 0, todayTodos: 0, deliveries: 1, urgentExpiry: 2),
            "1 个配送"
        )
        XCTAssertEqual(
            WidgetDashboard.statusLine(overdueTodos: 0, todayTodos: 0, deliveries: 0, urgentExpiry: 4),
            "4 件临期"
        )
        XCTAssertNil(WidgetDashboard.statusLine(overdueTodos: 0, todayTodos: 0, deliveries: 0, urgentExpiry: 0))
    }

    // MARK: - 金额格式

    func testFormatRevenue() {
        XCTAssertEqual(WidgetDashboard.formatRevenue(0), "0")
        XCTAssertEqual(WidgetDashboard.formatRevenue(2680), "2,680")
        XCTAssertEqual(WidgetDashboard.formatRevenue(268000), "268,000")
        XCTAssertEqual(WidgetDashboard.formatRevenue(88.5), "88.50")
    }

    // MARK: - Deep Link 常量（Small AI / Small Voice / Medium 两个胶囊共用）

    func testDeepLinkConstantsRoutePrecisely() {
        // AI：精准到小掌柜输入页（assistant Tab），不是仅打开首页
        XCTAssertEqual(AppDeepLink.route(url: XZGWidgetLink.ai), .some(.ai(voiceMode: false)))
        // 语音：直达 VoiceView（onAppear 即 beginListening）
        XCTAssertEqual(AppDeepLink.route(url: XZGWidgetLink.voice), .some(.voice))
    }

    // MARK: - 快照兼容

    func testSnapshotDecodesLegacyJSONWithoutFocusItems() throws {
        // V3.2/V3.3-Foundation 时代写入的旧快照（无 focusItems 键）
        let legacyJSON = """
        {"generatedAt":"2026-09-18T10:00:00Z","todayRevenue":123.5,"todayTodoCount":2,"overdueTodoCount":0}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(BusinessSnapshot.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(snapshot.todayRevenue, 123.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.todayTodoCount, 2)
        XCTAssertTrue(snapshot.focusItems.isEmpty)
    }

    func testSnapshotFocusItemsRoundTrip() throws {
        var snapshot = BusinessSnapshot()
        snapshot.focusItems = [
            WidgetFocusItem(id: "todo-1", kind: .todoOverdue, title: "回电话", detail: "逾期", completable: true),
            WidgetFocusItem(id: "delivery-1", kind: .delivery, title: "送牛奶", detail: "3 栋 502", completable: false),
        ]
        let data = try XCTUnwrap(snapshot.encode())
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BusinessSnapshot.self, from: data)
        XCTAssertEqual(decoded.focusItems, snapshot.focusItems)
    }

    // MARK: - Interactive：完成待办（真实 SwiftData in-memory 容器，同一条完成路径）

    @MainActor
    func testCompletionMarksDoneAndRebuildsSnapshot() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date().startOfDay)!
        let todo = Todo(title: "昨日该回的电话", detail: "", dueDate: yesterday, priority: 2)
        ctx.insert(todo)
        try ctx.save()

        let snapshot = try WidgetTodoCompletion.complete(todoID: todo.notificationID, context: ctx)

        XCTAssertTrue(todo.isCompleted)
        XCTAssertNotNil(todo.completedAt)
        XCTAssertEqual(snapshot.overdueTodoCount, 0)
        XCTAssertTrue(snapshot.focusItems.isEmpty)
    }

    @MainActor
    func testCompletionIsIdempotentAndNeverReopens() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let future = Date(timeIntervalSinceNow: 3600)
        let todo = Todo(title: "一小时后进货", detail: "", dueDate: future, priority: 1)
        ctx.insert(todo)
        try ctx.save()

        let firstNow = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try WidgetTodoCompletion.complete(todoID: todo.notificationID, context: ctx, now: firstNow)
        // 再次点击（双发/重复点击）：不得 toggle 回未完成，completedAt 必须保持首次时间
        let secondNow = Date(timeIntervalSince1970: 1_700_000_999)
        let snapshot = try WidgetTodoCompletion.complete(
            todoID: todo.notificationID, context: ctx, now: secondNow
        )

        XCTAssertTrue(todo.isCompleted)
        XCTAssertEqual(todo.completedAt, firstNow)
        // 已完成后不再计入今日待办
        XCTAssertEqual(snapshot.todayTodoCount, 0)
    }

    @MainActor
    func testCompletionUnknownIDThrowsAndDoesNotFakeSuccess() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        ctx.insert(Todo(title: "另一条", dueDate: Date(timeIntervalSinceNow: 3600)))
        try ctx.save()

        XCTAssertThrowsError(
            try WidgetTodoCompletion.complete(todoID: "not-exist-uuid", context: ctx)
        ) { error in
            XCTAssertEqual(error as? WidgetTodoCompletionError, .todoNotFound)
        }
    }

    // MARK: - SnapshotBuilder 真实模型集成（口径与主 App 同一份）

    @MainActor
    func testBuilderFocusItemsPickOverdueThenToday() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let reference = cal.date(from: DateComponents(timeZone: cal.timeZone, year: 2026, month: 1, day: 15, hour: 12))!
        let yesterday = cal.date(byAdding: .day, value: -1, to: reference)!
        let today = cal.date(byAdding: .hour, value: 1, to: reference)!
        let future = cal.date(byAdding: .day, value: 2, to: reference)!
        ctx.insert(Todo(title: "逾期待办", dueDate: yesterday))
        ctx.insert(Todo(title: "今日待办", dueDate: today))
        ctx.insert(Todo(title: "未来待办", dueDate: future))
        ctx.insert(Todo(title: "已完成", dueDate: today, isCompleted: true))
        ctx.insert(CustomerRequest(customer: "王姐", content: "送牛奶", status: CustomerStatus.delivering.rawValue))
        ctx.insert(ExpiryItem(name: "鲜牛奶", expiryDate: cal.date(byAdding: .day, value: 3, to: reference)!))
        try ctx.save()

        let todos = try ctx.fetch(FetchDescriptor<Todo>())
        let performances = try ctx.fetch(FetchDescriptor<Performance>())
        let expiryItems = try ctx.fetch(FetchDescriptor<ExpiryItem>())
        let customers = try ctx.fetch(FetchDescriptor<CustomerRequest>())
        let snapshot = SnapshotBuilder.makeSnapshot(todos: todos, performances: performances, expiryItems: expiryItems, customers: customers, now: reference)
        XCTAssertEqual(snapshot.focusItems.map(\.title), ["逾期待办", "今日待办"])
        XCTAssertEqual(snapshot.focusItems.map(\.completable), [true, true])
    }

    @MainActor
    func testBuilderFocusItemsFallbackToDeliveryExpiryAndExcludesGenericTitles() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let cal = Calendar.current
        // 无意义标题的待办不进焦点事项（但仍计入计数口径）
        ctx.insert(Todo(title: "记录", dueDate: Date(timeIntervalSinceNow: 3600)))
        let request = CustomerRequest(customer: "王姐", roomOrAddress: "3 栋 502",
                                      content: "鲜牛奶两箱", status: CustomerStatus.delivering.rawValue)
        ctx.insert(request)
        ctx.insert(ExpiryItem(name: "酸奶", expiryDate: cal.date(byAdding: .day, value: 1, to: Date().startOfDay)!))
        try ctx.save()

        let snapshot = try XCTUnwrap(SnapshotSyncManager.buildSnapshot(context: ctx))
        XCTAssertEqual(snapshot.focusItems.count, 2)
        XCTAssertEqual(snapshot.focusItems.first?.kind, .delivery)
        XCTAssertEqual(snapshot.focusItems.first?.id, "delivery-\(request.notificationID)")
        XCTAssertEqual(snapshot.focusItems.first?.detail, "3 栋 502")
        XCTAssertEqual(snapshot.focusItems.last?.kind, .expiry)
        XCTAssertEqual(snapshot.focusItems.last?.detail, "还剩1天")
    }

    @MainActor
    func testEmptySnapshotDefaultsAreSafeForWidget() {
        let empty = BusinessSnapshot()
        XCTAssertEqual(empty.todayRevenue, 0)
        XCTAssertTrue(empty.focusItems.isEmpty)
        XCTAssertNil(WidgetDashboard.statusLine(
            overdueTodos: empty.overdueTodoCount,
            todayTodos: empty.todayTodoCount,
            deliveries: empty.deliveringCustomerCount,
            urgentExpiry: empty.urgentExpiryCount
        ))
        XCTAssertEqual(WidgetDashboard.formatRevenue(empty.todayRevenue), "0")
    }

    // MARK: - Helper

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: AppDatabase.schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: AppDatabase.schema, configurations: [config])
    }
}
