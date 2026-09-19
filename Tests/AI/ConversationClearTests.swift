import XCTest
import SwiftData
@testable import XiaoZhangGui

// MARK: V3.3 AI REAL · 清空对话（8/9/10）
//
// - 清空只删除聊天消息与未确认 ActionCard；
// - 已真实写入业务库的数据、执行幂等日志绝不受影响；
// - 文件存储清空后必须原子落盘，重启 App（新实例）仍为空，文件不损坏。

@MainActor
final class ConversationClearTests: XCTestCase {

    // MARK: 8) clear conversation：消息与未确认卡立即清空（经 AgentCore）

    func testAgentClearEmptiesMessagesAndPendingCards() async {
        let (agent, _, pending, conversation) = AITestFactory.preview()
        let result = await agent.send("今天美团680")
        XCTAssertNotNil(result.proposal)
        let messagesBeforeClear = await agent.messages()
        XCTAssertFalse(messagesBeforeClear.isEmpty)
        let pendingBeforeClear = await pending.pending()
        XCTAssertEqual(pendingBeforeClear.count, 1)

        await agent.clearConversation()

        let messages = await agent.messages()
        XCTAssertTrue(messages.isEmpty, "清空后消息必须立即为空")
        let storedMessages = await conversation.load().messages
        XCTAssertTrue(storedMessages.isEmpty)
        let pendingAfterClear = await pending.pending()
        XCTAssertTrue(pendingAfterClear.isEmpty, "未确认 ActionCard 不得残留")
    }

    // MARK: 9) 文件存储：清空后重启（新实例）仍为空

    func testFileClearPersistsAcrossRelaunch() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-clear-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let conversation = FileConversationStore(directory: dir)
        await conversation.append(AIMessage(role: .user, content: "今天美团680"))
        let pending = FilePendingActionStore(directory: dir)
        let proposal = ActionProposal(
            call: AITestFactory.makeToolCall(.recordRevenue(RevenueArguments(amount: 680))),
            isPreviewOnly: true)
        await pending.upsert(proposal)

        await conversation.clearConversation()
        await pending.clear()

        // 模拟重启：重新从磁盘初始化
        let reopenedConversation = FileConversationStore(directory: dir)
        let reopenedPending = FilePendingActionStore(directory: dir)
        let reopenedMessages = await reopenedConversation.load().messages
        XCTAssertTrue(reopenedMessages.isEmpty, "重启后聊天必须仍为空")
        let reopenedItems = await reopenedPending.pending()
        XCTAssertTrue(reopenedItems.isEmpty, "重启后未确认卡必须仍为空")
    }

    // MARK: 10) 清空聊天绝不影响业务数据库

    func testClearConversationNeverDeletesBusinessRecords() async throws {
        let container = try AppDatabase.makeInMemoryContainer()
        let context = container.mainContext
        let journal = InMemoryExecutionJournal()
        let conversation = InMemoryConversationStore()
        let pending = InMemoryPendingActionStore()

        let env = try AgentEnvironment.makeLive(
            provider: UnconfiguredRemoteProvider(),
            fallback: nil,
            contextProvider: UnavailableBusinessContextProvider(),
            toolExecutor: RepositoryToolExecutor(context: context, journal: journal),
            conversation: conversation,
            pending: pending,
            journal: journal
        )
        let agent = AgentCore(env)

        // 真实写入一笔营业额到业务库
        let call = AITestFactory.makeToolCall(
            .recordRevenue(RevenueArguments(amount: 680, source: "美团", date: Date(), note: "今天美团680")))
        let result = await env.toolExecutor.execute(call)
        guard case .executed = result else { return XCTFail("前置：营业额应已真实写入") }
        XCTAssertEqual(try context.fetch(FetchDescriptor<Performance>()).count, 1)

        // 聊天里留痕 + 未确认卡，然后清空
        await conversation.append(AIMessage(role: .user, content: "今天美团680"))
        let card = ActionProposal(call: AITestFactory.makeToolCall(
            .createMemo(MemoArguments(title: "t", content: "c"))), isPreviewOnly: false)
        await pending.upsert(card)

        await agent.clearConversation()

        // 业务库原封不动
        let rows = try context.fetch(FetchDescriptor<Performance>())
        XCTAssertEqual(rows.count, 1, "清空聊天绝不能删除已保存的营业额")
        XCTAssertEqual(rows.first?.amount, 680)
        // 聊天侧已空
        let finalMessages = await conversation.load().messages
        XCTAssertTrue(finalMessages.isEmpty)
        let finalPending = await pending.pending()
        XCTAssertTrue(finalPending.isEmpty)
    }
}
