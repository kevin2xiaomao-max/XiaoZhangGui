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

    // MARK: - V3.3 真机 hotfix：任何一句话都不能丢

    /// 无法识别的无意义输入：兜底为备忘，且保存闸门允许保存
    func testUnknownGibberishFallsBackToMemo() {
        let raw = "卡卡卡卡卡卡"
        let draft = parser.parse(raw, now: now)
        XCTAssertEqual(draft.kind, .memo)
        XCTAssertEqual(draft.note, raw)
        XCTAssertTrue(QuickRecordSavePolicy.canSave(raw))
    }

    /// 陈述句不是动作、也不含配送 / 临期信号 → 备忘
    func testPlainStatementFallsBackToMemo() {
        XCTAssertEqual(parser.parse("供应商周五过来", now: now).kind, .memo)
    }

    /// 显式备忘口吻仍然是备忘
    func testExplicitMemoPhraseStaysMemo() {
        XCTAssertEqual(parser.parse("记一下王老板交代的事", now: now).kind, .memo)
    }

    /// 空白文本：不允许保存（备忘兜底只针对非空句子）
    func testBlankTextCannotBeSaved() {
        XCTAssertFalse(QuickRecordSavePolicy.canSave(""))
        XCTAssertFalse(QuickRecordSavePolicy.canSave("   \n\t "))
    }

    // MARK: - 四类分流（口语化真机例句）

    func testChannelRevenueMeituan() {
        let draft = parser.parse("今天美团680", now: now)
        XCTAssertEqual(draft.kind, .performance)
        XCTAssertEqual(draft.amount, 680)
    }

    func testActionPhraseIsTodo() {
        let draft = parser.parse("明天进两箱水", now: now)
        XCTAssertEqual(draft.kind, .todo)
    }

    func testRoomDeliveryViaGivePattern() {
        let draft = parser.parse("今晚8点给302送两箱怡宝", now: now)
        XCTAssertEqual(draft.kind, .customer)
        XCTAssertEqual(draft.customer, "302")
    }
}
