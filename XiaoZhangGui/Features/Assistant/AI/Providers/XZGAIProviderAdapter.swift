import Foundation

// MARK: - V3.3 Lite · 第三方 Provider 隔离 / 装配边界
//
// F0 Spike 结论（见 docs/ai/V3.3_OPEN_SOURCE_ACCELERATION.md）：
// - 采用 LLMProviderKit（MIT、零依赖、iOS16+、OpenAI 兼容端点可自定义 baseURL、
//   原生 tool calling），SPM 精确锁版，工程只链接 core / OpenAI；
// - Fathom 捆绑 MCP / File / Cipher 等 Lite 不做的模块，放弃依赖，AgentCore 薄自研。
//
// 本文件不 import 任何第三方库（唯一 import 点是 OpenAICompatProvider.swift）：
// 只负责按 AISettings + Keychain 凭据构造工程内 AIProvider，业务 / UI 层只认协议。
// 缺 Key / 端点非法时：
// - 本地 0-token 能力（四范例 CREATE、四类 READ）照常工作；
// - 需要上云时由 UnconfiguredRemoteProvider 明确抛 notConfigured，
//   绝不回落到 MockAIProvider 假装成功（Release fail-closed）。

enum XZGAIProviderAdapter {

    /// 构造主 Provider；未配置 Key / 端点非法时抛 notConfigured。
    static func makePrimary(
        settings: AISettings = .shared,
        credentials: any AIProviderCredentialStoring = KeychainAIProviderCredentials()
    ) throws -> any AIProvider {
        let urlText = settings.resolvedPrimaryBaseURL
        let model = settings.resolvedPrimaryModel
        let key = credentials.primaryAPIKey()
        guard let url = validURL(urlText), !model.isEmpty, !key.isEmpty else {
            throw AgentError.notConfigured
        }
        return OpenAICompatProvider(
            id: "primary-\(settings.primaryKind)",
            baseURL: url,
            apiKey: key,
            model: model
        )
    }

    /// 构造 fallback Provider；未完整配置返回 nil（禁用 fallback，而非伪造）。
    static func makeFallback(
        settings: AISettings = .shared,
        credentials: any AIProviderCredentialStoring = KeychainAIProviderCredentials()
    ) throws -> (any AIProvider)? {
        let urlText = settings.fallbackBaseURL.trimmingCharacters(in: .whitespaces)
        let model = settings.fallbackModel.trimmingCharacters(in: .whitespaces)
        let key = credentials.fallbackAPIKey()
        if urlText.isEmpty && model.isEmpty && key.isEmpty {
            return nil // 用户未配置 fallback
        }
        guard let url = validURL(urlText), !model.isEmpty, !key.isEmpty else {
            // 配了一半：明确失败，不静默吞掉
            throw AgentError.notConfigured
        }
        let kind = settings.fallbackKind.isEmpty ? "fallback" : settings.fallbackKind
        return OpenAICompatProvider(
            id: "fallback-\(kind)",
            baseURL: url,
            apiKey: key,
            model: model
        )
    }

    private static func validURL(_ text: String) -> URL? {
        guard let url = URL(string: text), let scheme = url.scheme,
              scheme == "https" || scheme == "http" else { return nil }
        return url
    }
}

/// 未配置真实 Provider 时的占位远端：任何上云请求都明确失败。
/// 与 MockAIProvider 的本质区别：它永远返回错误，绝不返回假成功。
struct UnconfiguredRemoteProvider: AIProvider {
    let id: String = "unconfigured"

    func complete(_ request: ProviderRequest) async throws -> ProviderTurn {
        throw AgentError.notConfigured
    }
}
