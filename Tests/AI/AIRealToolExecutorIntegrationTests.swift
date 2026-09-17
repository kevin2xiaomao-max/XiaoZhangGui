import XCTest
import SwiftData
@testable import XiaoZhangGui

// MARK: - AI REAL · ToolRouter → Repository 真实写入集成测试
//
// 使用内存 SwiftData 容器（与 baseline DatabaseSafetyTests 同一搭法），
// 验证：4 个 CREATE 真实落库、未确认 / 取消零写入、确认只写一次、
// toolCallID + 业务指纹双幂等、执行日志跨实例恢复防重。
// 这些测试不发任何网络请求，也不碰真实 Keychain。
//
// 类名以 AIReal 开头：SwiftData 集成测试在宿主冷启动后最健康的时间窗最先执行，
// 规避预发布版 CI 模拟器运行约 5~6 分钟后出现的连接停滞 / 宿主重启级联。

@MainActor
final class AIRealToolExecutorIntegrationTests: XCTestCase {

    // MARK: 辅助

    private func makeHarness() throws -> (
        container: ModelContainer,
        context: ModelContext,
        journal: InMemoryExecutionJournal,
        executor: RepositoryToolExecutor
    ) {
        let container = try AppDatabase.makeInMemoryContainer()
        let context = container.mainContext
        let journal = InMemoryExecutionJournal()
        let executor = RepositoryToolExecutor(context: context, journal: journal)
        return (container, context, journal, executor)
    }

    private func makeLiveAgent(
        context: ModelContext,
        journal: InMemoryExecutionJournal,
        provider: any AIProvider = UnconfiguredRemoteProvider()
    ) throws -> AgentCore {
        let env = try AgentEnvironment.makeLive(
            provider: provider,
            fallback: nil,
            contextProvider: UnavailableBusinessContextProvider(),
            toolExecutor: RepositoryToolExecutor(context: context, journal: journal),
            conversation: InMemoryConversationStore(),
            pending: InMemoryPendingActionStore(),
            journal: journal
        )
        return AgentCore(env)
    }

    private func count<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> Int {
        // 与基线测试一致：裸 FetchDescriptor + Swift 侧计数（不用 fetchCount）。
        try context.fetch(FetchDescriptor<T>()).count
    }

    private func revenueCall(id: String = ToolCall.makeID(), amount: Double = 680,
                             source: String = "美团", date: Date = Date()) -> ToolCall {
        ToolCall(id: id, name: .recordRevenue,
                 arguments: .recordRevenue(RevenueArguments(amount: amount, source: source, date: date, note: nil)))
    }

    // MARK: 4 个 CREATE 真实落库

    func testRecordRevenueWritesPerformance() async throws {
        let (_, context, _, executor) = try makeHarness()
        XCTAssertEqual(try count(Performance.self, in: context), 0)

        let result = await executor.execute(revenueCall())
        guard case .executed(let recordID, _) = result else { return XCTFail("应执行成功：\(result)") }
        XCTAssertFalse(recordID.isEmpty)

        let rows = try context.fetch(FetchDescriptor<Performance>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.amount, 680)
        XCTAssertEqual(rows.first?.incomeSource, IncomeSource.meituan.rawValue)
        XCTAssertTrue(rows.first?.note.contains("美团") ?? false)
    }

    func testCreateTodoWritesTodo() async throws {
        let (_, context, _, executor) = try makeHarness()
        let due = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let call = ToolCall(id: ToolCall.makeID(), name: .createTodo,
                            arguments: .createTodo(TodoArguments(title: "下两箱可乐", detail: "", dueDate: due, priority: 1)))
        let result = await executor.execute(call)
        guard case .executed = result else { return XCTFail("应执行成功：\(result)") }

        let rows = try context.fetch(FetchDescriptor<Todo>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.title, "下两箱可乐")
        XCTAssertEqual(rows.first?.priority, 1)
        XCTAssertFalse(rows.first?.isCompleted ?? true)
    }

    func testCreateMemoWritesMemo() async throws {
        let (_, context, _, executor) = try makeHarness()
        let call = ToolCall(id: ToolCall.makeID(), name: .createMemo,
                            arguments: .createMemo(MemoArguments(title: "供应商周五来", content: "周五上午送货")))
        let result = await executor.execute(call)
        guard case .executed = result else { return XCTFail("应执行成功：\(result)") }

        let rows = try context.fetch(FetchDescriptor<Memo>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.title, "供应商周五来")
        XCTAssertEqual(rows.first?.content, "周五上午送货")
    }

    func testCreateDeliveryWritesCustomerRequest() async throws {
        let (_, context, _, executor) = try makeHarness()
        let call = ToolCall(id: ToolCall.makeID(), name: .createDelivery,
                            arguments: .createDelivery(DeliveryArguments(
                                customer: "302", roomOrAddress: "302", phone: "",
                                content: "怡宝两箱", goodsName: "怡宝", quantity: "两箱",
                                deliveryTime: nil, deliveryTimeText: "今晚8点", note: nil)))
        let result = await executor.execute(call)
        guard case .executed = result else { return XCTFail("应执行成功：\(result)") }

        let rows = try context.fetch(FetchDescriptor<CustomerRequest>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.customer, "302")
        XCTAssertTrue(rows.first?.content.contains("怡宝") ?? false)
        XCTAssertTrue(rows.first?.content.contains("今晚8点") ?? false)
        XCTAssertEqual(rows.first?.status, CustomerStatus.pending.rawValue)
    }

    // MARK: 非法参数不写库

    func testRevenueWithoutAmountFailsAndWritesNothing() async throws {
        let (_, context, _, executor) = try makeHarness()
        let call = ToolCall(id: ToolCall.makeID(), name: .recordRevenue,
                            arguments: .recordRevenue(RevenueArguments(amount: nil, source: "美团", date: nil, note: nil)))
        let result = await executor.execute(call)
        guard case .failed = result else { return XCTFail("应失败：\(result)") }
        XCTAssertEqual(try count(Performance.self, in: context), 0)
    }

    // MARK: 未确认 / 取消：零写入

    func testProposalBeforeConfirmWritesNothing() async throws {
        let (_, context, journal, _) = try makeHarness()
        let agent = try makeLiveAgent(context: context, journal: journal)

        let result = await agent.send("今天美团680")
        XCTAssertNotNil(result.proposal, "本地 0-token 应直接出卡")
        XCTAssertEqual(try count(Performance.self, in: context), 0, "未确认不得写库")
    }

    func testCancelWritesNothing() async throws {
        let (_, context, journal, _) = try makeHarness()
        let agent = try makeLiveAgent(context: context, journal: journal)

        let result = await agent.send("今天美团680")
        let id = try XCTUnwrap(result.proposal?.id)
        await agent.cancel(proposalID: id)
        XCTAssertEqual(try count(Performance.self, in: context), 0, "取消不得写库")
    }

    // MARK: 确认：只写一次；重复确认不重复

    func testConfirmWritesExactlyOnce() async throws {
        let (_, context, journal, _) = try makeHarness()
        let agent = try makeLiveAgent(context: context, journal: journal)

        let result = await agent.send("今天美团680")
        let id = try XCTUnwrap(result.proposal?.id)

        let confirmed = await agent.confirm(proposalID: id)
        let first: ActionProposal = try XCTUnwrap(confirmed)
        XCTAssertEqual(first.status, .executed)
        XCTAssertEqual(try count(Performance.self, in: context), 1)

        // 再次确认同一提案：提案已非 pending，Agent 层直接拒绝（返回 nil），
        // 即使绕过 UI 重放，执行器还有 toolCallID / 指纹双判重兜底。
        let second = await agent.confirm(proposalID: id)
        XCTAssertNil(second, "已执行的提案不允许二次确认")
        XCTAssertEqual(try count(Performance.self, in: context), 1, "重复确认不得二次写库")
    }

    // MARK: 执行器级 toolCallID 幂等

    func testExecutorRejectsDuplicateCallID() async throws {
        let (_, context, journal, executor) = try makeHarness()
        let call = revenueCall(id: "call_fixed_1")

        let first = await executor.execute(call)
        guard case .executed = first else { return XCTFail("首次应成功：\(first)") }

        let second = await executor.execute(call)
        guard case .duplicate = second else { return XCTFail("同 callID 必须判重：\(second)") }
        XCTAssertEqual(try count(Performance.self, in: context), 1)
    }

    // MARK: 业务指纹幂等（不同 callID、同一笔业务）

    func testExecutorRejectsDuplicateBusinessFingerprint() async throws {
        let (_, context, journal, executor) = try makeHarness()
        let first = revenueCall(id: "call_a", amount: 680, source: "美团")
        let second = revenueCall(id: "call_b", amount: 680, source: "美团")
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(ToolIdempotency.fingerprint(for: first),
                       ToolIdempotency.fingerprint(for: second))

        _ = await executor.execute(first)
        let result = await executor.execute(second)
        guard case .duplicate = result else { return XCTFail("同业务指纹必须判重：\(result)") }
        XCTAssertEqual(try count(Performance.self, in: context), 1)
    }

    // MARK: pending / failed 日志不阻止后续执行

    func testPendingJournalEntryDoesNotBlockExecution() async throws {
        let (_, context, journal, executor) = try makeHarness()
        let call = revenueCall(id: "call_pending_1")
        // 模拟崩溃前只写了 pending 日志
        await journal.append(JournalEntry(toolCallID: call.id,
                                          fingerprint: ToolIdempotency.fingerprint(for: call),
                                          toolName: ToolName.recordRevenue.rawValue,
                                          status: ProposalStatus.pending.rawValue,
                                          recordID: nil, createdAt: .now))
        let result = await executor.execute(call)
        guard case .executed = result else { return XCTFail("pending 不应阻止执行：\(result)") }
        XCTAssertEqual(try count(Performance.self, in: context), 1)
    }

    // MARK: READ 工具不允许经过写执行器

    func testSearchRecordsNeverWrites() async throws {
        let (_, context, _, executor) = try makeHarness()
        let call = ToolCall(id: ToolCall.makeID(), name: .searchRecords,
                            arguments: .searchRecords(SearchRecordsArguments(query: nil, kinds: [.revenueToday])))
        let result = await executor.execute(call)
        guard case .failed = result else { return XCTFail("READ 到达写执行器必须失败：\(result)") }
        XCTAssertEqual(try count(Performance.self, in: context), 0)
    }
}
