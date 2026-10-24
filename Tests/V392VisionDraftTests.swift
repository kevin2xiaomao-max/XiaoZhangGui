import XCTest
@testable import XiaoZhangGui

/// V3.9.2 · 识别文字 → 记账草稿
///
/// 图片车道此前只回一段文字，用户还得自己再录一遍；这里锁住「识别结果能直接出确认卡」
/// 的闭环，同时锁住安全边界：支出语义（进货/采购/房租…）绝不生成收入卡。
final class V392VisionDraftTests: XCTestCase {

    func testRevenueTextDraftsRevenueCard() throws {
        let call = try XCTUnwrap(
            VisionDraftParser.draftToolCall(from: "微信收款 35 元"),
            "带来源 + 收款的识别结果应当出收入草稿"
        )
        XCTAssertEqual(call.name, .recordRevenue)
        guard case .recordRevenue(let arguments) = call.arguments else {
            return XCTFail("参数类型应为 recordRevenue")
        }
        XCTAssertEqual(arguments.amount ?? 0, 35, accuracy: 0.001)
    }

    func testSpokenAmountFlowsIntoDraft() throws {
        let call = try XCTUnwrap(VisionDraftParser.draftToolCall(from: "今天美团卖了六百八"))
        guard case .recordRevenue(let arguments) = call.arguments else {
            return XCTFail("参数类型应为 recordRevenue")
        }
        XCTAssertEqual(arguments.amount ?? 0, 680, accuracy: 0.001, "口语金额应被归一后再进草稿")
    }

    func testExpenseTextNeverDraftsRevenue() {
        XCTAssertNil(
            VisionDraftParser.draftToolCall(from: "进货 320 元 现金支付"),
            "进货是支出：当前只有 recordRevenue，记反方向比不识别更坏"
        )
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "这个月房租 3000 元"))
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "退款 58 元 已原路退回"))
    }

    func testRemainingExpenseCuesNeverDraftRevenue() {
        // 与 testExpenseTextNeverDraftsRevenue 同一模式：补齐阻断表其余 9 词。
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "采购 500 元"))
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "付款 200 元"))
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "退货 120 元"))
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "报销 300 元"))
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "工资 5000 元"))
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "水电 180 元"))
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "支出 90 元"))
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "付了 60 元"))
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "买入 400 元"))
    }

    func testNonBusinessTextDraftsNothing() {
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "今天天气不错"))
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "  "))
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "这是一张商品条码照片"))
    }

    func testTodoAndDeliveryStillDraft() throws {
        let todo = try XCTUnwrap(VisionDraftParser.draftToolCall(from: "明天下两箱可乐"))
        XCTAssertEqual(todo.name, .createTodo)

        let delivery = try XCTUnwrap(VisionDraftParser.draftToolCall(from: "今晚8点给302送两箱怡宝"))
        XCTAssertEqual(delivery.name, .createDelivery)
    }

    /// 源码审计：图片车道必须接上草稿解析，且与聊天链共用同一个 propose（不各写一套）。
    func testImageLaneSharesProposalPath() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        func source(_ relative: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        }

        let core = try source("XiaoZhangGui/Features/Assistant/AI/Core/AgentCore.swift")
        XCTAssertTrue(core.contains("VisionDraftParser.draftToolCall(from: result.userFacingText)"))
        XCTAssertTrue(core.contains("private func propose(_ call: ToolCall"), "建卡只允许一条实现")
        XCTAssertTrue(core.contains("return await propose(call, userMessage: userMessage)"))

        let draft = try source("XiaoZhangGui/Features/Assistant/AI/Core/VisionDraftParser.swift")
        XCTAssertTrue(draft.contains("\"进货\""), "支出语义必须被拦截")
        XCTAssertTrue(draft.contains("case .businessAction(let tool)"), "只对写动作出草稿")
    }
}
