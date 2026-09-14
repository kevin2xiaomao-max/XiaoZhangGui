import XCTest
@testable import XiaoZhangGui

final class QuickRecordParserTests: XCTestCase {
    let parser = LocalQuickRecordParser()
    let now = Date()

    func testRevenueSentence() {
        let draft = parser.parse("今天营业额2680", now: now)
        XCTAssertEqual(draft.kind, .performance)
        XCTAssertEqual(draft.amount, 2680)
    }

    func testTodoWithTime() {
        let draft = parser.parse("明天下午3点联系饮料供应商", now: now)
        XCTAssertEqual(draft.kind, .todo)
        XCTAssertNotNil(draft.date)
        let hour = Calendar.current.component(.hour, from: draft.date!)
        XCTAssertEqual(hour, 15)
    }

    func testCustomerDelivery() {
        let draft = parser.parse("后天张老板配送", now: now)
        XCTAssertEqual(draft.kind, .customer)
        XCTAssertEqual(draft.customer, "张老板")
    }

    func testExpiryReturn() {
        let draft = parser.parse("月底两箱牛奶退货", now: now)
        XCTAssertEqual(draft.kind, .expiry)
        XCTAssertEqual(draft.quantity, 2)
        XCTAssertTrue(draft.title.contains("牛奶"))
    }
}
