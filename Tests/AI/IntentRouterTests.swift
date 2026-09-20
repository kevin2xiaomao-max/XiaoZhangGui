import XCTest
@testable import XiaoZhangGui

final class IntentRouterTests: XCTestCase {
    private let router = IntentRouter()

    // MARK: 四个范例句必须正确分类

    func testRevenueExemplar() {
        XCTAssertEqual(router.classify("今天美团680"), .businessAction(.recordRevenue))
    }

    func testTodoExemplar() {
        XCTAssertEqual(router.classify("明天下两箱可乐"), .businessAction(.createTodo))
    }

    func testMemoExemplar() {
        XCTAssertEqual(router.classify("记一下供应商周五来"), .businessAction(.createMemo))
    }

    func testDeliveryExemplar() {
        XCTAssertEqual(router.classify("今晚8点给302送两箱怡宝"), .businessAction(.createDelivery))
    }

    // MARK: 经营读问答优先于新建动作

    func testDeliveryQueryWinsOverCreate() {
        XCTAssertEqual(router.classify("今天还有几单配送"), .businessQuery(.delivery))
    }

    func testRevenueQuery() {
        XCTAssertEqual(router.classify("今天营业额多少"), .businessQuery(.revenueToday))
    }

    func testTodoQuery() {
        XCTAssertEqual(router.classify("今天有什么待办"), .businessQuery(.todoToday))
    }

    func testMemoQuery() {
        XCTAssertEqual(router.classify("最近有什么备忘"), .businessQuery(.recentMemo))
    }

    // MARK: 世界知识不带经营语义

    func testWorldChat() {
        XCTAssertEqual(router.classify("苹果发布会什么时候开"), .worldChat)
        XCTAssertEqual(router.classify("iPhone 怎么设置闹钟"), .worldChat)
    }

    // MARK: 配送判定

    func testDeliveryNeedsRoomOrVerb() {
        XCTAssertTrue(router.isDelivery("给302送两箱水"))
        XCTAssertTrue(router.isDelivery("送到302室"))
        XCTAssertFalse(router.isDelivery("下两箱可乐"))
    }

    func testFirstRoomNumberIgnoresSingleDigitTime() {
        XCTAssertEqual(router.firstRoomNumber(in: "今晚8点给302送水"), "302")
    }

    // MARK: 金额识别不误伤纯日期

    func testAmountDetection() {
        XCTAssertTrue(router.hasAmount("美团680"))
        XCTAssertTrue(router.hasAmount("六十八元"))
        XCTAssertFalse(router.hasAmount("明天周末"))
    }

    func testP41BusinessPeriodPhrasesRouteLocally() {
        let cases: [(String, BusinessInsightKind)] = [
            ("最近一周生意怎么样", .period(.lastSevenDays)),
            ("最近7天生意怎么样", .period(.lastSevenDays)),
            ("这个月业绩", .period(.thisMonth)),
            ("本月营业额", .period(.thisMonth)),
            ("上个月业绩", .period(.lastMonth)),
            ("最近3个月业绩", .period(.lastThreeMonths)),
            ("最近6个月业绩", .period(.lastSixMonths)),
            ("近半年业绩", .period(.lastSixMonths)),
            ("上个月和这个月的对比", .period(.thisMonthComparedWithLastMonth)),
            ("本月和上月对比", .period(.thisMonthComparedWithLastMonth)),
            ("三个月和这个月的对比", .period(.lastThreeMonthsComparedWithThisMonth))
        ]
        for (text, expected) in cases { XCTAssertEqual(router.classify(text), .businessInsight(expected), text) }
    }

    func testTimeOnlyStillDoesNotCreateTodo() {
        XCTAssertEqual(router.classify("明天"), .worldChat)
        XCTAssertEqual(router.classify("下午3点"), .worldChat)
    }
}
