package com.xiaozhanggui.app.data.ai

import android.content.Context
import android.content.SharedPreferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

/**
 * AI 设置。对应 iOS `AI/Core/AISettings.swift`（@Observable final class AISettings）。
 *
 * 键名与 iOS 逐字 1:1（见 Keys）。非敏感字段进 DataStore（对应 UserDefaults），
 * API Key 只进 EncryptedSharedPreferences（对应 Keychain；绝不写入 DataStore / 仓库 / APK）。
 *
 * - 主 Provider 固定为 DeepSeek：模型只能从 DeepSeekModel Picker 选择，
 *   旧值 / 非法自由输入在初始化时自动迁移到 deepseek-flash；
 * - 自定义 OpenAI 兼容端点只允许出现在「高级 / 自定义 Provider（fallback）」；
 * - Fallback 仅在端点 / 模型 / Key 三者齐全时启用，否则禁用（fail-closed，不回退 Mock）。
 */
private val Context.aiDataStore by preferencesDataStore(name = "ai_settings")

/** 模型档位三档（对应 iOS ModelRouter.ModelTier） */
enum class ModelTier(val raw: String, val label: String) {
    FREE_FIRST("freeFirst", "免费优先"),
    AUTO("auto", "自动"),
    HIGH_QUALITY("highQuality", "高质量");

    companion object {
        fun from(raw: String?): ModelTier = entries.firstOrNull { it.raw == raw } ?: FREE_FIRST
    }
}

/** DeepSeek 官方当前可用模型。主流程只允许 Picker 选择这些 ID。 */
enum class DeepSeekModel(val id: String, val displayName: String) {
    /** 默认（推荐）：快速、便宜、满足小店日常对话 / 工具调用 */
    FLASH("deepseek-flash", "DeepSeek Flash（推荐）"),
    /** 高质量可选 */
    V4_PRO("deepseek-v4-pro", "DeepSeek V4 Pro");

    companion object {
        /** 已下线 / 历史默认值：检测到即自动迁移到 flash，绝不继续请求。 */
        private val legacyIDs: Set<String> = setOf(
            "deepseek-chat",
            "deepseek-reasoner",
            // 用户在旧版自由文本框里常见的误填
            "deepseek"
        )

        /** 空值 / 旧值 / 任意非法 ID 一律回落 flash（DeepSeek 主流程不接受自由输入）。 */
        fun normalize(raw: String?): DeepSeekModel {
            val trimmed = raw?.trim()?.takeIf { it.isNotEmpty() } ?: return FLASH
            entries.firstOrNull { it.id == trimmed }?.let { return it }
            entries.firstOrNull { it.id == trimmed.lowercase() }?.let { return it }
            return FLASH
        }

        fun isLegacy(raw: String?): Boolean {
            val trimmed = raw?.trim()?.lowercase()?.takeIf { it.isNotEmpty() } ?: return false
            return legacyIDs.contains(trimmed)
        }
    }
}

/**
 * Search 路由只是配置，不是能力逻辑。路由只请求 Web Search，
 * 本值决定哪个 adapter 履行。
 */
enum class SearchProviderSelection(val raw: String, val displayName: String) {
    DISABLED("disabled", "未配置"),
    AUTOMATIC_FREE_FIRST("automaticFreeFirst", "自动（免费优先）"),
    TAVILY("tavily", "Tavily"),
    CUSTOM_JSON("customJSON", "自定义 JSON Search");

    companion object {
        fun from(raw: String?): SearchProviderSelection =
            entries.firstOrNull { it.raw == raw } ?: DISABLED
    }
}

object AiDefaults {
    const val PRIMARY_KIND = "deepseek"
    const val PRIMARY_BASE_URL = "https://api.deepseek.com"
    const val PRIMARY_MODEL = "deepseek-flash"
    const val HIGH_QUALITY_MODEL = "deepseek-v4-pro"
    const val TAVILY_SEARCH_BASE_URL = "https://api.tavily.com/search"
}

class AiSettings(private val context: Context) {

    private object Keys {
        // iOS 键名逐字 1:1（AISettings.swift Keys）
        val TIER = stringPreferencesKey("ai_model_tier")
        val PRIMARY_KIND = stringPreferencesKey("ai_primary_kind")
        val FALLBACK_KIND = stringPreferencesKey("ai_fallback_kind")
        val PRIMARY_BASE_URL = stringPreferencesKey("ai_primary_base_url")
        val PRIMARY_MODEL = stringPreferencesKey("ai_primary_model")
        val FALLBACK_BASE_URL = stringPreferencesKey("ai_fallback_base_url")
        val FALLBACK_MODEL = stringPreferencesKey("ai_fallback_model")
        val SEARCH_PROVIDER_SELECTION = stringPreferencesKey("ai_search_provider_selection")
        val TAVILY_SEARCH_BASE_URL = stringPreferencesKey("ai_search_tavily_base_url")
        val CUSTOM_SEARCH_BASE_URL = stringPreferencesKey("ai_search_custom_json_base_url")
        val TAVILY_SEARCH_FREE_FIRST_ENABLED = booleanPreferencesKey("ai_search_tavily_free_first_enabled")
        val CUSTOM_SEARCH_FREE_FIRST_ENABLED = booleanPreferencesKey("ai_search_custom_free_first_enabled")
    }

    // Keychain 对应键（EncryptedSharedPreferences 的 key）
    private object SecretKeys {
        const val PRIMARY = "ai.primary.apiKey"
        const val FALLBACK = "ai.fallback.apiKey"
        const val TAVILY_SEARCH = "ai.search.tavily.apiKey"
        const val CUSTOM_SEARCH = "ai.search.customJSON.apiKey"
        const val LEGACY_SEARCH = "ai.search.apiKey"
    }

    private val securePrefs: SharedPreferences by lazy {
        val masterKey = MasterKey.Builder(context, MasterKey.DEFAULT_MASTER_KEY_ALIAS)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            "ai_secrets",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    private val dataStore get() = context.aiDataStore

    // MARK: - 读取（Flow）

    val tier: Flow<ModelTier> = dataStore.data.map { ModelTier.from(it[Keys.TIER]) }
    val primaryKind: Flow<String> = dataStore.data.map { it[Keys.PRIMARY_KIND] ?: AiDefaults.PRIMARY_KIND }
    val fallbackKind: Flow<String> = dataStore.data.map { it[Keys.FALLBACK_KIND] ?: "" }
    val primaryBaseURL: Flow<String> = dataStore.data.map { it[Keys.PRIMARY_BASE_URL] ?: "" }
    val primaryModel: Flow<String> = dataStore.data.map { it[Keys.PRIMARY_MODEL] ?: "" }
    val fallbackBaseURL: Flow<String> = dataStore.data.map { it[Keys.FALLBACK_BASE_URL] ?: "" }
    val fallbackModel: Flow<String> = dataStore.data.map { it[Keys.FALLBACK_MODEL] ?: "" }
    val searchProviderSelection: Flow<SearchProviderSelection> =
        dataStore.data.map { SearchProviderSelection.from(it[Keys.SEARCH_PROVIDER_SELECTION]) }
    val tavilySearchBaseURL: Flow<String> =
        dataStore.data.map { it[Keys.TAVILY_SEARCH_BASE_URL] ?: AiDefaults.TAVILY_SEARCH_BASE_URL }
    val customSearchBaseURL: Flow<String> = dataStore.data.map { it[Keys.CUSTOM_SEARCH_BASE_URL] ?: "" }
    val tavilySearchFreeFirstEnabled: Flow<Boolean> =
        dataStore.data.map { it[Keys.TAVILY_SEARCH_FREE_FIRST_ENABLED] ?: false }
    val customSearchFreeFirstEnabled: Flow<Boolean> =
        dataStore.data.map { it[Keys.CUSTOM_SEARCH_FREE_FIRST_ENABLED] ?: false }

    // MARK: - 非敏感写入

    suspend fun setTier(tier: ModelTier) = dataStore.edit { it[Keys.TIER] = tier.raw }
    suspend fun setPrimaryKind(kind: String) = dataStore.edit { it[Keys.PRIMARY_KIND] = kind }
    suspend fun setFallbackKind(kind: String) = dataStore.edit { it[Keys.FALLBACK_KIND] = kind }
    suspend fun setPrimaryBaseURL(url: String) = dataStore.edit { it[Keys.PRIMARY_BASE_URL] = url }
    suspend fun setPrimaryModel(model: String) = dataStore.edit { it[Keys.PRIMARY_MODEL] = model }
    suspend fun setFallbackBaseURL(url: String) = dataStore.edit { it[Keys.FALLBACK_BASE_URL] = url }
    suspend fun setFallbackModel(model: String) = dataStore.edit { it[Keys.FALLBACK_MODEL] = model }
    suspend fun setSearchProviderSelection(selection: SearchProviderSelection) =
        dataStore.edit { it[Keys.SEARCH_PROVIDER_SELECTION] = selection.raw }
    suspend fun setTavilySearchBaseURL(url: String) = dataStore.edit { it[Keys.TAVILY_SEARCH_BASE_URL] = url }
    suspend fun setCustomSearchBaseURL(url: String) = dataStore.edit { it[Keys.CUSTOM_SEARCH_BASE_URL] = url }
    suspend fun setTavilySearchFreeFirstEnabled(enabled: Boolean) =
        dataStore.edit { it[Keys.TAVILY_SEARCH_FREE_FIRST_ENABLED] = enabled }
    suspend fun setCustomSearchFreeFirstEnabled(enabled: Boolean) =
        dataStore.edit { it[Keys.CUSTOM_SEARCH_FREE_FIRST_ENABLED] = enabled }

    // MARK: - API Key（只进 EncryptedSharedPreferences，绝不回显完整值）

    var primaryAPIKey: String
        get() = securePrefs.getString(SecretKeys.PRIMARY, "") ?: ""
        set(value) = putSecret(SecretKeys.PRIMARY, value)

    var fallbackAPIKey: String
        get() = securePrefs.getString(SecretKeys.FALLBACK, "") ?: ""
        set(value) = putSecret(SecretKeys.FALLBACK, value)

    var tavilySearchAPIKey: String
        get() = securePrefs.getString(SecretKeys.TAVILY_SEARCH, "") ?: ""
        set(value) = putSecret(SecretKeys.TAVILY_SEARCH, value)

    var customSearchAPIKey: String
        get() = securePrefs.getString(SecretKeys.CUSTOM_SEARCH, "") ?: ""
        set(value) = putSecret(SecretKeys.CUSTOM_SEARCH, value)

    private fun putSecret(key: String, value: String) {
        val editor = securePrefs.edit()
        if (value.isEmpty()) editor.remove(key) else editor.putString(key, value)
        editor.apply()
    }

    // MARK: - 解析与配置判定（与 iOS 逻辑一致）

    /** 留空即回退 DeepSeek 官方默认端点 */
    suspend fun resolvedPrimaryBaseURL(): String {
        val raw = primaryBaseURL.first().trim()
        return if (raw.isEmpty()) AiDefaults.PRIMARY_BASE_URL else raw
    }

    /** 防御性归一：无论盘上值如何，主 Provider 只会拿到当前合法 DeepSeek 模型 ID。 */
    suspend fun resolvedPrimaryModel(): String = DeepSeekModel.normalize(primaryModel.first()).id

    /** 旧版迁移：deepseek-chat / deepseek-reasoner / 非法自由输入改写为 deepseek-flash 并持久化。 */
    suspend fun migrateLegacyConfigIfNeeded() {
        val raw = primaryModel.first().trim()
        if (raw.isEmpty()) return
        val normalized = DeepSeekModel.normalize(raw).id
        if (normalized != raw) setPrimaryModel(normalized)
    }

    /** 主 Provider 是否具备「发起连接」的字段条件（不等于 API 真的可用）。 */
    suspend fun isPrimaryConfigured(): Boolean {
        val urlText = resolvedPrimaryBaseURL()
        val scheme = urlText.substringBefore("://").lowercase()
        if (scheme != "https" && scheme != "http") return false
        return resolvedPrimaryModel().isNotEmpty() && primaryAPIKey.isNotEmpty()
    }

    /** 仅代表 Key 已存入；UI 文案必须用「Key 已保存」，不得暗示连接可用。 */
    val isPrimaryKeySaved: Boolean get() = primaryAPIKey.isNotEmpty()
    val isTavilySearchKeySaved: Boolean get() = tavilySearchAPIKey.isNotEmpty()
    val isCustomSearchKeySaved: Boolean get() = customSearchAPIKey.isNotEmpty()

    suspend fun isTavilySearchConfigured(): Boolean =
        isValidHTTPURL(tavilySearchBaseURL.first()) && isTavilySearchKeySaved

    suspend fun isCustomSearchConfigured(): Boolean =
        isValidHTTPURL(customSearchBaseURL.first()) && isCustomSearchKeySaved

    /** Fallback 仅在端点 / 模型 / Key 三者齐全时启用；否则禁用（fail-closed，不回退 Mock） */
    suspend fun isFallbackConfigured(): Boolean {
        val urlText = fallbackBaseURL.first().trim()
        val model = fallbackModel.first().trim()
        if (!isValidHTTPURL(urlText)) return false
        return model.isNotEmpty() && fallbackAPIKey.isNotEmpty()
    }

    private fun isValidHTTPURL(text: String): Boolean {
        val trimmed = text.trim()
        val scheme = trimmed.substringBefore("://").lowercase()
        return (scheme == "https" || scheme == "http") && trimmed.length > scheme.length + 3
    }

    // MARK: - Provider 构建

    suspend fun buildPrimaryProvider(): AIProvider? {
        if (!isPrimaryConfigured()) return null
        return OpenAiCompatProvider(
            baseURL = resolvedPrimaryBaseURL(),
            apiKey = primaryAPIKey,
            model = resolvedPrimaryModel()
        )
    }

    suspend fun buildFallbackProvider(): AIProvider? {
        if (!isFallbackConfigured()) return null
        return OpenAiCompatProvider(
            baseURL = fallbackBaseURL.first().trim(),
            apiKey = fallbackAPIKey,
            model = fallbackModel.first().trim()
        )
    }

    suspend fun buildChain(): ProviderChain =
        ProviderChain(buildPrimaryProvider(), buildFallbackProvider())
}

/**
 * 设置 Draft（打开时复制，保存才 commit，取消整体丢弃）。
 * 对应 iOS AISettingsDraft：非敏感字段保存时 trim 后一次性落盘；
 * API Key 仍只进加密存储（新输入非空才覆盖；勾选清除才删除）。
 */
data class AiSettingsDraft(
    var tier: ModelTier = ModelTier.FREE_FIRST,
    var primaryBaseURL: String = "",
    var primaryModel: DeepSeekModel = DeepSeekModel.FLASH,
    var fallbackKind: String = "",
    var fallbackBaseURL: String = "",
    var fallbackModel: String = "",
    var searchProviderSelection: SearchProviderSelection = SearchProviderSelection.DISABLED,
    var tavilySearchBaseURL: String = AiDefaults.TAVILY_SEARCH_BASE_URL,
    var customSearchBaseURL: String = "",
    var tavilySearchFreeFirstEnabled: Boolean = false,
    var customSearchFreeFirstEnabled: Boolean = false,

    /** 新粘贴的 Key；空表示「不动已保存的 Key」 */
    var stagedPrimaryKey: String = "",
    var primaryKeySaved: Boolean = false,
    var clearPrimaryKeyRequested: Boolean = false,
    var stagedFallbackKey: String = "",
    var fallbackKeySaved: Boolean = false,
    var clearFallbackKeyRequested: Boolean = false,
    var stagedTavilySearchKey: String = "",
    var tavilySearchKeySaved: Boolean = false,
    var clearTavilySearchKeyRequested: Boolean = false,
    var stagedCustomSearchKey: String = "",
    var customSearchKeySaved: Boolean = false,
    var clearCustomSearchKeyRequested: Boolean = false
) {
    suspend fun loadFrom(settings: AiSettings) {
        tier = settings.tier.first()
        primaryBaseURL = settings.primaryBaseURL.first()
        primaryModel = DeepSeekModel.normalize(settings.primaryModel.first())
        fallbackKind = settings.fallbackKind.first()
        fallbackBaseURL = settings.fallbackBaseURL.first()
        fallbackModel = settings.fallbackModel.first()
        searchProviderSelection = settings.searchProviderSelection.first()
        tavilySearchBaseURL = settings.tavilySearchBaseURL.first()
        customSearchBaseURL = settings.customSearchBaseURL.first()
        tavilySearchFreeFirstEnabled = settings.tavilySearchFreeFirstEnabled.first()
        customSearchFreeFirstEnabled = settings.customSearchFreeFirstEnabled.first()
        primaryKeySaved = settings.isPrimaryKeySaved
        fallbackKeySaved = settings.isFallbackConfigured() || settings.fallbackAPIKey.isNotEmpty()
        tavilySearchKeySaved = settings.isTavilySearchKeySaved
        customSearchKeySaved = settings.isCustomSearchKeySaved
    }

    /** 保存：trim 后一次性写入。 */
    suspend fun commit(to: AiSettings) {
        to.setTier(tier)
        to.setPrimaryBaseURL(primaryBaseURL.trim())
        to.setPrimaryModel(primaryModel.id)
        to.setFallbackKind(fallbackKind.trim())
        to.setFallbackBaseURL(fallbackBaseURL.trim())
        to.setFallbackModel(fallbackModel.trim())
        to.setSearchProviderSelection(searchProviderSelection)
        to.setTavilySearchBaseURL(tavilySearchBaseURL.trim())
        to.setCustomSearchBaseURL(customSearchBaseURL.trim())
        to.setTavilySearchFreeFirstEnabled(tavilySearchFreeFirstEnabled)
        to.setCustomSearchFreeFirstEnabled(customSearchFreeFirstEnabled)

        val newPrimaryKey = stagedPrimaryKey.trim()
        if (newPrimaryKey.isNotEmpty()) to.primaryAPIKey = newPrimaryKey
        else if (clearPrimaryKeyRequested) to.primaryAPIKey = ""

        val newFallbackKey = stagedFallbackKey.trim()
        if (newFallbackKey.isNotEmpty()) to.fallbackAPIKey = newFallbackKey
        else if (clearFallbackKeyRequested) to.fallbackAPIKey = ""

        val newTavilyKey = stagedTavilySearchKey.trim()
        if (newTavilyKey.isNotEmpty()) to.tavilySearchAPIKey = newTavilyKey
        else if (clearTavilySearchKeyRequested) to.tavilySearchAPIKey = ""

        val newCustomKey = stagedCustomSearchKey.trim()
        if (newCustomKey.isNotEmpty()) to.customSearchAPIKey = newCustomKey
        else if (clearCustomSearchKeyRequested) to.customSearchAPIKey = ""
    }
}
