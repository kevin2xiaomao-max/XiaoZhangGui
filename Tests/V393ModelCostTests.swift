import XCTest
@testable import XiaoZhangGui

// MARK: - V3.9.3 D · 模型与费用管理：次数级计量、真实模型显示、输入预算。

final class V393ModelCostTests: XCTestCase {

    private func isolatedStore() -> AIUsageStore {
        AIUsageStore(userDefaults: UserDefaults(suiteName: "xzg-test-\(UUID().uuidString)")!)
    }

    private func message(_ content: String, role: AIRole = .user, proposalID: UUID? = nil) -> AIMessage {
        AIMessage(role: role, content: content, proposalID: proposalID)
    }

    // MARK: 计量：次数级，不虚构 token / 费用

    func testUsageStoreCountsOutcomesAndNeverInventsTokens() async {
        let store = isolatedStore()
        await store.record(slot: "primary", tier: .freeFirst, outcome: .success)
        await store.record(slot: "fallback", tier: .highQuality, outcome: .failed)
        await store.record(slot: "primary", tier: .freeFirst, outcome: .cancelled)
        let summary = await store.summary()
        XCTAssertEqual(summary.total, 3)
        XCTAssertEqual(summary.success, 1)
        XCTAssertEqual(summary.failed, 1)
        XCTAssertEqual(summary.cancelled, 1)
        XCTAssertEqual(summary.bySlot["primary"], 2)
        XCTAssertEqual(summary.bySlot["fallback"], 1)
        XCTAssertFalse(summary.hasTokenData, "未核实服务商 usage 前绝不能有 token 数据")
        XCTAssertFalse(summary.hasCostData, "无可信价格配置时绝不能有费用估算")
    }

    func testProviderChainRecordsPerAttemptAndUsesRealFallbackModel() async throws {
        let store = isolatedStore()
        // fallback 先失败（可转移）→ primary 成功：应记 fallback 失败 + primary 成功两条。
        let failingFallback = FailingProvider(failure: .network("断网"))
        let chain = ProviderChain(
            primary: SucceedingProvider(), fallback: failingFallback,
            meter: store, fallbackModelDisplay: "deepseek-v4-pro")
        let request = ProviderRequest(
            messages: [message("你好")], tools: [],
            route: ModelRoute(providerID: "fallback", model: "fallback.strong", tier: .highQuality, isLocalZeroToken: false),
            context: .empty)
        let turn = try await chain.complete(request)
        guard case .text = turn else { return XCTFail("应由 primary 兜底成功") }
        let summary = await store.summary()
        XCTAssertEqual(summary.total, 2, "每次尝试各记一条，不合并、不丢失败")
        XCTAssertEqual(summary.failed, 1)
        XCTAssertEqual(summary.success, 1)
        // 真实模型显示：链的 fallbackModelDisplay 必须取自配置，而非占位串。
        XCTAssertEqual(chain.fallbackModelDisplay, "deepseek-v4-pro")
        XCTAssertNotEqual(chain.fallbackModelDisplay, "fallback.strong")
    }

    // MARK: 输入预算：不丢当前意图与待确认操作

    func testInputBudgetKeepsCurrentIntentAndPendingCards() {
        var messages: [AIMessage] = []
        for index in 0..<10 {
            messages.append(message("旧话题 \(index)：" + String(repeating: "中", count: 300), role: index % 2 == 0 ? .user : .assistant))
        }
        let pendingID = UUID()
        messages.append(message("待确认的卡片说明", role: .assistant, proposalID: pendingID))
        messages.append(message("当前意图：明天给302送两箱怡宝", role: .user))
        let trimmed = ConversationBudget.trimmedForInputBudget(messages, maxTokens: 100)
        XCTAssertTrue(trimmed.contains(where: { $0.content.contains("当前意图") }), "当前意图绝不能被截掉")
        XCTAssertTrue(trimmed.contains(where: { $0.proposalID == pendingID }), "待确认操作绝不能被截掉")
        XCTAssertLessThanOrEqual(ConversationBudget.estimatedInputTokens(for: trimmed), 100 + 200,
                                 "预算裁剪后应收敛（截断标注本身占少量 token，允差 200）")
    }

    func testInputBudgetKeepsShortConversationUntouched() {
        let messages = [message("今天美团680"), message("已记录", role: .assistant)]
        XCTAssertEqual(ConversationBudget.trimmedForInputBudget(messages), messages)
    }

    func testEstimatedTokensDistinguishesAsciiAndChinese() {
        let ascii = ConversationBudget.estimatedInputTokens(for: [message(String(repeating: "a", count: 400))])
        let chinese = ConversationBudget.estimatedInputTokens(for: [message(String(repeating: "中", count: 400))])
        XCTAssertEqual(ascii, 100, "ASCII 约 4 字符 1 token")
        XCTAssertEqual(chinese, 400, "中文约 1 字 1 token（估算口径）")
        XCTAssertGreaterThan(chinese, ascii)
    }
}

// MARK: - 测试替身（与 ProviderChainTests 同款语义的轻量版）

private struct SucceedingProvider: AIProvider {
    let id = "test-primary"
    func complete(_ request: ProviderRequest) async throws -> ProviderTurn { .text("ok") }
}

private struct FailingProvider: AIProvider {
    let id = "test-fallback"
    let failure: ProviderFailure
    func complete(_ request: ProviderRequest) async throws -> ProviderTurn { throw failure }
}
