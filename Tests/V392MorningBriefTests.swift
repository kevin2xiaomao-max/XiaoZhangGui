import XCTest
@testable import XiaoZhangGui

/// V3.9.2 PR-I:掌柜晨报纯逻辑——营收口径 / 环比 nil 语义 / 计数谓词 /
/// 建议优先级 / 问候时段边界 / 已读跨天滚动 / 深链路由。
final class V392MorningBriefTests: XCTestCase {

    private var cal: Calendar { Calendar.current }

    private func at(_ hour: Int, _ day: Int, month: Int = 10, year: Int = 2026) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: 30))!
    }

    private func perf(_ amount: Double, on date: Date) -> Performance {
        Performance(amount: amount, note: "", date: date, incomeSource: "门店")
    }

    private func expiry(daysLeft: Int, from now: Date, returned: Bool = false) -> ExpiryItem {
        let item = ExpiryItem(name: "牛奶", category: "乳品", quantity: 1,
                              expiryDate: cal.date(byAdding: .day, value: daysLeft, to: now)!)
        if returned { item.status = .returned }
        return item
    }

    // MARK: - 营收口径与环比

    func testYesterdayRevenueAndChangePercent() {
        let now = at(9, 25)
        let brief = MorningBriefBuilder.build(
            performances: [
                perf(100, on: now),                        // 今日(不计入昨日)
                perf(80, on: at(9, 24)),                   // 昨日
                perf(50, on: at(9, 23)),                   // 前日
                perf(999, on: at(9, 20)),                  // 更早(只进趋势,不进环比)
            ],
            todos: [], expiryItems: [], customers: [], monthGoal: 0, now: now
        )
        XCTAssertEqual(brief.yesterdayRevenue, 80, accuracy: 0.001)
        // (80-50)/50 = 60%
        XCTAssertEqual(brief.revenueChangePercent ?? 0, 60, accuracy: 0.001)
        // 25 号在本月内:100 + 80 + 50 + 999(20 号仍在 10 月)
        XCTAssertEqual(brief.monthRevenue, 1229, accuracy: 0.001)
    }

    func testChangePercentIsNilWhenDayBeforeHasNoRevenue() {
        let brief = MorningBriefBuilder.build(
            performances: [perf(80, on: at(9, 1))],  // 10-01 当天;前日 9-30 无营业额
            todos: [], expiryItems: [], customers: [], monthGoal: 0,
            now: cal.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))!
        )
        XCTAssertEqual(brief.yesterdayRevenue, 0, accuracy: 0.001)
        XCTAssertNil(brief.revenueChangePercent, "前日无营业额时不显示环比,不假装 0%")
        XCTAssertFalse(brief.headlineText.contains("%"), "无环比时主句不带百分比")
    }

    func testHeadlineUpDownWording() {
        let up = MorningBriefBuilder.build(
            performances: [perf(100, on: at(9, 24)), perf(50, on: at(9, 23))],
            todos: [], expiryItems: [], customers: [], monthGoal: 0, now: at(9, 25)
        )
        XCTAssertTrue(up.headlineText.contains("较前日涨"))
        let down = MorningBriefBuilder.build(
            performances: [perf(50, on: at(9, 24)), perf(100, on: at(9, 23))],
            todos: [], expiryItems: [], customers: [], monthGoal: 0, now: at(9, 25)
        )
        XCTAssertTrue(down.headlineText.contains("较前日跌"))
    }

    // MARK: - 计数谓词(与 HomeAggregates 同口径)

    func testTodoCountsMatchHomeAggregatesPredicates() {
        let now = at(9, 25)
        let todos = [
            Todo(title: "今日", detail: "", dueDate: now, priority: 0),
            Todo(title: "无期", detail: "", dueDate: nil, priority: 0),
            Todo(title: "逾期", detail: "", dueDate: cal.date(byAdding: .day, value: -2, to: now)!, priority: 0),
            Todo(title: "已完成今日", detail: "", dueDate: now, isCompleted: true),
        ]
        let brief = MorningBriefBuilder.build(
            performances: [], todos: todos, expiryItems: [], customers: [],
            monthGoal: 0, now: now
        )
        XCTAssertEqual(brief.todayTodoCount, 2, "未完成且(无期或今天):今日+无期")
        XCTAssertEqual(brief.overdueCount, 1)
        XCTAssertEqual(brief.focusItems.count, 2)
    }

    func testFocusItemsCappedAtThreeAndSortedByDueTime() {
        let now = at(9, 25)
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
        let eight = cal.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
        let todos = [
            Todo(title: "无期事", detail: "", dueDate: nil, priority: 0),
            Todo(title: "中午事", detail: "", dueDate: noon, priority: 0),
            Todo(title: "早上事", detail: "", dueDate: eight, priority: 0),
            Todo(title: "第四件", detail: "", dueDate: now, priority: 0),
        ]
        let brief = MorningBriefBuilder.build(
            performances: [], todos: todos, expiryItems: [], customers: [],
            monthGoal: 0, now: now
        )
        XCTAssertEqual(brief.focusItems.count, 3, "最多 3 条")
        // 排序:08:00 < 09:30 < 12:00;无截止排最后,被截断。
        XCTAssertEqual(brief.focusItems, ["08:00 早上事", "09:30 第四件", "12:00 中午事"])
        XCTAssertFalse(brief.focusItems.contains { $0.contains("无期事") }, "无截止排最后,超出 3 条被截断")
    }

    func testFocusItemUnscheduledShowsAllDay() {
        let now = at(9, 25)
        let todos = [
            Todo(title: "盘点", detail: "", dueDate: nil, priority: 0),
        ]
        let brief = MorningBriefBuilder.build(
            performances: [], todos: todos, expiryItems: [], customers: [],
            monthGoal: 0, now: now
        )
        XCTAssertEqual(brief.focusItems, ["全天 盘点"])
    }

    func testExpiringSoonOnlyPendingWithinSevenDays() {
        let now = at(9, 25)
        let items = [
            expiry(daysLeft: 3, from: now),                    // 计入
            expiry(daysLeft: 7, from: now),                    // 边界:计入
            expiry(daysLeft: 8, from: now),                    // 不计入
            expiry(daysLeft: 1, from: now, returned: true),    // 已退货:不计入
        ]
        let brief = MorningBriefBuilder.build(
            performances: [], todos: [], expiryItems: items, customers: [],
            monthGoal: 0, now: now
        )
        XCTAssertEqual(brief.expiringSoonCount, 2)
    }

    func testDeliveryCountMatchesHomeAggregates() {
        let now = at(9, 25)
        let customers = [
            CustomerRequest(customer: "王姐", roomOrAddress: "1栋", phone: "",
                            content: "牛奶", status: CustomerStatus.pending.rawValue),
            CustomerRequest(customer: "李叔", roomOrAddress: "2栋", phone: "",
                            content: "面包", status: CustomerStatus.done.rawValue),
        ]
        let brief = MorningBriefBuilder.build(
            performances: [], todos: [], expiryItems: [], customers: customers,
            monthGoal: 0, now: now
        )
        XCTAssertEqual(brief.deliveryCount, 1, "只数未完成配送,与首页 chips 同口径")
    }

    // MARK: - 建议优先级(确定性规则链)

    func testAdvicePriorityOverdueBeatsEverything() {
        let now = at(9, 25)
        let brief = MorningBriefBuilder.build(
            performances: [],
            todos: [Todo(title: "逾期", detail: "", dueDate: cal.date(byAdding: .day, value: -1, to: now)!, priority: 0)],
            expiryItems: [expiry(daysLeft: 1, from: now)],
            customers: [CustomerRequest(customer: "王姐", roomOrAddress: "1栋", phone: "",
                                        content: "牛奶", status: CustomerStatus.pending.rawValue)],
            monthGoal: 100, now: now
        )
        XCTAssertTrue(brief.advice.contains("逾期"), "逾期最高优先")
    }

    func testAdviceChainExpiringDeliveryGoalBehindGoalDoneDefault() {
        let now = at(9, 25)
        // 临期(无逾期)
        XCTAssertTrue(MorningBriefBuilder.build(
            performances: [], todos: [], expiryItems: [expiry(daysLeft: 2, from: now)],
            customers: [], monthGoal: 0, now: now
        ).advice.contains("到期"))
        // 配送(无逾期无临期)
        XCTAssertTrue(MorningBriefBuilder.build(
            performances: [], todos: [], expiryItems: [],
            customers: [CustomerRequest(customer: "王姐", roomOrAddress: "1栋", phone: "",
                                        content: "牛奶", status: CustomerStatus.pending.rawValue)],
            monthGoal: 0, now: now
        ).advice.contains("配送"))
        // 目标落后:25/31≈81% 时间进度,完成 50% 落后超 15pt
        let behind = MorningBriefBuilder.build(
            performances: [], todos: [], expiryItems: [], customers: [],
            monthGoal: 1000, now: now
        )
        XCTAssertEqual(behind.monthRevenue, 0)
        XCTAssertTrue(behind.advice.contains("落后"))
        // 目标达成
        let done = MorningBriefBuilder.build(
            performances: [perf(1000, on: now)], todos: [], expiryItems: [], customers: [],
            monthGoal: 1000, now: now
        )
        XCTAssertTrue(done.advice.contains("达成"))
        // 默认:昨日有进账
        let steady = MorningBriefBuilder.build(
            performances: [perf(80, on: at(9, 24))], todos: [], expiryItems: [], customers: [],
            monthGoal: 0, now: now
        )
        XCTAssertTrue(steady.advice.contains("保持节奏"))
    }

    // MARK: - 问候时段

    func testGreetingTimeBoundaries() {
        XCTAssertEqual(MorningBriefBuilder.build(
            performances: [], todos: [], expiryItems: [], customers: [], monthGoal: 0, now: at(10, 25)
        ).greeting, "早上好,掌柜")
        XCTAssertEqual(MorningBriefBuilder.build(
            performances: [], todos: [], expiryItems: [], customers: [], monthGoal: 0, now: at(11, 25)
        ).greeting, "下午好,掌柜")
        XCTAssertEqual(MorningBriefBuilder.build(
            performances: [], todos: [], expiryItems: [], customers: [], monthGoal: 0, now: at(18, 25)
        ).greeting, "晚上好,掌柜", "18 点整起算晚上")
    }

    // MARK: - 已读状态跨天滚动

    func testReadStateRollsOverNextDay() {
        let suite = "v392.morningbrief.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let today = at(9, 25)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        XCTAssertFalse(MorningBriefStore.isRead(on: today, defaults: defaults))
        MorningBriefStore.markRead(now: today, defaults: defaults)
        XCTAssertTrue(MorningBriefStore.isRead(on: today, defaults: defaults))
        XCTAssertFalse(MorningBriefStore.isRead(on: yesterday, defaults: defaults), "昨天的已读不算今天")
        MorningBriefStore.markRead(now: today, defaults: defaults)
        XCTAssertTrue(MorningBriefStore.isRead(on: today, defaults: defaults), "重复标记幂等")
        // 跨天:昨天读过,今天未读
        MorningBriefStore.markRead(now: yesterday, defaults: defaults)
        XCTAssertFalse(MorningBriefStore.isRead(on: today, defaults: defaults), "跨天自动回到未读")
    }

    func testDayKeyStableFormat() {
        let key = MorningBriefStore.dayKey(at(23, 5))
        XCTAssertEqual(key, "2026-10-05")
    }

    // MARK: - 深链路由

    func testDeepLinkMorningBriefRoutes() {
        XCTAssertEqual(AppDeepLink.route(host: "morningbrief", queryItems: []), .morningBrief)
        XCTAssertEqual(AppDeepLink.route(host: "Brief", queryItems: []), .morningBrief, "brief 别名 + 大小写不敏感")
        XCTAssertNil(AppDeepLink.route(host: "morningbriefs", queryItems: []))
        XCTAssertEqual(AppDeepLink.route(url: URL(string: "xzg://morningbrief")!), .morningBrief)
    }

    // MARK: - 月目标进度文案

    func testProgressTextSemantics() {
        let now = at(9, 25)
        XCTAssertEqual(MorningBriefBuilder.build(
            performances: [], todos: [], expiryItems: [], customers: [],
            monthGoal: 0, now: now
        ).progressText, "未设月目标")
        let brief = MorningBriefBuilder.build(
            performances: [perf(400, on: now)], todos: [], expiryItems: [], customers: [],
            monthGoal: 1000, now: now
        )
        XCTAssertEqual(brief.monthProgress, 0.4, accuracy: 0.001)
        XCTAssertTrue(brief.progressText.contains("40%"))
    }
}
