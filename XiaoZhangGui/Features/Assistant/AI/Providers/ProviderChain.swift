import Foundation

// MARK: - V3.3 Lite · Provider 失败链（主 + 至多 1 个 fallback）
//
// Lite 不做复杂多 Provider 编排：
// - 只允许跳 1 次（primary → fallback），不链式轮询；
// - 仅网络 / 超时 / 429 / 5xx 允许跳转（ProviderFailure.allowsFailover）；
// - 401 / 403 等鉴权错误不换链（避免无效 Key 轮询多家）；
// - 取消 / 解码错误 / 其它错误直接上抛。

struct ProviderChain: AIProvider {
    let id: String = "chain"
    let primary: any AIProvider
    let fallback: (any AIProvider)?

    init(primary: any AIProvider, fallback: (any AIProvider)? = nil) {
        self.primary = primary
        self.fallback = fallback
    }

    func complete(_ request: ProviderRequest) async throws -> ProviderTurn {
        do {
            return try await primary.complete(request)
        } catch let error as ProviderFailure {
            guard error.allowsFailover, let fallback else { throw error }
            let retry = ProviderRequest(
                messages: request.messages,
                tools: request.tools,
                route: ModelRoute(providerID: "fallback", model: request.route.model,
                                  tier: request.route.tier, isLocalZeroToken: false),
                context: request.context
            )
            return try await fallback.complete(retry)
        }
        // AgentError / CancellationError / 未知错误：不换链
    }
}
