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
    /// V3.9.3 · 用量计量（次数级；nil 表示不计量，如预览环境与旧测试装配）。
    let meter: AIUsageStore?
    /// V3.9.3 · fallback 的真实配置模型 ID（取自 AISettings.fallbackModel）。
    /// route.model 是占位串（fallback.strong），绝不能当真实模型显示或记账；
    /// 有真实配置时日志与计量一律用它，无配置时回落占位串并在文案中说明。
    let fallbackModelDisplay: String?

    static let primarySlotID = "primary"
    static let fallbackSlotID = "fallback"

    init(primary: any AIProvider, fallback: (any AIProvider)? = nil,
         meter: AIUsageStore? = nil, fallbackModelDisplay: String? = nil) {
        self.primary = primary
        self.fallback = fallback
        self.meter = meter
        self.fallbackModelDisplay = fallbackModelDisplay
    }

    func complete(_ request: ProviderRequest) async throws -> ProviderTurn {
        // 高质量档：路由把槽位指到 fallback，先打强模型，可故障转移时再由主链兜底。
        if request.route.providerID == Self.fallbackSlotID, let fallback {
            let displayModel = (fallbackModelDisplay?.isEmpty == false)
                ? fallbackModelDisplay!
                : request.route.model
            AILog.fallbackFirstSelected(model: displayModel, tier: request.route.tier)
            do {
                let turn = try await fallback.complete(request)
                await meter?.record(slot: Self.fallbackSlotID, tier: request.route.tier, outcome: .success)
                return turn
            } catch let error as ProviderFailure {
                await meter?.record(slot: Self.fallbackSlotID, tier: request.route.tier, outcome: .failed)
                guard error.allowsFailover else { throw error }
                do {
                    let turn = try await primary.complete(request.rebased(to: Self.primarySlotID))
                    await meter?.record(slot: Self.primarySlotID, tier: request.route.tier, outcome: .success)
                    return turn
                } catch {
                    await recordFailureOrCancellation(error, slot: Self.primarySlotID, tier: request.route.tier)
                    throw error
                }
            } catch {
                await recordFailureOrCancellation(error, slot: Self.fallbackSlotID, tier: request.route.tier)
                throw error
            }
        }
        do {
            let turn = try await primary.complete(request)
            await meter?.record(slot: Self.primarySlotID, tier: request.route.tier, outcome: .success)
            return turn
        } catch let error as ProviderFailure {
            await meter?.record(slot: Self.primarySlotID, tier: request.route.tier, outcome: .failed)
            guard error.allowsFailover, let fallback else { throw error }
            do {
                let turn = try await fallback.complete(request.rebased(to: Self.fallbackSlotID))
                await meter?.record(slot: Self.fallbackSlotID, tier: request.route.tier, outcome: .success)
                return turn
            } catch {
                await recordFailureOrCancellation(error, slot: Self.fallbackSlotID, tier: request.route.tier)
                throw error
            }
        } catch {
            await recordFailureOrCancellation(error, slot: Self.primarySlotID, tier: request.route.tier)
            throw error
        }
        // AgentError / CancellationError / 未知错误：不换链
    }

    private func recordFailureOrCancellation(_ error: Error, slot: String, tier: ModelTier) async {
        if error is CancellationError {
            await meter?.record(slot: slot, tier: tier, outcome: .cancelled)
        } else {
            await meter?.record(slot: slot, tier: tier, outcome: .failed)
        }
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
