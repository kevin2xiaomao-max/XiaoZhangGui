import XCTest
@testable import XiaoZhangGui

// MARK: V3.3 AI REAL · Provider 错误 → 用户可读中文映射
//
// 真机问题：ProviderFailure 最终只剩 generic localizedDescription
// （类似 "The operation couldn't be completed … error 2"），用户无法自救。

final class UserFacingAIErrorTests: XCTestCase {

    // MARK: 3) 401 → API Key 无效

    func test401MapsToInvalidAPIKey() {
        let message = UserFacingAIError.message(for: ProviderFailure.http(status: 401, body: ""))
        XCTAssertTrue(message.contains("API Key"), "401 必须明确提示 Key 问题，实际：\(message)")
        XCTAssertTrue(message.contains("无效"), "实际：\(message)")
        XCTAssertFalse(message.contains("ProviderFailure"), "不得泄漏原始错误类型名")
    }

    // MARK: 4) 402 → 账户余额不足

    func test402MapsToInsufficientBalance() {
        let message = UserFacingAIError.message(for: ProviderFailure.http(status: 402, body: ""))
        XCTAssertTrue(message.contains("余额"), "实际：\(message)")
    }

    // MARK: 5) 422 → API 参数 / 模型配置错误

    func test422MapsToModelOrParameterConfig() {
        let message = UserFacingAIError.message(for: ProviderFailure.http(status: 422, body: ""))
        XCTAssertTrue(message.contains("模型") || message.contains("参数"), "实际：\(message)")
    }

    func test400AlsoMapsToModelOrParameterConfig() {
        // DeepSeek 模型不存在实际常以 400 invalid_request_error 返回
        let message = UserFacingAIError.message(for: ProviderFailure.http(status: 400, body: ""))
        XCTAssertTrue(message.contains("模型") || message.contains("参数"), "实际：\(message)")
    }

    // MARK: 6) 429 → 中文提示且允许 fallback

    func test429HasChineseMessageAndAllowsFailover() {
        let failure = ProviderFailure.http(status: 429, body: "")
        let message = UserFacingAIError.message(for: failure)
        XCTAssertTrue(message.contains("频繁") || message.contains("稍后"), "实际：\(message)")
        XCTAssertTrue(failure.allowsFailover, "429 必须允许跳到备用 Provider 一次")
    }

    // MARK: 7) timeout → 超时中文且允许 fallback；offline → 当前没有网络

    func testTimeoutHasChineseMessageAndAllowsFailover() {
        let message = UserFacingAIError.message(for: ProviderFailure.timeout)
        XCTAssertTrue(message.contains("超时"), "实际：\(message)")
        XCTAssertTrue(ProviderFailure.timeout.allowsFailover)
    }

    func testOfflineMapsToNoNetworkAndAllowsFailover() {
        let message = UserFacingAIError.message(for: ProviderFailure.offline)
        XCTAssertTrue(message.contains("没有网络") || message.contains("网络连接"), "实际：\(message)")
        XCTAssertTrue(ProviderFailure.offline.allowsFailover)
    }

    func test5xxMapsToServiceTemporarilyUnavailable() {
        XCTAssertTrue(UserFacingAIError.message(for: ProviderFailure.http(status: 500, body: ""))
            .contains("暂时不可用"))
        XCTAssertTrue(UserFacingAIError.message(for: ProviderFailure.http(status: 503, body: ""))
            .contains("暂时不可用"))
    }

    func testNotConfiguredKeepsGuardMessage() {
        let message = UserFacingAIError.message(for: AgentError.notConfigured)
        XCTAssertTrue(message.contains("配置"))
    }
}

// MARK: ProviderConnectionTester · 真实测试连接的状态机（注入脚本 Provider，不发网络）

@MainActor
final class ProviderConnectionTesterTests: XCTestCase {

    private func pingRequest() -> ProviderRequest {
        ProviderRequest(
            messages: [AIMessage(role: .user, content: "ping")],
            tools: [],
            route: ModelRoute(providerID: "test", model: "deepseek-flash",
                              tier: .freeFirst, isLocalZeroToken: false)
        )
    }

    func testSuccessShowsConnectedOnlyAfterRealCall() async {
        actor OKProvider: AIProvider {
            nonisolated let id = "ok"
            func complete(_ request: ProviderRequest) async throws -> ProviderTurn { .text("pong") }
        }
        let tester = ProviderConnectionTester()
        XCTAssertEqual(tester.status, .unverified, "初始必须是未验证，不得凭字段齐全显示成功")
        await tester.test(OKProvider())
        XCTAssertEqual(tester.status, .success, "只有真实调用成功后才允许显示连接成功")
    }

    func test401ShowsFailureWithChineseReason() async {
        let tester = ProviderConnectionTester()
        await tester.test(ScriptedAIProvider(id: "bad", [.failure(ProviderFailure.http(status: 401, body: ""))]))
        guard case .failure(let message) = tester.status else { return XCTFail("应失败，实际 \(tester.status)") }
        XCTAssertTrue(message.contains("API Key"))
    }

    func testTestingStateExposedDuringRequest() async {
        actor HangingProvider: AIProvider {
            nonisolated let id = "hang"
            func complete(_ request: ProviderRequest) async throws -> ProviderTurn {
                try? await Task.sleep(nanoseconds: 50_000_000)
                return .text("pong")
            }
        }
        let tester = ProviderConnectionTester()
        let task = Task { await tester.test(HangingProvider()) }
        try? await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(tester.status, .testing)
        await task.value
        XCTAssertEqual(tester.status, .success)
    }
}
