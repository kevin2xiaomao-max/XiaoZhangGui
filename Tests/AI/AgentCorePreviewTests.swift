import XCTest
@testable import XiaoZhangGui

@MainActor
final class AgentCorePreviewTests: XCTestCase {

    // MARK: 四个范例句 → ActionCard 预览

    func testRevenueExemplarProducesPreviewCard() async {
        let (agent, _, pending, _) = AITestFactory.preview()
        let result = await agent.send("今天美团680")
        guard let proposal = result.proposal else { return XCTFail("应生成 ActionProposal") }
        XCTAssertEqual(proposal.call.name, .recordRevenue)
        XCTAssertTrue(proposal.isPreviewOnly)
        guard case .recordRevenue(let a) = proposal.call.arguments else { return XCTFail() }
        XCTAssertEqual(a.amount, 680)
        XCTAssertEqual(a.source, "美团")
        let messages = await agent.messages()
        XCTAssertEqual(messages.map(\.role), [.user, .assistant])
        let pendingCount = await pending.pending().count
        XCTAssertEqual(pendingCount, 1)
    }

    func testTodoExemplar() async {
        let (agent, _, _, _) = AITestFactory.preview()
        let result = await agent.send("明天下两箱可乐")
        XCTAssertEqual(result.proposal?.call.name, .createTodo)
    }

    func testMemoExemplar() async {
        let (agent, _, _, _) = AITestFactory.preview()
        let result = await agent.send("记一下供应商周五来")
        XCTAssertEqual(result.proposal?.call.name, .createMemo)
    }

    func testDeliveryExemplar() async {
        let (agent, _, _, _) = AITestFactory.preview()
        let result = await agent.send("今晚8点给302送两箱怡宝")
        guard let proposal = result.proposal else { return XCTFail("应生成 ActionProposal") }
        XCTAssertEqual(proposal.call.name, .createDelivery)
        guard case .createDelivery(let a) = proposal.call.arguments else { return XCTFail() }
        XCTAssertEqual(a.customer, "302")
        XCTAssertEqual(a.goodsName, "怡宝")
        XCTAssertEqual(a.quantity, "两箱")
    }

    // MARK: Foundation 确认不写库（写闸门）

    func testConfirmInPreviewNeverExecutes() async throws {
        let (agent, journal, pending, _) = AITestFactory.preview()
        let result = await agent.send("今天美团680")
        let id = try XCTUnwrap(result.proposal?.id)

        let confirmed = await agent.confirm(proposalID: id)
        let updated = try XCTUnwrap(confirmed)
        XCTAssertTrue(updated.previewAcknowledged)
        XCTAssertEqual(updated.status, .pending, "预览态确认后仍不应标记已执行")
        XCTAssertNotNil(updated.resultText)

        let entries = await journal.entries()
        XCTAssertTrue(entries.allSatisfy { $0.status != "executed" }, "Foundation 不允许出现 executed 记录")
        // 待确认仍在（未被当作已保存移除）
        let pendingCount = await pending.pending().count
        XCTAssertEqual(pendingCount, 1)
    }

    // MARK: 普通聊天不出卡

    func testWorldChatReturnsTextOnly() async {
        let (agent, _, _, _) = AITestFactory.preview()
        let result = await agent.send("苹果发布会什么时候开")
        XCTAssertNil(result.proposal)
        XCTAssertTrue(result.assistantMessage?.content.contains("预览版") ?? false)
    }

    // MARK: 经营问答在 Foundation 给说明，不伪造数据

    func testBusinessQueryDoesNotFabricate() async {
        let (agent, _, _, _) = AITestFactory.preview()
        let result = await agent.send("今天还有几单配送")
        XCTAssertNil(result.proposal)
        XCTAssertTrue(result.assistantMessage?.content.contains("预览版") ?? false)
    }

    // MARK: Provider 失败：原文保留、错误可见、可重试
    //
    // AI REAL 起四范例为本地 0 Token 解析，不会调用 Provider；
    // Provider 故障用普通世界知识问题（worldChat 必须上云）验证。
    // 注意：天气类问题自 P0-1 起改为本地固定回复（无天气工具），不再上云。
    func testProviderFailureKeepsUserTextAndShowsError() async {
        let failing = ScriptedAIProvider(id: "broken", [.failure(ProviderFailure.timeout)])
        let (agent, _, _, _) = AITestFactory.preview(provider: failing)
        let result = await agent.send("广东有什么好玩的景点")
        XCTAssertNil(result.proposal)
        XCTAssertTrue(result.assistantMessage?.isError ?? false)
        let messages = await agent.messages()
        XCTAssertEqual(messages.first?.role, .user)
        XCTAssertEqual(messages.first?.content, "广东有什么好玩的景点")
    }

    // MARK: 重复响应得到相同业务指纹（幂等键稳定）

    func testRepeatedUtteranceHasSameFingerprint() async {
        let (agent, _, _, _) = AITestFactory.preview()
        let first = (await agent.send("今天美团680")).proposal
        let second = (await agent.send("今天美团680")).proposal
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertNotEqual(first?.call.id, second?.call.id)
        XCTAssertEqual(ToolIdempotency.fingerprint(for: first!.call),
                       ToolIdempotency.fingerprint(for: second!.call))
    }

    // MARK: 修改 / 取消

    func testCancelRemovesPendingCard() async throws {
        let (agent, _, pending, _) = AITestFactory.preview()
        let result = await agent.send("明天下两箱可乐")
        let id = try XCTUnwrap(result.proposal?.id)
        await agent.cancel(proposalID: id)
        let remaining = await pending.pending()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testModifyReturnsOriginalUserText() async throws {
        let (agent, _, _, _) = AITestFactory.preview()
        let result = await agent.send("明天下两箱可乐")
        let id = try XCTUnwrap(result.proposal?.id)
        let original = await agent.modify(proposalID: id)
        XCTAssertEqual(original, "明天下两箱可乐")
    }
}
