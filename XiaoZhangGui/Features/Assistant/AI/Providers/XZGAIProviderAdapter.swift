import Foundation

// MARK: - V3.3 Lite · 第三方 Provider 隔离边界
//
// F0 Spike 结论（见 docs/ai/V3.3_OPEN_SOURCE_ACCELERATION.md）：
// - 采用 LLMProviderKit（MIT、零依赖、iOS16+、OpenAI 兼容端点可自定义 baseURL、
//   原生 tool calling），SPM 精确锁版，工程只链接 core / OpenAI（Gemini 留待 FINAL）；
// - Fathom 为 Swift 6 单一 target，捆绑 MCP / File / Cipher 等 Lite 不做的模块，
//   无法干净子集化，放弃依赖，AgentCore 薄自研。
//
// 约束：
// - 只有本文件允许 import LLMProviderKit；业务 / UI 层只认 AIProvider 协议；
// - 第三方类型不得出现在 AgentCore / ToolRouter / Repository；
// - Foundation（逻辑 Build 29）不连真实 Provider，本类在 FINAL（逻辑 Build 30）
//   才实现 LLMProviderKit ↔ ProviderRequest/ProviderTurn 的映射。
//
// FINAL 接入点（此处仅占位，保证架构边界在 Foundation 就固定）：
//   1) OpenAICompatProviderAdapter: AIProvider，内部持有 LLMProviderKit.OpenAIProvider，
//      baseURL / apiKey / model 来自 AISettings（Keychain 取 Key）；
//   2) 把 ProviderToolDefinition.jsonSchema 映射为 LLMRequest.tools；
//   3) 把 tool_calls 映射回我方 ToolCall（toolCallID 由我方统一生成 / 幂等）；
//   4) 错误统一映射为 ProviderFailure，交由 ProviderChain 决定是否跳 1 次 fallback。

/// 真实 Provider 适配器的统一基类 / 命名占位。
/// Foundation 阶段任何装配路径一旦请求真实适配器即失败闭合（.notConfigured），
/// 绝不静默回落到 MockAIProvider 返回假成功。
struct XZGAIProviderAdapter: AIProvider {
    let id: String

    init(id: String = "llmproviderkit-adapter") {
        self.id = id
    }

    func complete(_ request: ProviderRequest) async throws -> ProviderTurn {
        throw AgentError.notConfigured
    }
}
