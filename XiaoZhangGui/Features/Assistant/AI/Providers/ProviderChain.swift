import Foundation

// MARK: - V3.3 Lite · Provider 失败链（主 + 至多 1 个 fallback）
//
// Lite 不做复杂多 Provider 编排：
// - 只允许跳 1 次（primary ↔ fallback），不链式轮询；
// - 仅网络 / 超时 / 429 / 5xx 允许跳转（ProviderFailure.allowsFailover）；
// - 401 / 403 等鉴权错误不换链（避免无效 Key 轮询多家）；
// - 取消 / 解码错误 / 其它错误直接上抛。
//
// V3.9.2 修正（P1-4「高质量档位失效」）：
// 路由把槽位算进 `route.providerID`（高质量档 → "fallback"），
// 但原实现永远先打 primary，等于用户选了高质量也走主模型。
// 现在按 route 起手：指到 fallback 就先打强模型，失败再回主链兜底。

struct ProviderChain: AIProvider {
    let id: String = "chain"
    let primary: any AIProvider
    let fallback: (any AIProvider)?

    static let primarySlotID = "primary"
    static let fallbackSlotID = "fallback"

    init(primary: any AIProvider, fallback: (any AIProvider)? = nil) {
        self.primary = primary
        self.fallback = fallback
    }

    func complete(_ request: ProviderRequest) async throws -> ProviderTurn {
        // 高质量档：路由把槽位指到 fallback，先打强模型，可故障转移时再由主链兜底。
        if request.route.providerID == Self.fallbackSlotID, let fallback {
            AILog.fallbackFirstSelected(model: request.route.model, tier: request.route.tier)
            do {
                return try await fallback.complete(request)
            } catch let error as ProviderFailure {
                guard error.allowsFailover else { throw error }
                return try await primary.complete(request.rebased(to: Self.primarySlotID))
            }
        }
        do {
            return try await primary.complete(request)
        } catch let error as ProviderFailure {
            guard error.allowsFailover, let fallback else { throw error }
            return try await fallback.complete(request.rebased(to: Self.fallbackSlotID))
        }
        // AgentError / CancellationError / 未知错误：不换链
    }
}

private extension ProviderRequest {
    /// 换槽位只改 route 的 providerID，消息 / 工具 / 上下文原样保留。
    func rebased(to providerID: String) -> ProviderRequest {
        ProviderRequest(
            messages: messages,
            tools: tools,
            route: ModelRoute(
                providerID: providerID,
                model: route.model,
                tier: route.tier,
                isLocalZeroToken: false
            ),
            context: context
        )
    }
}
