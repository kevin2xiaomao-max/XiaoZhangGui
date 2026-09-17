import XCTest
import LLMProviderKit
@testable import XiaoZhangGui

// MARK: - OpenAI 兼容 Provider（DeepSeek）适配层测试
//
// 不发真实网络、不消耗 Token：第三方 completion 用脚本替身，
// 只验证请求构造、响应解析、错误映射与 fallback 行为。

@MainActor
final class OpenAICompatProviderTests: XCTestCase {

    // MARK: 替身

    actor ScriptedChatCompletion: XZGChatCompleting {
        private let result: Result<LLMResponse, Error>
        private(set) var capturedRequest: LLMRequest?
        private(set) var callCount = 0

        init(_ result: Result<LLMResponse, Error>) {
            self.result = result
        }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            callCount += 1
            capturedRequest = request
            switch result {
            case .success(let response): return response
            case .failure(let error): throw error
            }
        }
    }

    struct InMemoryCredentials: AIProviderCredentialStoring {
        var primary: String
        var fallback: String
        func primaryAPIKey() -> String { primary }
        func fallbackAPIKey() -> String { fallback }
    }

    private func baseRequest(_ userText: String = "今天美团680") -> ProviderRequest {
        ProviderRequest(
            messages: [AIMessage(role: .user, content: userText)],
            tools: ToolCatalog.definitions(),
            route: ModelRoute(providerID: "primary-deepseek", model: "deepseek-chat",
                              tier: .freeFirst, isLocalZeroToken: false),
            context: .empty
        )
    }

    private func textResponse(_ text: String = "好的") -> LLMResponse {
        LLMResponse(text: text, request: LLMRequest(model: "m", messages: []), providerName: "openai")
    }

    private func toolResponse(name: String, arguments: String) -> LLMResponse {
        let call = LLMToolCall(id: "tc_1", name: name, arguments: arguments)
        return LLMResponse(text: "", toolCalls: [call],
                           request: LLMRequest(model: "m", messages: []), providerName: "openai")
    }

    private func makeProvider(_ chat: ScriptedChatCompletion) -> OpenAICompatProvider {
        OpenAICompatProvider(id: "test", model: "deepseek-chat", chat: chat)
    }

    // MARK: 请求构造

    func testRequestContainsSystemPromptToolsAndUserMessage() async throws {
        let chat = ScriptedChatCompletion(.success(textResponse()))
        let provider = makeProvider(chat)
        _ = try? await provider.complete(baseRequest())
        let request = await chat.capturedRequest
        let unwrapped = try XCTUnwrap(request)
        XCTAssertEqual(unwrapped.model, "deepseek-chat")
        XCTAssertTrue(unwrapped.messages.contains { $0.role == .system })
        XCTAssertTrue(unwrapped.messages.contains { $0.content == "今天美团680" })
        XCTAssertEqual(Set(unwrapped.tools.map(\.name)),
                       Set(["recordRevenue", "createTodo", "createMemo", "createDelivery", "searchRecords"]))
        // 普通请求 context 为空：不得注入任何经营数据
        XCTAssertFalse(unwrapped.messages.map(\.content).joined().contains("revenueTodayTotal"))
    }

    // MARK: 文本响应

    func testPlainTextResponse() async throws {
        let provider = makeProvider(ScriptedChatCompletion(.success(textResponse("今天天气不错"))))
        let turn = try await provider.complete(baseRequest("广东天气怎么样"))
        guard case .text(let text) = turn else { return XCTFail("应为文本回复") }
        XCTAssertEqual(text, "今天天气不错")
    }

    // MARK: 工具调用解析

    func testRevenueToolCallDecoded() async throws {
        let json = #"{"amount":680,"source":"美团","date":"2026-09-18T00:00:00Z"}"#
        let provider = makeProvider(ScriptedChatCompletion(
            .success(toolResponse(name: "recordRevenue", arguments: json))))
        let turn = try await provider.complete(baseRequest())
        guard case .toolCall(let call) = turn else { return XCTFail("应为工具调用") }
        XCTAssertEqual(call.name, .recordRevenue)
        XCTAssertTrue(call.id.hasPrefix("call_tc_1"), "模型 toolCall id 应作为幂等键前缀")
        guard case .recordRevenue(let args) = call.arguments else { return XCTFail() }
        XCTAssertEqual(args.amount, 680)
        XCTAssertEqual(args.source, "美团")
        XCTAssertNotNil(args.date, "ISO8601 日期必须可解析")
    }

    func testDeliveryToolCallDecoded() async throws {
        let json = #"{"customer":"302","goodsName":"怡宝","quantity":"两箱","deliveryTimeText":"今晚8点"}"#
        let provider = makeProvider(ScriptedChatCompletion(
            .success(toolResponse(name: "createDelivery", arguments: json))))
        let turn = try await provider.complete(baseRequest("今晚8点给302送两箱怡宝"))
        guard case .toolCall(let call) = turn,
              case .createDelivery(let args) = call.arguments else { return XCTFail() }
        XCTAssertEqual(args.customer, "302")
        XCTAssertEqual(args.goodsName, "怡宝")
        XCTAssertEqual(args.quantity, "两箱")
    }

    func testMalformedToolArgumentsFailClosed() async {
        let provider = makeProvider(ScriptedChatCompletion(
            .success(toolResponse(name: "createTodo", arguments: "{不是合法 JSON"))))
        do {
            _ = try await provider.complete(baseRequest())
            return XCTFail("坏 JSON 必须抛错")
        } catch let failure as ProviderFailure {
            guard case .decoding = failure else { return XCTFail("应为 decoding，实际 \(failure)") }
        } catch {
            return XCTFail("应抛 ProviderFailure，实际 \(error)")
        }
    }

    func testUnknownToolRejected() async {
        let provider = makeProvider(ScriptedChatCompletion(
            .success(toolResponse(name: "deleteEverything", arguments: "{}"))))
        do {
            _ = try await provider.complete(baseRequest())
            return XCTFail("未知工具必须拒绝")
        } catch let failure as ProviderFailure {
            guard case .decoding = failure else { return XCTFail() }
        } catch {
            return XCTFail("应抛 ProviderFailure，实际 \(error)")
        }
    }

    func testEmptyResponseFailsClosed() async {
        let response = LLMResponse(text: "   ", request: LLMRequest(model: "m", messages: []),
                                   providerName: "openai")
        let provider = makeProvider(ScriptedChatCompletion(.success(response)))
        do {
            _ = try await provider.complete(baseRequest())
            XCTFail("空响应必须抛错")
        } catch let failure as ProviderFailure {
            guard case .decoding = failure else { return XCTFail("应为 decoding") }
        } catch {
            XCTFail("应抛 ProviderFailure，实际 \(error)")
        }
    }

    // MARK: 错误映射与换链策略

    func testHTTP401DoesNotFailover() {
        let failure = OpenAICompatProvider.mapError(.httpError(401, nil))
        guard case .http(let status, _) = failure else { return XCTFail() }
        XCTAssertEqual(status, 401)
        XCTAssertFalse(failure.allowsFailover, "401 不得换链")
    }

    func testRetryableErrorsFailover() {
        XCTAssertTrue(OpenAICompatProvider.mapError(.httpError(500, nil)).allowsFailover)
        XCTAssertTrue(OpenAICompatProvider.mapError(.httpError(429, nil)).allowsFailover)
        let timeout = OpenAICompatProvider.mapError(.networkError("The request timed out."))
        guard case .timeout = timeout else { return XCTFail("应映射为 timeout") }
        XCTAssertTrue(timeout.allowsFailover)
        XCTAssertTrue(OpenAICompatProvider.mapError(.networkError("offline")).allowsFailover)
    }

    func testFallbackSucceedsWhenPrimaryFails() async throws {
        let primary = makeProvider(ScriptedChatCompletion(.failure(ProviderFailure.http(status: 500, body: ""))))
        let fallback = makeProvider(ScriptedChatCompletion(.success(textResponse("备用回答"))))
        let chain = ProviderChain(primary: primary, fallback: fallback)
        let turn = try await chain.complete(baseRequest())
        guard case .text(let text) = turn else { return XCTFail() }
        XCTAssertEqual(text, "备用回答")
    }

    func testBothProvidersFail() async {
        let primary = makeProvider(ScriptedChatCompletion(.failure(ProviderFailure.timeout)))
        let fallback = makeProvider(ScriptedChatCompletion(.failure(ProviderFailure.http(status: 503, body: ""))))
        let chain = ProviderChain(primary: primary, fallback: fallback)
        do {
            _ = try await chain.complete(baseRequest())
            XCTFail("双失败必须抛错")
        } catch {
            // 预期：错误可见，不允许回退 Mock
        }
    }

    // MARK: 未配置 Key：fail-closed

    func testAdapterThrowsNotConfiguredWithoutKey() {
        let settings = AISettings()
        let credentials = InMemoryCredentials(primary: "", fallback: "")
        XCTAssertThrowsError(try XZGAIProviderAdapter.makePrimary(
            settings: settings, credentials: credentials)) { error in
            XCTAssertEqual(error as? AgentError, .notConfigured)
        }
        // fallback 完全未配置时返回 nil（禁用），而不是伪造
        let fallback = try? XZGAIProviderAdapter.makeFallback(settings: settings, credentials: credentials)
        XCTAssertNil(fallback ?? nil)
    }

    func testUnconfiguredRemoteProviderAlwaysThrows() async {
        let provider = UnconfiguredRemoteProvider()
        do {
            _ = try await provider.complete(baseRequest())
            XCTFail("未配置 Provider 必须抛 notConfigured")
        } catch let error as AgentError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("应抛 AgentError.notConfigured，实际 \(error)")
        }
    }
}
