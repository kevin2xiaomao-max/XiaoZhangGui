import XCTest
@testable import XiaoZhangGui

final class MockBusinessParserTests: XCTestCase {
    private let router = IntentRouter()
    private let parser = MockBusinessParser()

    /// 固定基准：2026-09-17（周四）中午
    private let now: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = 17; c.hour = 12
        return Calendar.current.date(from: c)!
    }()

    private func parse(_ text: String) -> MockParseResult? {
        parser.parse(text, intent: router.classify(text), now: now)
    }

    // MARK: 四个范例句

    func testRevenue() throws {
        guard case .tool(.recordRevenue(let a))? = parse("今天美团680") else {
            return XCTFail("应解析为 recordRevenue")
        }
        XCTAssertEqual(a.amount, 680)
        XCTAssertEqual(a.source, "美团")
        let day = Calendar.current.component(.day, from: a.date ?? now)
        XCTAssertEqual(day, 17)
    }

    func testTodo() throws {
        guard case .tool(.createTodo(let a))? = parse("明天下两箱可乐") else {
            return XCTFail("应解析为 createTodo")
        }
        XCTAssertEqual(a.title, "下两箱可乐")
        let due = try XCTUnwrap(a.dueDate)
        XCTAssertEqual(Calendar.current.component(.day, from: due), 18)
    }

    func testMemo() throws {
        guard case .tool(.createMemo(let a))? = parse("记一下供应商周五来") else {
            return XCTFail("应解析为 createMemo")
        }
        XCTAssertEqual(a.title, "供应商周五来")
        XCTAssertEqual(a.content, "记一下供应商周五来")
    }

    func testDelivery() throws {
        guard case .tool(.createDelivery(let a))? = parse("今晚8点给302送两箱怡宝") else {
            return XCTFail("应解析为 createDelivery")
        }
        XCTAssertEqual(a.customer, "302")
        XCTAssertEqual(a.goodsName, "怡宝")
        XCTAssertEqual(a.quantity, "两箱")
        XCTAssertTrue((a.content ?? "").contains("怡宝"))
        XCTAssertTrue((a.content ?? "").contains("两箱"))
        XCTAssertEqual(a.deliveryTimeText, "今晚8点")
        let time = try XCTUnwrap(a.deliveryTime)
        let comps = Calendar.current.dateComponents([.day, .hour], from: time)
        XCTAssertEqual(comps.day, 17)
        XCTAssertEqual(comps.hour, 20)
    }

    // MARK: 信息不足必须 clarify，不脑补

    func testRevenueMissingAmountClarifies() {
        guard case .clarify? = parse("美团卖了") else {
            return XCTFail("缺金额应要求补充")
        }
    }

    func testEmptyMemoClarifies() {
        guard case .clarify? = parse("记一下") else {
            return XCTFail("空备忘应要求补充")
        }
    }

    // MARK: 普通聊天不产出工具

    func testWorldChatProducesNoTool() {
        XCTAssertNil(parse("广东天气怎么样"))
    }
}
