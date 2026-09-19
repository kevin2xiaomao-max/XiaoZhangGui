import Foundation
import Observation

// MARK: - V3.3 AI REAL · 真实「测试连接」
//
// 真机问题：isPrimaryConfigured 只表示字段填了，不代表 API 可用，
// UI 却显示绿色「已配置」，Key 错 / 模型下架时用户无从判断。
//
// 本状态机对真实端点发一次最小 chat 请求（不带工具、不携带任何经营数据），
// 只有真实返回成功才进入 .success（UI 才允许显示绿色「连接成功」）。

enum ProviderConnectionStatus: Equatable {
    /// 未配置（连可发起请求的字段 / Key 都没有）
    case notConfigured
    /// Key 已保存但尚未验证
    case unverified
    /// 正在测试
    case testing
    /// 真实调用成功
    case success
    /// 连接失败（携带用户可读中文原因）
    case failure(String)

    /// 设置页状态文案
    var text: String {
        switch self {
        case .notConfigured: return "未配置"
        case .unverified: return "Key 已保存，未验证"
        case .testing: return "正在测试连接…"
        case .success: return "连接成功"
        case .failure(let reason): return "连接失败：\(reason)"
        }
    }
}

@MainActor
@Observable
final class ProviderConnectionTester {
    private(set) var status: ProviderConnectionStatus

    init(initial: ProviderConnectionStatus = .unverified) {
        self.status = initial
    }

    /// 按当前是否存在可用 Key 同步初始状态（不覆盖进行中 / 已成功的测试）
    func synchronize(hasEffectiveKey: Bool) {
        if !hasEffectiveKey {
            status = .notConfigured
        } else if case .notConfigured = status {
            status = .unverified
        }
    }

    func reset(to state: ProviderConnectionStatus) {
        status = state
    }

    /// 用给定 Provider 发一次最小请求验证连通性。
    /// - 任何错误都经 UserFacingAIError 转中文；不向上抛。
    func test(_ provider: any AIProvider, model: String) async {
        status = .testing
        let request = ProviderRequest(
            messages: [AIMessage(role: .user, content: "ping")],
            tools: [],
            route: ModelRoute(providerID: "connection-test", model: model,
                              tier: .freeFirst, isLocalZeroToken: false),
            context: .empty
        )
        do {
            let turn = try await provider.complete(request)
            switch turn {
            case .text(let text) where !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
                status = .success
            case .text:
                status = .failure("AI 返回了空响应，请稍后重试")
            case .toolCall:
                // 测试请求不应触发工具；触发说明模型 / 端点异常
                status = .failure("服务响应异常，请检查模型设置")
            }
        } catch let agentError as AgentError {
            status = .failure(agentError.errorDescription ?? "AI 服务暂时不可用，请稍后重试")
        } catch {
            status = .failure(UserFacingAIError.message(for: error))
        }
    }
}
