import XCTest
@testable import XiaoZhangGui

/// V3.9.1 P1:单次聚合等价性 / 5000 条性能 / 待办筛选状态 / 金额精度约束。
final class V391P1Tests: XCTestCase {

    private func perf(_ amount: Double, _ date: Date, _ note: String = "", _ source: String = "门店") -> Performance {
        Performance(amount: amount, note: note, date: date, incomeSource: source)
    }

    // MARK: - P1-7 首页单次聚合与旧多遍计算逐项等价

    func testHomeAggregatesMatchesLegacy() {
        let now = Date()
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let performances = [
            perf(100, now, "今日门店", "门店"),
            perf(50, now, "今日美团", "美团"),
            perf(80, yesterday, "昨日", "门店"),
            perf(999, cal.date(byAdding: .day, value: -40, to: now)!, "上月", "门店"),
        ]
        let todos = [
            Todo(title: "今日", detail: "", dueDate: now, priority: 0),
            Todo(title: "逾期", detail: "", dueDate: cal.date(byAdding: .day, value: -2, to: now), priority: 0),
            Todo(title: "已完成", detail: "", isCompleted: true),
        ]
        let customers = [CustomerRequest(customer: "王姐", roomOrAddress: "1栋", phone: "",
                                         content: "牛奶", status: CustomerStatus.delivering.rawValue)]
        let expiryItems = [ExpiryItem(name: "牛奶", category: "乳品", quantity: 1, expiryDate: now)]

        let agg = HomeAggregates.build(performances: performances, todos: todos,
                                       customers: customers, expiryItems: expiryItems, monthGoal: 1000)
        let legacy = TodaySummary.build(performances: performances, todos: todos,
                                        customers: customers, expiryItems: expiryItems)
        XCTAssertEqual(agg.todayRevenue, legacy.revenue, accuracy: 0.001)
        XCTAssertEqual(agg.changePercent ?? 0, legacy.changePercent ?? 0, accuracy: 0.001)
        XCTAssertEqual(agg.monthRevenue, MonthlyBusinessMetrics.revenue(from: performances), accuracy: 0.001)
        XCTAssertEqual(agg.trendPoints.map(\.value),
                       PerformanceTrend.last7Days(performances: performances).map(\.value))
        XCTAssertEqual(agg.trendPoints.map(\.label),
                       PerformanceTrend.last7Days(performances: performances).map(\.label))
        let legacySources = IncomeSourceSummary.compute(
            performances: performances, range: (Date().startOfMonth, Date().endOfDay))
        for kind in IncomeSource.allCases {
            let a = agg.sourceSummaries.first { $0.source == kind }
            let b = legacySources.first { $0.source == kind }
            XCTAssertEqual(a?.amount ?? -1, b?.amount ?? -2, accuracy: 0.001, "来源 \(kind) 金额须一致")
            XCTAssertEqual(a?.ratio ?? -1, b?.ratio ?? -2, accuracy: 0.001, "来源 \(kind) 占比须一致")
        }
        XCTAssertEqual(agg.todayTodoCount, TodoFilter.todos(for: .today, in: todos).count)
        XCTAssertEqual(agg.overdueCount, TodoFilter.todos(for: .overdue, in: todos).count)
        XCTAssertEqual(agg.handlingItems.count, min(3, HomeInbox.items(
            todos: legacy.todos, deliveries: legacy.deliveries,
            expiryItems: legacy.pendingExpiry, limit: 3).count))
    }

    func testPerformance5000RecordsAggregatesAndTiming() {
        // 5000 条:今日/昨日/本月/本年/去年各一段,旧多遍 vs 新单遍结果必须一致;
        // 计时打印供 CI 日志复现(不以机器抖动断言耗时,避免 flake)。
        let now = Date()
        let cal = Calendar.current
        var performances: [Performance] = []
        for i in 0..<5000 {
            let dayOffset = [0, -1, -5, -40, -400][i % 5]
            let date = cal.date(byAdding: .day, value: dayOffset, to: now)!
            performances.append(perf(Double(i % 97) + 0.5, date, "n\(i)", ["门店", "美团", "其他"][i % 3]))
        }
        let todos = (0..<200).map { Todo(title: "t\($0)", detail: "", dueDate: now, priority: $0 % 3) }

        let legacyStart = Date()
        let legacySummary = TodaySummary.build(performances: performances, todos: todos,
                                               customers: [], expiryItems: [])
        _ = PerformanceTrend.last7Days(performances: performances)
        _ = IncomeSourceSummary.compute(performances: performances, range: (now.startOfMonth, now.endOfDay))
        _ = MonthlyBusinessMetrics.revenue(from: performances)
        let legacySeconds = Date().timeIntervalSince(legacyStart)

        let newStart = Date()
        let agg = HomeAggregates.build(performances: performances, todos: todos,
                                       customers: [], expiryItems: [], monthGoal: 10000)
        let header = PerformanceHeaderAggregates.build(performances: performances)
        let newSeconds = Date().timeIntervalSince(newStart)
        print("[V391Perf] 5000 performances: legacy multi-pass=\(legacySeconds)s, single-pass=\(newSeconds)s")

        XCTAssertEqual(agg.todayRevenue, legacySummary.revenue, accuracy: 0.001)
        XCTAssertEqual(agg.monthRevenue, MonthlyBusinessMetrics.revenue(from: performances), accuracy: 0.001)
        XCTAssertEqual(header.today, agg.todayRevenue, accuracy: 0.001, "经营头部今日须与首页今日一致")
        XCTAssertEqual(header.month, agg.monthRevenue, accuracy: 0.001, "经营头部本月须与首页本月一致")
        // 本年累计必须含去年样本之外的全部本年记录,且不被 30 天列表截断影响:
        // header.year 应 >= header.month(本年含本月),且旧逐项计算一致。
        let legacyYear = performances.filter {
            $0.date >= (cal.date(from: cal.dateComponents([.year], from: now)) ?? now)
                && $0.date <= now.endOfDay
        }.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(header.year, legacyYear, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(header.year, header.month)
    }

    func testTodoCountsMatchesFilters() {
        let now = Date()
        let cal = Calendar.current
        let todos = [
            Todo(title: "今日", detail: "", dueDate: now, priority: 0),
            Todo(title: "逾期", detail: "", dueDate: cal.date(byAdding: .day, value: -3, to: now), priority: 0),
            Todo(title: "完成", detail: "", isCompleted: true),
            Todo(title: "无期", detail: "", priority: 0),
        ]
        let counts = TodoCounts.build(todos: todos)
        XCTAssertEqual(counts.today, TodoFilter.todos(for: .today, in: todos).count)
        XCTAssertEqual(counts.overdue, TodoFilter.todos(for: .overdue, in: todos).count)
        XCTAssertEqual(counts.done, 1)
        XCTAssertEqual(counts.pendingTotal, 3)
    }

    func testPerformanceHeaderAggregatesChangePercent() {
        let now = Date()
        let cal = Calendar.current
        let header = PerformanceHeaderAggregates.build(performances: [
            perf(150, now), perf(100, cal.date(byAdding: .day, value: -1, to: now)!),
        ])
        XCTAssertEqual(header.changePercent ?? 0, 50, accuracy: 0.001)
        let noYesterday = PerformanceHeaderAggregates.build(performances: [perf(150, now)])
        XCTAssertNil(noYesterday.changePercent, "无昨日数据不得显示虚假涨跌")
    }

    // MARK: - P1-4 筛选导航状态

    func testTodoNavigationRequestConsumesOnce() {
        let state = TodoNavigationState()
        XCTAssertNil(state.consume(), "无请求时消费为空")
        state.request(.overdue)
        XCTAssertEqual(state.consume(), .overdue)
        XCTAssertNil(state.consume(), "消费一次后即清空,不得重复触发筛选")
        state.request(.today)
        XCTAssertEqual(state.requestedTab, .today)
    }

    // MARK: - P2-A 金额格式分工锁定(明细 2 位小数 / 大数字整数千分位,精度不丢)

    func testAmountFormatsAreStableByRole() {
        XCTAssertEqual(Fmt.money(1234.5), "¥1,234.50", "明细金额恒为 2 位小数")
        XCTAssertEqual(Fmt.groupedAmount(1234.4), "1,234", "Hero 大数字为整数千分位")
        XCTAssertEqual(Fmt.money(0), "¥0.00")
    }

    // MARK: - P2-C 金额精度约束(持久化仍为 Double,合计走整分)

    func testMoneyPrecisionGuards() {
        XCTAssertTrue(MoneyPrecision.equalInCents(MoneyPrecision.sumInCents([0.1, 0.2]), 0.3),
                      "0.1+0.2 的 Double 直和为 0.30000000000000004,整分求和必须回到 0.30")
        XCTAssertEqual(MoneyPrecision.sumInCents(Array(repeating: 19.99, count: 5000)), 99950.0,
                       accuracy: 0.001, "5000 笔 19.99 整分合计不得漂移")
        XCTAssertEqual(MoneyPrecision.roundedToCents(123.456), 123.46, accuracy: 0.001)
        XCTAssertFalse(MoneyPrecision.equalInCents(100.0, 100.01), "分位不同不得判相等")
    }
}
