import XCTest
import SwiftData
@testable import XiaoZhangGui

// MARK: - AI REAL · 本地经营数据读取 + 隐私裁剪
//
// 验证 RepositoryBusinessContextReader 只产出最小投影（数量 / 标题），
// 且投影经 ContextRedactor 后可进入 Provider 的 payload 中
// 不含电话、地址、图片等敏感字段（R3 隐私边界）。
//
// 写法对齐基线 SwiftData 测试（IncomeSourceTests / CustomerImageRoundTripTests）：
// 类不标 @MainActor、单个测试方法 @MainActor + 同步 throws，
// 走 reader 的同步测试接缝，避免 async 宿主 + SwiftData 组合导致的进程挂起。
//
// 类名以 AIReal 开头：SwiftData 集成测试在宿主冷启动后最健康的时间窗最先执行，
// 规避预发布版 CI 模拟器运行约 5~6 分钟后出现的连接停滞 / 宿主重启级联。
final class AIRealBusinessContextReaderTests: XCTestCase {

    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try AppDatabase.makeInMemoryContainer()
        return container.mainContext
    }

    @MainActor
    private func seed(_ context: ModelContext) throws {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        let inTwoDays = cal.date(byAdding: .day, value: 2, to: today)!
        let inThirtyDays = cal.date(byAdding: .day, value: 30, to: today)!

        // 营业额：今日两笔（100 + 580.5），昨日一笔不应计入
        context.insert(Performance(amount: 100, note: "现金", date: today, incomeSource: "门店"))
        context.insert(Performance(amount: 580.5, note: "美团", date: today.addingTimeInterval(3600),
                                   incomeSource: "美团"))
        context.insert(Performance(amount: 999, note: "昨日", date: yesterday, incomeSource: "门店"))

        // 待办：今日到期 + 逾期未完成各一；明日 / 已完成不计入
        context.insert(Todo(title: "今日下可乐", dueDate: today.addingTimeInterval(3600)))
        context.insert(Todo(title: "逾期未拿货", dueDate: yesterday))
        context.insert(Todo(title: "明天的事", dueDate: tomorrow))
        context.insert(Todo(title: "今日已完成", dueDate: today, isCompleted: true))

        // 备忘：4 条，只应返回最近 3 条
        for (index, title) in ["最早备忘", "第三新", "第二新", "最新备忘"].enumerated() {
            context.insert(Memo(title: title, content: title,
                                createdAt: today.addingTimeInterval(TimeInterval(index) * 60)))
        }

        // 临期：2 天后待处理（计入）、昨天过期待处理（计入）、
        // 30 天后（不计入）、已退货（不计入）
        context.insert(ExpiryItem(name: "牛奶", expiryDate: inTwoDays))
        context.insert(ExpiryItem(name: "过期面包", expiryDate: yesterday))
        context.insert(ExpiryItem(name: "长期罐头", expiryDate: inThirtyDays))
        context.insert(ExpiryItem(name: "已退酸奶", expiryDate: inTwoDays,
                                  returnStatus: ReturnStatus.returned.rawValue))

        // 配送：今日待处理 2、配送中 1、已完成 1（不计）；昨日待处理 1（不计）
        context.insert(CustomerRequest(customer: "301", content: "水", status: "待处理", createdAt: today))
        context.insert(CustomerRequest(customer: "302", content: "可乐", status: "待处理",
                                       createdAt: today.addingTimeInterval(600)))
        context.insert(CustomerRequest(customer: "303", content: "泡面", status: "配送中",
                                       createdAt: today.addingTimeInterval(1200)))
        context.insert(CustomerRequest(customer: "304", content: "已送", status: "已完成",
                                       createdAt: today.addingTimeInterval(1800)))
        context.insert(CustomerRequest(customer: "昨天客", content: "昨天单", status: "待处理",
                                       createdAt: yesterday))

        try context.save()
    }

    // MARK: 五类 READ 投影

    @MainActor
    func testRevenueProjection() throws {
        let context = try makeContext()
        try seed(context)
        let reader = RepositoryBusinessContextReader(context: context)

        let scoped = reader.scopedContextSync(for: [.revenueToday])
        XCTAssertEqual(scoped.revenueTodayTotal ?? 0, 680.5, accuracy: 0.01)
        XCTAssertEqual(scoped.revenueTodayCount, 2)
        XCTAssertNil(scoped.todoTodayTitles)
    }

    @MainActor
    func testTodoProjectionIncludesTodayAndOverdue() throws {
        let context = try makeContext()
        try seed(context)
        let reader = RepositoryBusinessContextReader(context: context)

        let scoped = reader.scopedContextSync(for: [.todoToday])
        let titles = try XCTUnwrap(scoped.todoTodayTitles)
        XCTAssertEqual(Set(titles), ["今日下可乐", "逾期未拿货"])
        XCTAssertFalse(titles.contains("明天的事"))
        XCTAssertFalse(titles.contains("今日已完成"))
    }

    @MainActor
    func testMemoProjectionReturnsLatestThree() throws {
        let context = try makeContext()
        try seed(context)
        let reader = RepositoryBusinessContextReader(context: context)

        let scoped = reader.scopedContextSync(for: [.recentMemo])
        let titles = try XCTUnwrap(scoped.recentMemoTitles)
        XCTAssertEqual(titles.count, 3)
        XCTAssertTrue(titles.contains("最新备忘"))
        XCTAssertFalse(titles.contains("最早备忘"))
    }

    @MainActor
    func testExpiringProjectionExcludesReturnedAndFarItems() throws {
        let context = try makeContext()
        try seed(context)
        let reader = RepositoryBusinessContextReader(context: context)

        let scoped = reader.scopedContextSync(for: [.expiringGoods])
        let titles = try XCTUnwrap(scoped.expiringTitles)
        XCTAssertTrue(titles.contains { $0.contains("牛奶") })
        XCTAssertTrue(titles.contains { $0.contains("过期面包") })
        XCTAssertFalse(titles.contains { $0.contains("长期罐头") })
        XCTAssertFalse(titles.contains { $0.contains("已退酸奶") })
    }

    @MainActor
    func testDeliveryProjectionCountsTodayOnly() throws {
        let context = try makeContext()
        try seed(context)
        let reader = RepositoryBusinessContextReader(context: context)

        let scoped = reader.scopedContextSync(for: [.delivery])
        XCTAssertEqual(scoped.deliveryPendingCount, 2)
        XCTAssertEqual(scoped.deliveryDeliveringCount, 1)
    }

    @MainActor
    func testEmptyKindsReturnsEmpty() throws {
        let context = try makeContext()
        try seed(context)
        let reader = RepositoryBusinessContextReader(context: context)
        let scoped = reader.scopedContextSync(for: [])
        XCTAssertNil(scoped.revenueTodayTotal)
        XCTAssertNil(scoped.todoTodayTitles)
    }

    // MARK: 隐私：READ 结果 → 脱敏 → Provider payload

    @MainActor
    func testSanitizedPayloadExcludesSensitiveFields() throws {
        let context = try makeContext()
        try seed(context)
        let reader = RepositoryBusinessContextReader(context: context)
        let redactor = ContextRedactor()

        let scoped = reader.scopedContextSync(for: [.revenueToday, .todoToday, .delivery])
        let payload = redactor.sanitize(scoped)

        guard let data = payload.json, let raw = String(data: data, encoding: .utf8) else {
            return XCTFail("应产出 JSON payload")
        }
        // 投影结构里根本不存在电话 / 地址 / 图片 / 客户名字段
        XCTAssertFalse(raw.contains("phone"))
        XCTAssertFalse(raw.contains("roomOrAddress"))
        XCTAssertFalse(raw.contains("imageData"))
        XCTAssertFalse(raw.contains("301"), "客户房号不得进入 Provider payload")
        XCTAssertFalse(raw.contains("昨天客"))
        // 允许保留的最小聚合数据
        XCTAssertTrue(raw.contains("680.5"))
    }

    @MainActor
    func testPhoneInsideTitleIsMaskedBeforeLeavingDevice() throws {
        let context = try makeContext()
        let cal = Calendar.current
        context.insert(Todo(title: "给 13800138000 回电", dueDate: cal.startOfDay(for: Date())))
        try context.save()

        let reader = RepositoryBusinessContextReader(context: context)
        let scoped = reader.scopedContextSync(for: [.todoToday])
        let payload = ContextRedactor().sanitize(scoped)

        guard let data = payload.json, let raw = String(data: data, encoding: .utf8) else {
            return XCTFail("应产出 JSON payload")
        }
        XCTAssertFalse(raw.contains("13800138000"), "完整手机号不得外发")
        XCTAssertTrue(raw.contains("1**********"), "应脱敏为 1**********")
    }
}
