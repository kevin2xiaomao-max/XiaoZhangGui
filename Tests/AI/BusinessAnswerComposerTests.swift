import XCTest
@testable import XiaoZhangGui

// MARK: - 本地经营问答合成（0 Token，纯函数）

final class BusinessAnswerComposerTests: XCTestCase {

    func testRevenueWithCount() {
        let answer = BusinessAnswerComposer.answer(for: .revenueToday, context:
            ScopedBusinessContext(revenueTodayTotal: 680.5, revenueTodayCount: 3,
                                  todoTodayTitles: nil, recentMemoTitles: nil,
                                  deliveryPendingCount: nil, deliveryDeliveringCount: nil))
        XCTAssertTrue(answer.contains("¥680.5"))
        XCTAssertTrue(answer.contains("3 笔"))
    }

    func testRevenueEmpty() {
        let answer = BusinessAnswerComposer.answer(for: .revenueToday, context: .empty)
        XCTAssertTrue(answer.contains("还没有记录营业额"))
    }

    func testTodoListAndEmpty() {
        let withItems = BusinessAnswerComposer.answer(for: .todoToday, context:
            ScopedBusinessContext(revenueTodayTotal: nil, revenueTodayCount: nil,
                                  todoTodayTitles: ["下可乐", "联系供应商"], recentMemoTitles: nil,
                                  deliveryPendingCount: nil, deliveryDeliveringCount: nil))
        XCTAssertTrue(withItems.contains("2 件待办"))
        XCTAssertTrue(withItems.contains("1. 下可乐"))
        XCTAssertTrue(withItems.contains("2. 联系供应商"))

        let empty = BusinessAnswerComposer.answer(for: .todoToday, context: .empty)
        XCTAssertTrue(empty.contains("没有未完成的待办"))
    }

    func testMemoAndExpiring() {
        let c = ScopedBusinessContext(revenueTodayTotal: nil, revenueTodayCount: nil,
                                      todoTodayTitles: nil, recentMemoTitles: ["周五对账"],
                                      expiringTitles: ["牛奶", "面包"],
                                      deliveryPendingCount: nil, deliveryDeliveringCount: nil)
        XCTAssertTrue(BusinessAnswerComposer.answer(for: .recentMemo, context: c).contains("周五对账"))
        let expiring = BusinessAnswerComposer.answer(for: .expiringGoods, context: c)
        XCTAssertTrue(expiring.contains("2 件临期"))
        XCTAssertTrue(expiring.contains("牛奶"))
        XCTAssertTrue(BusinessAnswerComposer.answer(for: .expiringGoods, context: .empty)
            .contains("没有查到临期"))
    }

    func testDeliveryCounts() {
        let both = BusinessAnswerComposer.answer(for: .delivery, context:
            ScopedBusinessContext(revenueTodayTotal: nil, revenueTodayCount: nil,
                                  todoTodayTitles: nil, recentMemoTitles: nil,
                                  deliveryPendingCount: 2, deliveryDeliveringCount: 1))
        XCTAssertTrue(both.contains("2 单待处理"))
        XCTAssertTrue(both.contains("1 单配送中"))

        let empty = BusinessAnswerComposer.answer(for: .delivery, context: .empty)
        XCTAssertTrue(empty.contains("没有待处理的配送"))
    }

    func testMultiKindsJoinedWithoutDuplicates() {
        let c = ScopedBusinessContext(revenueTodayTotal: 100, revenueTodayCount: 1,
                                      todoTodayTitles: nil, recentMemoTitles: nil,
                                      deliveryPendingCount: 0, deliveryDeliveringCount: 0)
        let answer = BusinessAnswerComposer.answer(
            for: [.revenueToday, .revenueToday, .delivery], context: c)
        XCTAssertEqual(answer.components(separatedBy: "\n").count, 2, "重复 kind 只回答一次")
        XCTAssertTrue(answer.contains("¥100"))
    }
}
