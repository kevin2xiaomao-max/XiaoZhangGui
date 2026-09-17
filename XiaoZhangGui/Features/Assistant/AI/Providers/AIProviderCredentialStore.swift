import Foundation

// MARK: - V3.3 Lite · Provider 凭据层
//
// 真实 API Key 唯一允许存放在 iOS Keychain（见 AIKeychain）。
// 本协议把「取 Key」抽象出来：正式环境走 Keychain，单元测试用内存实现，
// 任何测试都不会读到 / 断言真实 Key。

protocol AIProviderCredentialStoring: Sendable {
    func primaryAPIKey() -> String
    func fallbackAPIKey() -> String
}

/// 正式环境：从 Keychain 读取（AISettings 同一组键）。
struct KeychainAIProviderCredentials: AIProviderCredentialStoring {
    func primaryAPIKey() -> String {
        AIKeychain.read("ai.primary.apiKey") ?? ""
    }

    func fallbackAPIKey() -> String {
        AIKeychain.read("ai.fallback.apiKey") ?? ""
    }
}
