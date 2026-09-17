import XCTest
@testable import XiaoZhangGui

// MARK: - Free First · Local First（0 Token）
//
// 四范例 CREATE 与四类 READ 必须本地闭环，Provider 调用次数为 0；
// 只有本地无把握 / 普通聊天才允许上云。

@MainActor
final class LocalFirstZeroTokenTests: XCTestCase {

    // MARK: 四范例 CREATE：0 Token 直接出卡

    func testFourExemplarsNeverCallProvider() async {
        for utterance in [
            "今天美团680",
            "明天下两箱可乐",
            "记一下供应商周五来",
            "今晚8点给302送两箱怡宝"
        ] {
            let counting = CountingAIProvider(wrapping: ScriptedAIProvider(
                id: "should-not-run",
                [.success(.text("不应被调用"))]))
            let (agent, _, _, _) = AITestFactory.live(provider: counting)
            let result = await agent.send(utterance)
            let calls = await counting.callCount
            XCTAssertEqual(calls, 0, "「\(utterance)」必须本地解析，不得消耗 Token")
            XCTAssertNotNil(result.proposal, "「\(utterance)」应直接生成 ActionCard")
        }
    }

    func testLocalRevenueExemplarFields() async {
        let counting = CountingAIProvider(wrapping: ScriptedAIProvider(id: "x", []))
        let (agent, _, _, _) = AITestFactory.live(provider: counting)
        let result = await agent.send("今天美团680")
        guard case .recordRevenue(let a) = result.proposal?.call.arguments else {
            return XCTFail("应解析为 recordRevenue")
        }
        XCTAssertEqual(a.amount, 680)
        XCTAssertEqual(a.source, "美团")
    }

    func testLocalDeliveryExemplarFields() async {
        let counting = CountingAIProvider(wrapping: ScriptedAIProvider(id: "x", []))
        let (agent, _, _, _) = AITestFactory.live(provider: counting)
        let result = await agent.send("今晚8点给302送两箱怡宝")
        guard case .createDelivery(let a) = result.proposal?.call.arguments else {
            return XCTFail("应解析为 createDelivery")
        }
        XCTAssertEqual(a.customer, "302")
        XCTAssertEqual(a.goodsName, "怡宝")
        XCTAssertEqual(a.quantity, "两箱")
        XCTAssertNotNil(a.deliveryTime)
    }

    // MARK: 信息不足：本地追问，仍 0 Token，不出卡

    func testMissingAmountClarifiesLocally() async {
        let counting = CountingAIProvider(wrapping: ScriptedAIProvider(id: "x", []))
        let (agent, _, _, _) = AITestFactory.live(provider: counting)
        let result = await agent.send("美团卖了")
        XCTAssertNil(result.proposal)
        XCTAssertTrue(result.assistantMessage?.content.contains("金额") ?? false)
        XCTAssertFalse(result.assistantMessage?.isError ?? true, "追问是普通回复，不是错误")
        XCTAssertEqual(await counting.callCount, 0)
    }

    // MARK: 普通聊天：必须上云

    func testWorldChatCallsProvider() async {
        let counting = CountingAIProvider(wrapping: ScriptedAIProvider(
            id: "cloud", [.success(.text("这是网络回答"))]))
        let (agent, _, _, _) = AITestFactory.live(provider: counting)
        let result = await agent.send("苹果发布会什么时候开")
        XCTAssertEqual(await counting.callCount, 1)
        XCTAssertNil(result.proposal)
        XCTAssertEqual(result.assistantMessage?.content, "这是网络回答")
    }

    // MARK: 四类 READ：本地聚合回答，0 Token

    func testFourReadKindsAnswerLocally() async {
        let scoped = ScopedBusinessContext(
            revenueTodayTotal: 680, revenueTodayCount: 3,
            todoTodayTitles: ["下可乐", "联系供应商"],
            recentMemoTitles: ["周五对账"],
            expiringTitles: ["牛奶 2 瓶"],
            deliveryPendingCount: 2, deliveryDeliveringCount: 1)
        let reader = ScriptedBusinessContextProvider(scoped)
        let counting = CountingAIProvider(wrapping: ScriptedAIProvider(id: "x", []))
        let (agent, _, _, _) = AITestFactory.live(provider: counting, contextProvider: reader)

        let cases: [(String, String)] = [
            ("今天营业额多少", "680"),
            ("今天还有什么待办", "下可乐"),
            ("最近有什么备忘", "周五对账"),
            ("最近有什么临期商品", "牛奶"),
            ("今天还有几单配送", "待处理")
        ]
        for (question, expected) in cases {
            let result = await agent.send(question)
            XCTAssertEqual(await counting.callCount, 0, "READ「\(question)」不得调用 Provider")
            XCTAssertNil(result.proposal, "READ 不出 ActionCard")
            XCTAssertTrue(result.assistantMessage?.content.contains(expected) ?? false,
                          "「\(question)」应答应包含 \(expected)，实际：\(result.assistantMessage?.content ?? "")")
        }
    }

    func testEmptyKindsRequestsZeroContext() async {
        let reader = ScriptedBusinessContextProvider(.empty)
        let counting = CountingAIProvider(wrapping: ScriptedAIProvider(id: "x", []))
        let (agent, _, _, _) = AITestFactory.live(provider: counting, contextProvider: reader)
        _ = await agent.send("今天营业额多少")
        let requested = await reader.requestedKinds
        XCTAssertEqual(requested.last, [.revenueToday])
    }

    // MARK: 云端模型仍可对本地未识别的表达返回 ToolCall（worldChat → tool）

    func testCloudToolCallStillProducesCard() async {
        let call = ToolCall(id: ToolCall.makeID(), name: .createTodo,
                            arguments: .createTodo(TodoArguments(
                                title: "给老客户回电话", detail: nil, dueDate: nil, priority: 0)))
        let provider = ScriptedAIProvider(id: "cloud", [.success(.toolCall(call))])
        let (agent, _, _, _) = AITestFactory.live(provider: provider)
        // 纯聊天表达（无任何经营动作词）→ worldChat 上云，模型仍可返回工具调用
        let result = await agent.send("解释一下相对论")
        XCTAssertNotNil(result.proposal)
        XCTAssertEqual(result.proposal?.call.name, .createTodo)
        XCTAssertFalse(result.proposal?.isPreviewOnly ?? true, "live 闸门提案不得标记 previewOnly")
    }
}
