import Foundation
import Observation
import Security

// MARK: - V3.3 Lite · AI 设置（Free First 三档 + DeepSeek 模型 Picker + Draft 编辑）
//
// 边界（R3 定稿）：
// - AppSettings 继续负责 system/light/dark 的 themeMode，本类不碰 colorScheme 链路；
// - 页面不得直接读主题 / AI 的 UserDefaults 键，统一经由本类；
// - API Key 只存 Keychain，绝不写入 UserDefaults / 仓库 / IPA；
// - 主 Provider 固定为 DeepSeek：模型只能从 DeepSeekModel Picker 选择，
//   旧值 / 非法自由输入在初始化时自动迁移到 deepseek-flash；
// - 自定义 OpenAI 兼容端点只允许出现在「高级 / 自定义 Provider（fallback）」。

/// DeepSeek 官方当前可用模型。主流程只允许 Picker 选择这些 ID。
enum DeepSeekModel: String, CaseIterable, Sendable {
    /// 默认（推荐）：快速、便宜、满足小店日常对话 / 工具调用
    case flash = "deepseek-flash"
    /// 高质量可选
    case v4Pro = "deepseek-v4-pro"

    var displayName: String {
        switch self {
        case .flash: return "DeepSeek Flash（推荐）"
        case .v4Pro: return "DeepSeek V4 Pro"
        }
    }

    /// 已下线 / 历史默认值：检测到即自动迁移到 flash，绝不继续请求。
    static let legacyIDs: Set<String> = [
        "deepseek-chat",
        "deepseek-reasoner",
        // 用户在旧版自由文本框里常见的误填
        "deepseek",
    ]

    /// 空值 / 旧值 / 任意非法 ID 一律回落 flash（DeepSeek 主流程不接受自由输入）。
    static func normalize(_ raw: String?) -> DeepSeekModel {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return .flash }
        if let model = DeepSeekModel(rawValue: trimmed) { return model }
        if let model = DeepSeekModel(rawValue: trimmed.lowercased()) { return model }
        return .flash
    }

    static func isLegacy(_ raw: String?) -> Bool {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !trimmed.isEmpty else { return false }
        return legacyIDs.contains(trimmed)
    }
}

/// Search routing is configuration, not capability logic. The router only
/// requests Web Search; this value decides which adapter fulfills it.
enum SearchProviderSelection: String, CaseIterable, Sendable {
    case disabled
    case automaticFreeFirst
    case tavily
    case customJSON

    var displayName: String {
        switch self {
        case .disabled: return "未配置"
        case .automaticFreeFirst: return "自动（免费优先）"
        case .tavily: return "Tavily"
        case .customJSON: return "自定义 JSON Search"
        }
    }
}

@Observable
final class AISettings {
    static let shared = AISettings()

    /// V3.3 主 Provider：DeepSeek（OpenAI 兼容裸域；LLMProviderKit 自动拼 chat/completions）。
    enum Defaults {
        static let primaryKind = "deepseek"
        static let primaryBaseURL = "https://api.deepseek.com"
        static let primaryModel = DeepSeekModel.flash.rawValue
        static let highQualityModel = DeepSeekModel.v4Pro.rawValue
    }

    private let ud: UserDefaults

    /// 免费优先 / 自动 / 高质量
    var tier: ModelTier {
        didSet { ud.set(tier.rawValue, forKey: Keys.tier) }
    }

    /// Provider 类型标识（非敏感，仅用于展示 / id）；主默认 deepseek
    var primaryKind: String {
        didSet { ud.set(primaryKind, forKey: Keys.primaryKind) }
    }
    var fallbackKind: String {
        didSet { ud.set(fallbackKind, forKey: Keys.fallbackKind) }
    }

    /// 用户自定义端点；留空时解析为 DeepSeek 默认端点
    var primaryBaseURL: String {
        didSet { ud.set(primaryBaseURL, forKey: Keys.primaryBaseURL) }
    }
    /// 持久化值始终为 DeepSeekModel 合法 ID（init 已迁移旧值）
    var primaryModel: String {
        didSet { ud.set(primaryModel, forKey: Keys.primaryModel) }
    }
    var fallbackBaseURL: String {
        didSet { ud.set(fallbackBaseURL, forKey: Keys.fallbackBaseURL) }
    }
    var fallbackModel: String {
        didSet { ud.set(fallbackModel, forKey: Keys.fallbackModel) }
    }

    var primaryAPIKey: String { AIKeychain.read(Keys.primaryKey) ?? "" }
    var fallbackAPIKey: String { AIKeychain.read(Keys.fallbackKey) ?? "" }
    var searchProviderSelection: SearchProviderSelection {
        didSet { ud.set(searchProviderSelection.rawValue, forKey: Keys.searchProviderSelection) }
    }
    var tavilySearchBaseURL: String {
        didSet { ud.set(tavilySearchBaseURL, forKey: Keys.tavilySearchBaseURL) }
    }
    var customSearchBaseURL: String {
        didSet { ud.set(customSearchBaseURL, forKey: Keys.customSearchBaseURL) }
    }
    /// Pricing changes outside the app. Automatic routing is allowed only after
    /// the user explicitly confirms that this configured provider is eligible.
    var tavilySearchFreeFirstEnabled: Bool {
        didSet { ud.set(tavilySearchFreeFirstEnabled, forKey: Keys.tavilySearchFreeFirstEnabled) }
    }
    var customSearchFreeFirstEnabled: Bool {
        didSet { ud.set(customSearchFreeFirstEnabled, forKey: Keys.customSearchFreeFirstEnabled) }
    }
    /// 图片整张外发前的二次确认。默认开：图片里常有客户姓名、电话、单据金额，
    /// 一次误选就是不可撤回的外发，值得多一次点击。
    var imageUploadNeedsConfirmation: Bool {
        didSet { ud.set(imageUploadNeedsConfirmation, forKey: Keys.imageUploadNeedsConfirmation) }
    }

    var tavilySearchAPIKey: String { AIKeychain.read(Keys.tavilySearchKey) ?? "" }
    var customSearchAPIKey: String { AIKeychain.read(Keys.customSearchKey) ?? "" }

    enum APIKeySlot {
        case primary, fallback, tavilySearch, customSearch

        fileprivate var account: String {
            switch self {
            case .primary: return Keys.primaryKey
            case .fallback: return Keys.fallbackKey
            case .tavilySearch: return Keys.tavilySearchKey
            case .customSearch: return Keys.customSearchKey
            }
        }
    }

    /// 保持旧版 account 名不变，仅把写入改为可报告失败的 update/add。
    func setAPIKey(_ value: String, for slot: APIKeySlot) throws {
        try AIKeychain.save(value, forKey: slot.account)
    }

    /// 留空即回退 DeepSeek 官方默认端点
    var resolvedPrimaryBaseURL: String {
        primaryBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Defaults.primaryBaseURL : primaryBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /// 防御性归一：无论盘上值如何，主 Provider 只会拿到当前合法 DeepSeek 模型 ID。
    var resolvedPrimaryModel: String {
        DeepSeekModel.normalize(primaryModel).rawValue
    }

    /// 主 Provider 是否具备「发起连接」的字段条件（不等于 API 真的可用）。
    var isPrimaryConfigured: Bool {
        guard let url = URL(string: resolvedPrimaryBaseURL), let scheme = url.scheme,
              scheme == "https" || scheme == "http" else { return false }
        return !resolvedPrimaryModel.isEmpty && !primaryAPIKey.isEmpty
    }

    /// 仅代表 Key 已存入 Keychain；UI 文案必须用「Key 已保存」，不得暗示连接可用。
    var isPrimaryKeySaved: Bool { !primaryAPIKey.isEmpty }
    var isTavilySearchKeySaved: Bool { !tavilySearchAPIKey.isEmpty }
    var isCustomSearchKeySaved: Bool { !customSearchAPIKey.isEmpty }

    var isTavilySearchConfigured: Bool {
        Self.isValidHTTPURL(tavilySearchBaseURL) && isTavilySearchKeySaved
    }

    var isCustomSearchConfigured: Bool {
        Self.isValidHTTPURL(customSearchBaseURL) && isCustomSearchKeySaved
    }

    /// Fallback 仅在端点 / 模型 / Key 三者齐全时启用；否则禁用（fail-closed，不回退 Mock）
    var isFallbackConfigured: Bool {
        let urlText = fallbackBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = fallbackModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlText), let scheme = url.scheme,
              scheme == "https" || scheme == "http" else { return false }
        return !model.isEmpty && !fallbackAPIKey.isEmpty
    }

    /// - Parameter defaults: 生产用 .standard；测试注入独立 suite，避免污染真实配置。
    init(defaults: UserDefaults = .standard) {
        self.ud = defaults
        Self.migrateLegacyConfig(in: defaults)

        let rawTier = defaults.string(forKey: Keys.tier) ?? ModelTier.freeFirst.rawValue
        tier = ModelTier(rawValue: rawTier) ?? .freeFirst
        primaryKind = defaults.string(forKey: Keys.primaryKind) ?? Defaults.primaryKind
        fallbackKind = defaults.string(forKey: Keys.fallbackKind) ?? ""
        primaryBaseURL = defaults.string(forKey: Keys.primaryBaseURL) ?? ""
        primaryModel = defaults.string(forKey: Keys.primaryModel) ?? ""
        fallbackBaseURL = defaults.string(forKey: Keys.fallbackBaseURL) ?? ""
        fallbackModel = defaults.string(forKey: Keys.fallbackModel) ?? ""
        searchProviderSelection = SearchProviderSelection(
            rawValue: defaults.string(forKey: Keys.searchProviderSelection) ?? ""
        ) ?? .disabled
        tavilySearchBaseURL = defaults.string(forKey: Keys.tavilySearchBaseURL)
            ?? "https://api.tavily.com/search"
        customSearchBaseURL = defaults.string(forKey: Keys.customSearchBaseURL) ?? ""
        tavilySearchFreeFirstEnabled = defaults.bool(forKey: Keys.tavilySearchFreeFirstEnabled)
        customSearchFreeFirstEnabled = defaults.bool(forKey: Keys.customSearchFreeFirstEnabled)
        // 缺省为开：老用户没有这个键，也应该先看到一次外发确认。
        imageUploadNeedsConfirmation = (defaults.object(forKey: Keys.imageUploadNeedsConfirmation) as? Bool) ?? true

        migrateLegacySearchCredentialIfNeeded()
    }

    /// 旧版用户迁移：deepseek-chat / deepseek-reasoner / "DeepSeek" 等旧值或非法自由输入
    /// 在加载时直接改写为 deepseek-flash 并持久化，避免旧值继续被拿去请求而报模型错误。
    private static func migrateLegacyConfig(in defaults: UserDefaults) {
        guard let raw = defaults.string(forKey: Keys.primaryModel)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return }
        let normalized = DeepSeekModel.normalize(raw)
        if normalized.rawValue != raw {
            defaults.set(normalized.rawValue, forKey: Keys.primaryModel)
        }
    }

    private func migrateLegacySearchCredentialIfNeeded() {
        guard tavilySearchAPIKey.isEmpty,
              let legacy = AIKeychain.read(Keys.legacySearchKey),
              !legacy.isEmpty else { return }
        do {
            try setAPIKey(legacy, for: .tavilySearch)
            try AIKeychain.remove(Keys.legacySearchKey)
        } catch {
            // 新槽位没有确认写入时保留旧条目，下次启动继续迁移。
            return
        }
        if searchProviderSelection == .disabled {
            searchProviderSelection = .tavily
        }
    }

    private static func isValidHTTPURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme else { return false }
        return scheme == "https" || scheme == "http"
    }

    private enum Keys {
        static let tier = "ai_model_tier"
        static let primaryKind = "ai_primary_kind"
        static let fallbackKind = "ai_fallback_kind"
        static let primaryBaseURL = "ai_primary_base_url"
        static let primaryModel = "ai_primary_model"
        static let fallbackBaseURL = "ai_fallback_base_url"
        static let fallbackModel = "ai_fallback_model"
        static let primaryKey = "ai.primary.apiKey"
        static let fallbackKey = "ai.fallback.apiKey"
        static let searchProviderSelection = "ai_search_provider_selection"
        static let tavilySearchBaseURL = "ai_search_tavily_base_url"
        static let customSearchBaseURL = "ai_search_custom_json_base_url"
        static let tavilySearchFreeFirstEnabled = "ai_search_tavily_free_first_enabled"
        static let customSearchFreeFirstEnabled = "ai_search_custom_free_first_enabled"
        static let imageUploadNeedsConfirmation = "ai_image_upload_needs_confirmation"
        static let tavilySearchKey = "ai.search.tavily.apiKey"
        static let customSearchKey = "ai.search.customJSON.apiKey"
        static let legacySearchKey = "ai.search.apiKey"
    }
}

// MARK: - 设置 Draft（打开时复制，保存才 commit，取消整体丢弃）
//
// 解决真机问题：旧版 @Bindable AISettings 使每次键入都实时写 UserDefaults，
// 「取消」无法恢复。Draft 只在内存中编辑，非敏感字段保存时 trim 后一次性落盘；
// API Key 仍只进 Keychain（新输入非空才覆盖；勾选清除才删除）。

@Observable
final class AISettingsDraft {
    var tier: ModelTier
    var primaryBaseURL: String
    var primaryModel: DeepSeekModel
    var fallbackKind: String
    var fallbackBaseURL: String
    var fallbackModel: String
    var searchProviderSelection: SearchProviderSelection
    var tavilySearchBaseURL: String
    var customSearchBaseURL: String
    var tavilySearchFreeFirstEnabled: Bool
    var customSearchFreeFirstEnabled: Bool
    var imageUploadNeedsConfirmation: Bool

    /// 新粘贴的 Key；空表示「不动已保存的 Key」
    var stagedPrimaryKey = ""
    var primaryKeySaved: Bool
    var clearPrimaryKeyRequested = false
    var stagedFallbackKey = ""
    var fallbackKeySaved: Bool
    var clearFallbackKeyRequested = false
    var stagedTavilySearchKey = ""
    var tavilySearchKeySaved: Bool
    var clearTavilySearchKeyRequested = false
    var stagedCustomSearchKey = ""
    var customSearchKeySaved: Bool
    var clearCustomSearchKeyRequested = false

    init(settings: AISettings) {
        tier = settings.tier
        primaryBaseURL = settings.primaryBaseURL
        primaryModel = DeepSeekModel.normalize(settings.primaryModel)
        fallbackKind = settings.fallbackKind
        fallbackBaseURL = settings.fallbackBaseURL
        fallbackModel = settings.fallbackModel
        searchProviderSelection = settings.searchProviderSelection
        tavilySearchBaseURL = settings.tavilySearchBaseURL
        customSearchBaseURL = settings.customSearchBaseURL
        tavilySearchFreeFirstEnabled = settings.tavilySearchFreeFirstEnabled
        customSearchFreeFirstEnabled = settings.customSearchFreeFirstEnabled
        imageUploadNeedsConfirmation = settings.imageUploadNeedsConfirmation
        primaryKeySaved = settings.isPrimaryKeySaved
        fallbackKeySaved = settings.isFallbackConfigured || !settings.fallbackAPIKey.isEmpty
        tavilySearchKeySaved = settings.isTavilySearchKeySaved
        customSearchKeySaved = settings.isCustomSearchKeySaved
    }

    /// 保存：trim 后一次性写入。调用方负责随后发出 .aiProviderConfigChanged。
    func commit(to settings: AISettings) throws {
        try Self.applyKey(staged: stagedPrimaryKey, clear: clearPrimaryKeyRequested,
                          slot: .primary, settings: settings)
        try Self.applyKey(staged: stagedFallbackKey, clear: clearFallbackKeyRequested,
                          slot: .fallback, settings: settings)
        try Self.applyKey(staged: stagedTavilySearchKey, clear: clearTavilySearchKeyRequested,
                          slot: .tavilySearch, settings: settings)
        try Self.applyKey(staged: stagedCustomSearchKey, clear: clearCustomSearchKeyRequested,
                          slot: .customSearch, settings: settings)

        settings.tier = tier
        settings.primaryBaseURL = primaryBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.primaryModel = primaryModel.rawValue
        settings.fallbackKind = fallbackKind.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.fallbackBaseURL = fallbackBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.fallbackModel = fallbackModel.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.searchProviderSelection = searchProviderSelection
        settings.tavilySearchBaseURL = tavilySearchBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.customSearchBaseURL = customSearchBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.tavilySearchFreeFirstEnabled = tavilySearchFreeFirstEnabled
        settings.customSearchFreeFirstEnabled = customSearchFreeFirstEnabled
        settings.imageUploadNeedsConfirmation = imageUploadNeedsConfirmation

    }

    private static func applyKey(
        staged: String,
        clear: Bool,
        slot: AISettings.APIKeySlot,
        settings: AISettings
    ) throws {
        let value = staged.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            try settings.setAPIKey(value, for: slot)
        } else if clear {
            try settings.setAPIKey("", for: slot)
        }
    }
}

// MARK: - Keychain 最小封装（API Key 唯一允许的存放处）

enum AIKeychainError: LocalizedError, Equatable {
    case unexpectedStatus(operation: String, status: OSStatus)

    var errorDescription: String? {
        switch self {
        case let .unexpectedStatus(operation, status):
            return "\(operation)失败（OSStatus \(status)），请重试。"
        }
    }
}

enum AIKeychain {
    static func save(_ value: String, forKey key: String) throws {
        guard !value.isEmpty else {
            try remove(key)
            return
        }
        let data = Data(value.utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let updateStatus = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw AIKeychainError.unexpectedStatus(operation: "更新 Keychain", status: updateStatus)
        }
        let add = base.merging(attributes) { _, new in new }
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw AIKeychainError.unexpectedStatus(operation: "写入 Keychain", status: addStatus)
        }
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

    static func remove(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AIKeychainError.unexpectedStatus(operation: "删除 Keychain", status: status)
        }
    }
}
