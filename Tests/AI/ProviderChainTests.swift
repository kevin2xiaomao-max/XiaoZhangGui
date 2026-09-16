import XCTest
@testable import XiaoZhangGui

final class ProviderChainTests: XCTestCase {
    private let request = ProviderRequest(
        messages: [AIMessage(role: .user, content: "今天美团680")],
        tools: [], route: ModelRoute(providerID: "primary", model: "m", tier: .freeFirst, isLocalZeroToken: false))

    func testNetworkFailureFailsOverOnce() async throws {
        let primary = ScriptedAIProvider(id: "p1", [.failure(ProviderFailure.network("offline"))])
        let fallback = ScriptedAIProvider(id: "p2", [.success(.text("ok"))])
        let chain = ProviderChain(primary: primary, fallback: fallback)

        let turn = try await chain.complete(request)
        XCTAssertEqual(turn, .text("ok"))
        let p1Calls = await primary.callCount
        let p2Calls = await fallback.callCount
        XCTAssertEqual(p1Calls, 1)
        XCTAssertEqual(p2Calls, 1)
    }

    func testTimeoutFailsOver() async {
        let primary = ScriptedAIProvider(id: "p1", [.failure(ProviderFailure.timeout)])
        let fallback = ScriptedAIProvider(id: "p2", [.success(.text("ok"))])
        let chain = ProviderChain(primary: primary, fallback: fallback)
        let turn = try? await chain.complete(request)
        XCTAssertEqual(turn, .text("ok"))
    }

    func testHTTP401DoesNotFailOver() async {
        let primary = ScriptedAIProvider(id: "p1", [.failure(ProviderFailure.http(status: 401, body: ""))])
        let fallback = ScriptedAIProvider(id: "p2", [.success(.text("should-not-happen"))])
        let chain = ProviderChain(primary: primary, fallback: fallback)
        do {
            _ = try await chain.complete(request)
            XCTFail("401 应直接抛错")
        } catch let error as ProviderFailure {
            guard case .http(let status, _) = error else { return XCTFail() }
            XCTAssertEqual(status, 401)
        } catch {
            XCTFail("错误类型应为 ProviderFailure")
        }
        let p2Calls = await fallback.callCount
        XCTAssertEqual(p2Calls, 0, "鉴权错误禁止换链轮询")
    }

    func testHTTP403DoesNotFailOver() async {
        let primary = ScriptedAIProvider(id: "p1", [.failure(ProviderFailure.http(status: 403, body: ""))])
        let fallback = ScriptedAIProvider(id: "p2", [.success(.text("x"))])
        _ = try? await ProviderChain(primary: primary, fallback: fallback).complete(request)
        let p2Calls = await fallback.callCount
        XCTAssertEqual(p2Calls, 0)
    }

    func testServerErrorFailsOver() async {
        let primary = ScriptedAIProvider(id: "p1", [.failure(ProviderFailure.http(status: 503, body: ""))])
        let fallback = ScriptedAIProvider(id: "p2", [.success(.text("recovered"))])
        let turn = try? await ProviderChain(primary: primary, fallback: fallback).complete(request)
        XCTAssertEqual(turn, .text("recovered"))
    }

    func testFallbackAlsoFailsThrows() async {
        let primary = ScriptedAIProvider(id: "p1", [.failure(ProviderFailure.timeout)])
        let fallback = ScriptedAIProvider(id: "p2", [.failure(ProviderFailure.timeout)])
        do {
            _ = try await ProviderChain(primary: primary, fallback: fallback).complete(request)
            XCTFail("两条链都失败应抛错")
        } catch {
            // 预期
        }
        let p1 = await primary.callCount
        let p2 = await fallback.callCount
        XCTAssertEqual(p1, 1)
        XCTAssertEqual(p2, 1, "最多只允许跳 1 次")
    }

    func testNonProviderErrorDoesNotFailOver() async {
        struct OtherError: Error {}
        let primary = ScriptedAIProvider(id: "p1", [.failure(OtherError())])
        let fallback = ScriptedAIProvider(id: "p2", [.success(.text("x"))])
        _ = try? await ProviderChain(primary: primary, fallback: fallback).complete(request)
        let p2Calls = await fallback.callCount
        XCTAssertEqual(p2Calls, 0)
    }
}
