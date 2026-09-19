import XCTest
@testable import XiaoZhangGui

final class AI20MultiTurnTests: XCTestCase {
    @MainActor
    func testRevenueAmountCorrectionUpdatesSamePendingProposal() async throws {
        let harness = AITestFactory.live(provider: ScriptedAIProvider([]))
        let firstResult = await harness.agent.send("今天美团680")
        let first = try XCTUnwrap(firstResult.proposal)
        let correctedResult = await harness.agent.send("不是680，是860")
        let corrected = try XCTUnwrap(correctedResult.proposal)
        XCTAssertEqual(corrected.id, first.id)
        guard case .recordRevenue(let value) = corrected.call.arguments else { return XCTFail("应保留营业额类型") }
        XCTAssertEqual(value.amount, 860)
        let pending = await harness.pending.pending()
        XCTAssertEqual(pending.count, 1)
    }

    @MainActor
    func testRevenueSourceCorrectionIsFieldLevel() async throws {
        let harness = AITestFactory.live(provider: ScriptedAIProvider([]))
        _ = await harness.agent.send("今天现金680")
        let correctedResult = await harness.agent.send("来源改成美团")
        let corrected = try XCTUnwrap(correctedResult.proposal)
        guard case .recordRevenue(let value) = corrected.call.arguments else { return XCTFail() }
        XCTAssertEqual(value.amount, 680)
        XCTAssertEqual(value.source, "美团")
    }

    @MainActor
    func testTodoDateCorrectionPreservesTitle() async throws {
        let harness = AITestFactory.live(provider: ScriptedAIProvider([]))
        let firstResult = await harness.agent.send("提醒我今天下午3点进货")
        let first = try XCTUnwrap(firstResult.proposal)
        let correctedResult = await harness.agent.send("刚才那个改成明天下午4点")
        let corrected = try XCTUnwrap(correctedResult.proposal)
        guard case .createTodo(let before) = first.call.arguments,
              case .createTodo(let after) = corrected.call.arguments else { return XCTFail() }
        XCTAssertEqual(after.title, before.title)
        XCTAssertNotEqual(after.dueDate, before.dueDate)
    }

    @MainActor
    func testMissingCorrectionValueAsksFollowUpWithoutReplacingCard() async throws {
        let harness = AITestFactory.live(provider: ScriptedAIProvider([]))
        let firstResult = await harness.agent.send("今天美团680")
        let first = try XCTUnwrap(firstResult.proposal)
        let result = await harness.agent.send("金额改一下")
        XCTAssertNil(result.proposal)
        XCTAssertTrue(result.assistantMessage?.content.contains("多少") == true)
        let pending = await harness.pending.pending()
        XCTAssertEqual(pending.first?.id, first.id)
    }

    @MainActor
    func testCancelPendingAction() async throws {
        let harness = AITestFactory.live(provider: ScriptedAIProvider([]))
        let firstResult = await harness.agent.send("今天美团680")
        let first = try XCTUnwrap(firstResult.proposal)
        let result = await harness.agent.send("取消刚才那个")
        XCTAssertEqual(result.cancelledProposalIDs, [first.id])
        let pending = await harness.pending.pending()
        let stored = await harness.pending.proposal(id: first.id)
        XCTAssertTrue(pending.isEmpty)
        XCTAssertEqual(stored?.status, .cancelled)
    }
}
