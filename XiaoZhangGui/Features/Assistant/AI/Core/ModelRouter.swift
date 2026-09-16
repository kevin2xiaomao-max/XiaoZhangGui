import Foundation

// MARK: - V3.3 Lite · Free First 模型路由（接缝）
//
// 第一原则：免费 / 低成本优先，本地能算的 0 Token。
// Lite 只保留「主 Provider + 1 个 fallback」，不做复杂多 Provider 编排。
// Foundation 全部走 Mock；本路由只决定“该用哪一档 / 哪一个槽位”，
// 真实 Provider 与模型 ID 在 FINAL 由 AISettings 注入。

/// 用户可见的三档（UI 最多只暴露这三项，不出现十几个 Provider）
enum ModelTier: String, CaseIterable, Sendable {
    /// 免费优先
    case freeFirst
    /// 自动（默认）
    case auto
    /// 高质量
    case highQuality

    var label: String {
        switch self {
        case .freeFirst: return "免费优先"
        case .auto: return "自动"
        case .highQuality: return "高质量"
        }
    }
}

/// Agent 子任务类型，用于选择档位与是否需要工具调用能力
enum ModelTask: Sendable, Equatable {
    /// 普通聊天
    case chat
    /// 意图分类（本地规则可 0 Token；这里仅为未来模型分类预留）
    case intentClassify
    /// 简单信息抽取
    case simpleExtraction
    /// 工具调用（结构化 CREATE / READ）
    case toolCall
    /// 经营数据问答
    case businessAnswer
}

/// 一次路由结果。providerID 对应 AgentEnvironment 中主 / 备槽位。
struct ModelRoute: Equatable, Sendable {
    /// "primary" 或 "fallback"
    let providerID: String
    /// FINAL 填真实模型 ID；Foundation 为占位
    let model: String
    let tier: ModelTier
    /// 本地直接处理（0 Token）
    let isLocalZeroToken: Bool
}

protocol ModelRouting: Sendable {
    func route(task: ModelTask, intent: IntentKind, tier: ModelTier) -> ModelRoute
}

/// Lite 默认路由：
/// - 意图分类：本地 0 Token（Foundation 的 IntentRouter 已完成分类）；
/// - 聊天 / 简单抽取 / 经营问答：免费优先档 → 主 Provider；
/// - 工具调用：自动档 → 主 Provider；主 Provider 失败再由 ProviderChain 跳 1 次 fallback；
/// - 用户手动选“高质量”：直接走 fallback 槽位（FINAL 配更强模型）。
struct FreeFirstModelRouter: ModelRouting {
    func route(task: ModelTask, intent: IntentKind, tier: ModelTier) -> ModelRoute {
        switch task {
        case .intentClassify:
            return ModelRoute(providerID: "local", model: "local-rules", tier: tier, isLocalZeroToken: true)
        case .toolCall:
            return ModelRoute(providerID: "primary", model: "primary.tool", tier: .auto, isLocalZeroToken: false)
        default:
            if tier == .highQuality {
                return ModelRoute(providerID: "fallback", model: "fallback.strong", tier: .highQuality, isLocalZeroToken: false)
            }
            return ModelRoute(providerID: "primary", model: "primary.free", tier: .freeFirst, isLocalZeroToken: false)
        }
    }
}
