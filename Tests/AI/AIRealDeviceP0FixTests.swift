import XCTest
import SwiftData
@testable import XiaoZhangGui

// MARK: V3.3 AI REAL · 第二轮真机问题 P0-1 ~ P0-6 回归
//
// 对应真机输入：
// - P0-1 明天恩平什么天气啊，帮我查下（READ，不得误建待办）
// - P0-2 今晚8点送3杯珍珠奶茶到幸福路9号，一共45元（五字段 + 确认后才写库）
// - P0-3 提醒我明天3点进货（歧义时间必须澄清，不得回落当前时间）
// - P0-4 普通聊天 / 经营建议直接走云端
// - P0-5 多轮纠正：Todo pending →「不是，改成备忘，没收到钱」
// - P0-6 客户单「还没收钱」不得降级 Todo / Memo，当前模型先明确告知

@MainActor
final class AIRealDeviceP0FixTests: XCTestCase {

    // MARK: 辅助

    private func makeHarness(provider: any AIProvider) throws -> (
        agent: AgentCore,
        context: ModelContext,
        pending: InMemoryPendingActionStore,
        provider: CountingAIProvider
    ) {
        let container = try AppDatabase.makeInMemoryContainer()
        let context = container.mainContext
        let journal = InMemoryExecutionJournal()
        let pending = InMemoryPendingActionStore()
        let counting = CountingAIProvider(wrapping: provider)
        let env = try AgentEnvironment.makeLive(
            provider: counting,
            fallback: nil,
            contextProvider: UnavailableBusinessContextProvider(),
            toolExecutor: RepositoryToolExecutor(context: context, journal: journal),
            conversation: InMemoryConversationStore(),
            pending: pending,
            journal: journal
        )
        return (AgentCore(env), context, pending, counting)
    }

    private func count<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<T>()).count
    }

    private func assertBusinessDBEmpty(_ context: ModelContext, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(try count(Performance.self, in: context), 0, "不应产生营业额", file: file, line: line)
        XCTAssertEqual(try count(Todo.self, in: context), 0, "不应产生待办", file: file, line: line)
        XCTAssertEqual(try count(Memo.self, in: context), 0, "不应产生备忘", file: file, line: line)
        XCTAssertEqual(try count(CustomerRequest.self, in: context), 0, "不应产生配送", file: file, line: line)
    }

    private let router = IntentRouter()
    private let parser = LocalBusinessParser()

    // MARK: P0-1 天气查询是 READ，不是新建待办

    func testP0_1_WeatherQueryClassifiedAsWeather() {
        XCTAssertEqual(router.classify("明天恩平什么天气啊，帮我查下"), .weatherQuery)
        XCTAssertEqual(router.classify("明天会下雨吗"), .weatherQuery)
        // 经营 READ 不能被天气词误伤
        XCTAssertEqual(router.classify("今天还有几单配送"), .businessQuery(.delivery))
    }

    func testP0_1_WeatherReplyIsLocalNoCardNoCloudNoWrite() async throws {
        let harness = try makeHarness(provider: ScriptedAIProvider(id: "x", []))
        let result = await harness.agent.send("明天恩平什么天气啊，帮我查下")

        let reply = try XCTUnwrap(result.assistantMessage?.content)
        XCTAssertTrue(reply.contains("当前无法查询实时天气"))
        XCTAssertNil(result.proposal, "天气查询绝不能出 ActionCard")
        let calls = await harness.provider.callCount
        XCTAssertEqual(calls, 0, "天气回复必须 0 Token")
        try assertBusinessDBEmpty(harness.context)
    }

    // MARK: P0-2 配送五字段 + 确认前零写入

    func testP0_2_DeliveryFieldsMappedCorrectly() async throws {
        let harness = try makeHarness(provider: ScriptedAIProvider(id: "x", []))
        let sentence = "今晚8点送3杯珍珠奶茶到幸福路9号，一共45元"
        let result = await harness.agent.send(sentence)

        let proposal = try XCTUnwrap(result.proposal)
        XCTAssertEqual(proposal.call.name, .createDelivery)
        guard case .createDelivery(let a) = proposal.call.arguments else {
            return XCTFail("应为 createDelivery")
        }
        XCTAssertTrue(a.customer?.isEmpty ?? true, "未提供客户名时 customer 必须为空")
        XCTAssertEqual(a.roomOrAddress, "幸福路9号")
        XCTAssertEqual(a.goodsName, "珍珠奶茶")
        XCTAssertEqual(a.quantity, "3杯")
        XCTAssertEqual(a.amount, 45)
        XCTAssertEqual(a.deliveryTimeText, "今晚8点")
        let time = try XCTUnwrap(a.deliveryTime)
        XCTAssertEqual(Calendar.current.component(.hour, from: time), 20, "今晚8点必须是 20:00，不得回落当前时间")
        XCTAssertTrue((a.content ?? "").contains("珍珠奶茶"))

        let calls = await harness.provider.callCount
        XCTAssertEqual(calls, 0, "高置信本地解析 0 Token")
        // 确认前绝不写库
        try assertBusinessDBEmpty(harness.context)
        XCTAssertEqual(proposal.status, .pending)
    }

    func testP0_2_WritesOnlyAfterConfirm() async throws {
        let harness = try makeHarness(provider: ScriptedAIProvider(id: "x", []))
        let result = await harness.agent.send("今晚8点送3杯珍珠奶茶到幸福路9号，一共45元")
        let proposalID = try XCTUnwrap(result.proposal).id

        let confirmedResult = await harness.agent.confirm(proposalID: proposalID)
        let confirmed = try XCTUnwrap(confirmedResult)
        XCTAssertEqual(confirmed.status, .executed)

        let rows = try harness.context.fetch(FetchDescriptor<CustomerRequest>())
        XCTAssertEqual(rows.count, 1, "确认后且仅确认后写入一条配送")
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.customer, "")
        XCTAssertEqual(row.roomOrAddress, "幸福路9号")
        XCTAssertTrue(row.content.contains("珍珠奶茶"))
        XCTAssertTrue(row.content.contains("3杯"))
        XCTAssertTrue(row.content.contains("45"), "金额必须随单落库，实际：\(row.content)")
        XCTAssertTrue(row.content.contains("今晚8点"))
    }

    // P0-2 既有范例不得回归
    func testP0_2_LegacyRoomDeliveryStillParses() {
        guard case .tool(let arguments)? = parser.parse(
            "今晚8点给302送两箱怡宝", intent: .businessAction(.createDelivery)),
              case .createDelivery(let a) = arguments else {
            return XCTFail("旧范例应继续解析为 createDelivery")
        }
        XCTAssertEqual(a.customer, "302")
        XCTAssertEqual(a.roomOrAddress, "302")
        XCTAssertEqual(a.goodsName, "怡宝")
        XCTAssertEqual(a.quantity, "两箱")
    }

    // MARK: P0-3 模糊时间

    func testP0_3_DateResolutionAfternoonMorningAmbiguous() {
        let now = Date()
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!

        guard case .date(let afternoon) = DatePhraseParser.resolve("明天下午3点进货", now: now) else {
            return XCTFail("明天下午3点应解析为确定时间")
        }
        XCTAssertEqual(cal.component(.hour, from: afternoon), 15)
        XCTAssertEqual(cal.component(.day, from: afternoon), cal.component(.day, from: tomorrow))

        guard case .date(let morning) = DatePhraseParser.resolve("明天上午3点进货", now: now) else {
            return XCTFail("明天上午3点应解析为确定时间")
        }
        XCTAssertEqual(cal.component(.hour, from: morning), 3)

        guard case .ambiguousClock(let token) = DatePhraseParser.resolve("明天3点进货", now: now) else {
            return XCTFail("明天3点必须判定为歧义，而不是偷偷选定时间")
        }
        XCTAssertTrue(token.contains("3"))
    }

    func testP0_3_AmbiguousTimeClarifiesAndNeverWrites() async throws {
        let harness = try makeHarness(provider: ScriptedAIProvider(id: "x", []))
        let result = await harness.agent.send("提醒我明天3点进货")
        XCTAssertNil(result.proposal, "歧义时间不能出待办卡")
        let reply = try XCTUnwrap(result.assistantMessage?.content)
        XCTAssertTrue(reply.contains("凌晨"))
        XCTAssertTrue(reply.contains("下午"))
        try assertBusinessDBEmpty(harness.context)

        // 对照组：下午3点正常出卡，时间 15:00
        let ok = await harness.agent.send("提醒我明天下午3点进货可乐")
        let proposal = try XCTUnwrap(ok.proposal)
        guard case .createTodo(let todo) = proposal.call.arguments else { return XCTFail() }
        XCTAssertEqual(Calendar.current.component(.hour, from: try XCTUnwrap(todo.dueDate)), 15)
        XCTAssertEqual(todo.title, "进货可乐")
    }

    // MARK: P0-4 普通聊天 / 经营建议走云端，时间词不导致误建待办

    func testP0_4_QuestionsGoToWorldChat() {
        XCTAssertEqual(router.classify("可乐最近卖不动，有什么经营建议"), .worldChat)
        XCTAssertEqual(router.classify("明天手机发布会什么时候开"), .worldChat)
        // CREATE 范例不回归
        XCTAssertEqual(router.classify("明天下两箱可乐"), .businessAction(.createTodo))
    }

    func testP0_4_WorldChatCallsRemoteProvider() async throws {
        let harness = try makeHarness(provider: ScriptedAIProvider(
            id: "cloud", [.success(.text("可以试试做个第二件半价"))]))
        let result = await harness.agent.send("可乐最近卖不动，有什么经营建议")
        let calls = await harness.provider.callCount
        XCTAssertEqual(calls, 1, "经营建议应直接走远程模型")
        XCTAssertNil(result.proposal)
        XCTAssertEqual(result.assistantMessage?.content, "可以试试做个第二件半价")
    }

    // MARK: P0-5 多轮纠正：旧 Todo 立即失效，只剩新的 Memo，确认前零写入

    func testP0_5_CorrectionCancelsTodoAndReplacesWithMemo() async throws {
        let harness = try makeHarness(provider: ScriptedAIProvider(id: "x", []))

        let first = await harness.agent.send("明天下午3点提醒我进货可乐")
        let oldID = try XCTUnwrap(first.proposal).id
        XCTAssertEqual(first.proposal?.call.name, .createTodo)

        let second = await harness.agent.send("不是，改成备忘，没收到钱")
        let newProposal = try XCTUnwrap(second.proposal)
        XCTAssertEqual(newProposal.call.name, .createMemo)
        guard case .createMemo(let memo) = newProposal.call.arguments else { return XCTFail() }
        XCTAssertEqual(memo.title, "没收到钱")
        XCTAssertTrue(memo.content?.contains("没收到钱") ?? false)
        XCTAssertFalse(memo.content?.contains("不是") ?? true, "纠正话术不得进入业务字段")
        XCTAssertFalse(memo.content?.contains("改成") ?? true, "纠正话术不得进入业务字段")

        // 同一时刻只有一个有效 pending
        let active = await harness.pending.pending()
        XCTAssertEqual(active.map(\.id), [newProposal.id])
        let cancelledOld = await harness.pending.proposal(id: oldID)
        let old = try XCTUnwrap(cancelledOld)
        XCTAssertEqual(old.status, .cancelled, "旧 Todo proposal 必须立即取消")

        // 确认前数据库无任何新记录
        try assertBusinessDBEmpty(harness.context)
    }

    func testP0_5_CorrectionParserBothRealPhrases() {
        let a = CorrectionParser.detect("不是，改成备忘，没收到钱")
        XCTAssertEqual(a?.targetTool, .createMemo)
        XCTAssertEqual(a?.cleanedText, "没收到钱")

        let b = CorrectionParser.detect("没有，是帮我记录备忘了，是没收到钱")
        XCTAssertEqual(b?.targetTool, .createMemo)
        XCTAssertEqual(b?.cleanedText, "没收到钱")

        // 没有 pending 语义时，普通业务句不应被当成纠正
        XCTAssertNil(CorrectionParser.detect("明天下午3点提醒我进货"))
    }

    // MARK: P0-6 客户单未收款：不降级、不写库，明确说明

    func testP0_6_UnpaidCustomerOrderDoesNotCreateTodoOrMemo() async throws {
        let harness = try makeHarness(provider: ScriptedAIProvider(id: "x", []))
        let result = await harness.agent.send("没有，是帮我记录这个客人的东西还没收钱")
        XCTAssertNil(result.proposal, "未收款语义不得生成任何 ActionCard")
        let reply = try XCTUnwrap(result.assistantMessage?.content)
        XCTAssertTrue(reply.contains("未收款") || reply.contains("还没收款"))
        try assertBusinessDBEmpty(harness.context)
    }

    func testP0_6_UnpaidPhraseVariantsRecognized() {
        for phrase in ["这个客人还没给钱", "客户阿东欠着", "顾客那笔还没付款", "他的单未收款"] {
            XCTAssertTrue(CustomerPaymentIntent.isUnpaidCustomerOrder(phrase), "应识别：\(phrase)")
        }
        // P0-5 的备忘场景没有客户语境词，不能被拦截
        XCTAssertFalse(CustomerPaymentIntent.isUnpaidCustomerOrder("是没收到钱"))
    }

    /// P0-6 目标结构预演：多商品 ×N 解析（schema 授权前只验证解析侧，不落未收款字段）
    func testP0_6_MultiItemCustomerOrderParsing() {
        guard case .tool(let arguments)? = parser.parse(
            "给阿东送百年糊涂×2、王老吉×3、番茄酱×1",
            intent: .businessAction(.createDelivery)),
              case .createDelivery(let a) = arguments else {
            return XCTFail("客户订单多商品应解析为 createDelivery")
        }
        XCTAssertEqual(a.customer, "阿东")
        XCTAssertEqual(a.goodsName, "百年糊涂")
        XCTAssertEqual(a.quantity, "×2")
        XCTAssertTrue(a.content?.contains("百年糊涂 ×2") ?? false)
        XCTAssertTrue(a.content?.contains("王老吉 ×3") ?? false)
        XCTAssertTrue(a.content?.contains("番茄酱 ×1") ?? false)
    }
}
