import XCTest
@testable import XiaoZhangGui

/// V3.9.2 · AI 上下文预算与档位路由（纯逻辑 + 源码审计）
///
/// 锁两件此前真实存在的问题：
/// 1. `ProviderChain` 永远先打 primary，导致「高质量」档选的 fallback 槽位形同无效（P1-4）；
/// 2. `remoteTurn` 把整段会话原样上送，且 `maxTokens: nil` 无上限（P1-3）。
final class V392AIContextBudgetTests: XCTestCase {

    // MARK: - 上下文预算

    func testTrimKeepsTailWindowAndStartsAtUser() {
        var messages: [AIMessage] = []
        for index in 0..<20 {
            messages.append(AIMessage(role: .user, content: "u\(index)"))
            messages.append(AIMessage(role: .assistant, content: "a\(index)"))
        }
        let trimmed = ConversationBudget.trimmed(messages, maxMessages: 5)
        XCTAssertLessThanOrEqual(trimmed.count, 5, "不得超出预算条数")
        XCTAssertEqual(trimmed.first?.role, .user, "窗口必须从用户发言起手，否则模型看到无来由的回答")
        XCTAssertEqual(trimmed.last?.content, "a19", "必须保留最新一轮")
    }

    func testTrimDropsErrorReplies() {
        let messages = [
            AIMessage(role: .user, content: "今天营业额 800"),
            AIMessage(role: .assistant, content: "网络连接失败，请检查网络后重试", isError: true),
            AIMessage(role: .assistant, content: "已记下今天的营业额。")
        ]
        let trimmed = ConversationBudget.trimmed(messages, maxMessages: 10)
        XCTAssertEqual(trimmed.count, 2, "失败回执是本地 UI 文案，不该喂回模型")
        XCTAssertFalse(trimmed.contains(where: \.isError))
    }

    func testTrimKeepsShortConversationUntouched() {
        let messages = [
            AIMessage(role: .user, content: "今天营业额 800"),
            AIMessage(role: .assistant, content: "已记下。")
        ]
        XCTAssertEqual(ConversationBudget.trimmed(messages, maxMessages: 16).count, 2)
    }

    func testTrimWithZeroBudgetReturnsEmpty() {
        let messages = [AIMessage(role: .user, content: "hi")]
        XCTAssertTrue(ConversationBudget.trimmed(messages, maxMessages: 0).isEmpty)
    }

    func testCompletionTokensAreCapped() {
        XCTAssertEqual(ConversationBudget.maxCompletionTokens, 2048, "回复上限必须显式给出，不能传 nil 无上限")
    }

    // MARK: - 档位路由（P1-4）

    func testHighQualityRouteStartsAtFallbackSlot() async throws {
        let primary = SpyProvider(id: "primary")
        let fallback = SpyProvider(id: "fallback")
        let chain = ProviderChain(primary: primary, fallback: fallback)

        let turn = try await chain.complete(request(providerID: "fallback", tier: .highQuality))

        XCTAssertEqual(turn, .text("fallback"))
        let primaryCalls = await primary.callCount
        let fallbackCalls = await fallback.callCount
        XCTAssertEqual(primaryCalls, 0, "高质量档不该先打主模型")
        XCTAssertEqual(fallbackCalls, 1)
    }

    func testDefaultRouteStartsAtPrimarySlot() async throws {
        let primary = SpyProvider(id: "primary")
        let fallback = SpyProvider(id: "fallback")
        let chain = ProviderChain(primary: primary, fallback: fallback)

        let turn = try await chain.complete(request(providerID: "primary", tier: .freeFirst))

        XCTAssertEqual(turn, .text("primary"))
        let fallbackCalls = await fallback.callCount
        XCTAssertEqual(fallbackCalls, 0)
    }

    func testFallbackSlotFailsOverToPrimary() async throws {
        let primary = SpyProvider(id: "primary")
        let fallback = SpyProvider(id: "fallback", failure: .http(status: 500, body: ""))
        let chain = ProviderChain(primary: primary, fallback: fallback)

        let turn = try await chain.complete(request(providerID: "fallback", tier: .highQuality))

        XCTAssertEqual(turn, .text("primary"), "强模型 5xx 时仍要能降级到主链")
        let route = await primary.lastRoute
        XCTAssertEqual(route?.providerID, "primary", "换槽位后 route 必须同步，便于日志定位")
    }

    func testAuthFailureDoesNotFailOver() async throws {
        let primary = SpyProvider(id: "primary")
        let fallback = SpyProvider(id: "fallback", failure: .http(status: 401, body: ""))
        let chain = ProviderChain(primary: primary, fallback: fallback)

        do {
            _ = try await chain.complete(request(providerID: "fallback", tier: .highQuality))
            XCTFail("鉴权失败不该悄悄换链")
        } catch let failure as ProviderFailure {
            XCTAssertEqual(failure, .http(status: 401, body: ""))
        }
        let primaryCalls = await primary.callCount
        XCTAssertEqual(primaryCalls, 0, "401 不得把无效 Key 轮询到另一家")
    }

    // MARK: - 源码审计（防止回退）

    func testAgentCoreRoutesThroughBudgetAndHasNoForcedTry() throws {
        let source = try readSource("XiaoZhangGui/Features/Assistant/AI/Core/AgentCore.swift")
        XCTAssertTrue(
            source.contains("ConversationBudget.trimmed("),
            "上云上下文必须走预算裁剪，不得整段会话直送"
        )
        XCTAssertFalse(
            source.contains("try! await"),
            "禁止 try! 等待：能力层失败回执请用 appendAssistantUnchecked"
        )
    }

    func testRequestCarriesExplicitCompletionCap() throws {
        let source = try readSource("XiaoZhangGui/Features/Assistant/AI/Providers/OpenAICompatProvider.swift")
        XCTAssertTrue(
            source.contains("maxTokens: ConversationBudget.maxCompletionTokens"),
            "请求必须带 completion 上限，不能传 nil"
        )
    }

    // MARK: - 工具

    private func request(providerID: String, tier: ModelTier) -> ProviderRequest {
        ProviderRequest(
            messages: [AIMessage(role: .user, content: "今天营业额 800")],
            tools: [],
            route: ModelRoute(
                providerID: providerID,
                model: "test.model",
                tier: tier,
                isLocalZeroToken: false
            )
        )
    }

    private func readSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("..")
            .standardized
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

/// 记录调用次数与实际收到的 route（actor 保证并发安全）。
private actor SpyProvider: AIProvider {
    let id: String
    private let failure: ProviderFailure?
    private(set) var callCount = 0
    private(set) var lastRoute: ModelRoute?

    init(id: String, failure: ProviderFailure? = nil) {
        self.id = id
        self.failure = failure
    }

    func complete(_ request: ProviderRequest) async throws -> ProviderTurn {
        callCount += 1
        lastRoute = request.route
        if let failure { throw failure }
        return .text(id)
    }
}
