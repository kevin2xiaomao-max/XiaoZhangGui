import Foundation
import Observation
import Security

// MARK: - V3.3 Lite · AI 设置（Free First 三档 + 端点配置接缝）
//
// 边界（R3 定稿）：
// - AppSettings 继续负责 system/light/dark 的 themeMode，本类不碰 colorScheme 链路；
// - 页面不得直接读主题 / AI 的 UserDefaults 键，统一经由本类；
// - API Key 只存 Keychain，绝不写入 UserDefaults / 仓库 / IPA；
// - Foundation 不连真实 Provider，配置项先落好，FINAL 才启用；
// - 自用阶段可经 Secrets.xcconfig / 本设置直连，Gateway 为 V3.4 可选项，不阻塞。

@Observable
final class AISettings {
    static let shared = AISettings()

    private let ud = UserDefaults.standard

    /// 免费优先 / 自动 / 高质量
    var tier: ModelTier {
        didSet { ud.set(tier.rawValue, forKey: Keys.tier) }
    }

    var primaryBaseURL: String {
        didSet { ud.set(primaryBaseURL, forKey: Keys.primaryBaseURL) }
    }
    var primaryModel: String {
        didSet { ud.set(primaryModel, forKey: Keys.primaryModel) }
    }
    var fallbackBaseURL: String {
        didSet { ud.set(fallbackBaseURL, forKey: Keys.fallbackBaseURL) }
    }
    var fallbackModel: String {
        didSet { ud.set(fallbackModel, forKey: Keys.fallbackModel) }
    }

    var primaryAPIKey: String {
        get { AIKeychain.read(Keys.primaryKey) ?? "" }
        set { AIKeychain.write(newValue, forKey: Keys.primaryKey) }
    }
    var fallbackAPIKey: String {
        get { AIKeychain.read(Keys.fallbackKey) ?? "" }
        set { AIKeychain.write(newValue, forKey: Keys.fallbackKey) }
    }

    /// 主 Provider 是否具备可连接条件（FINAL 才需要）
    var isPrimaryConfigured: Bool {
        guard let url = URL(string: primaryBaseURL), let scheme = url.scheme,
              scheme == "https" || scheme == "http" else { return false }
        return !primaryModel.isEmpty && !primaryAPIKey.isEmpty
    }

    init() {
        let rawTier = ud.string(forKey: Keys.tier) ?? ModelTier.freeFirst.rawValue
        tier = ModelTier(rawValue: rawTier) ?? .freeFirst
        primaryBaseURL = ud.string(forKey: Keys.primaryBaseURL) ?? ""
        primaryModel = ud.string(forKey: Keys.primaryModel) ?? ""
        fallbackBaseURL = ud.string(forKey: Keys.fallbackBaseURL) ?? ""
        fallbackModel = ud.string(forKey: Keys.fallbackModel) ?? ""
    }

    private enum Keys {
        static let tier = "ai_model_tier"
        static let primaryBaseURL = "ai_primary_base_url"
        static let primaryModel = "ai_primary_model"
        static let fallbackBaseURL = "ai_fallback_base_url"
        static let fallbackModel = "ai_fallback_model"
        static let primaryKey = "ai.primary.apiKey"
        static let fallbackKey = "ai.fallback.apiKey"
    }
}

// MARK: - Keychain 最小封装（API Key 唯一允许的存放处）

enum AIKeychain {
    static func write(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
