package com.xiaozhanggui.app.ai

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import com.xiaozhanggui.app.data.ai.AiAssembly
import com.xiaozhanggui.app.data.ai.AiInitException
import com.xiaozhanggui.app.data.ai.AiProvider
import com.xiaozhanggui.app.data.ai.AiSettings
import com.xiaozhanggui.app.data.ai.ApiKeyStore
import com.xiaozhanggui.app.data.ai.ConnectionTestState
import com.xiaozhanggui.app.data.ai.DeepSeekModel
import com.xiaozhanggui.app.data.ai.OpenAiCompatProvider
import com.xiaozhanggui.app.data.ai.ProviderChain
import com.xiaozhanggui.app.data.ai.ProviderConnectionTester
import com.xiaozhanggui.app.data.ai.ProviderException
import com.xiaozhanggui.app.data.ai.ProviderFailure
import com.xiaozhanggui.app.data.ai.ProviderFailureKind
import com.xiaozhanggui.app.data.ai.ProviderMessage
import com.xiaozhanggui.app.data.ai.ProviderTurn
import com.xiaozhanggui.app.data.ai.SearchProviderSelection
import com.xiaozhanggui.app.domain.ai.ToolCall
import com.xiaozhanggui.app.domain.ai.ToolDefinition
import com.xiaozhanggui.app.domain.ai.ToolName
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

/**
 * Phase 1 AI 架构测试（V3.7.1 对齐 iOS 基线）：
 * - DeepSeek 模型二选一 + 旧值自动迁移；
 * - ProviderChain 只 failover 1 次，白名单：网络/超时/429/5xx；401/403 与其他 4xx/解析错误不换链；
 * - ping 连接测试语义（最小 chat "ping"，无工具无业务数据；空响应/工具调用判失败）；
 * - 密钥只走 ApiKeyStore（Keystore），绝不进明文 DataStore；
 * - fail-closed 装配（存储目录不可用抛错）。
 */
class AiPhase1ArchitectureTest {

    @get:Rule
    val tmp = TemporaryFolder()

    // MARK: - 测试替身

    /** 内存 ApiKeyStore：验证密钥路径，不触 Android Keystore。 */
    class InMemoryApiKeyStore : ApiKeyStore {
        private val map = mutableMapOf<String, String>()
        override fun get(key: String): String = map[key] ?: ""
        override fun put(key: String, value: String) { map[key] = value }
        override fun remove(key: String) { map.remove(key) }
    }

    class FakeProvider(var result: Result<ProviderTurn>) : AiProvider {
        override val displayName = "fake"
        var calls = 0
        var lastMessages: List<ProviderMessage>? = null
        var lastTools: List<com.xiaozhanggui.app.domain.ai.ToolDefinition>? = null

        override suspend fun chat(
            systemPrompt: String,
            messages: List<ProviderMessage>,
            tools: List<ToolDefinition>
        ): Result<ProviderTurn> {
            calls++
            lastMessages = messages
            lastTools = tools
            return result
        }
    }

    private fun failure(kind: ProviderFailureKind, message: String = kind.name) =
        Result.failure<ProviderTurn>(ProviderException(ProviderFailure(kind, message)))

    private fun newSettings(): Triple<AiSettings, DataStore<Preferences>, InMemoryApiKeyStore> {
        val dir = tmp.newFolder("ds")
        val dataStore = PreferenceDataStoreFactory.create(
            produceFile = { File(dir, "ai_settings.preferences_pb") }
        )
        val keyStore = InMemoryApiKeyStore()
        return Triple(AiSettings(dataStore, keyStore), dataStore, keyStore)
    }

    // MARK: - 模型二选一 + 旧值迁移（纯逻辑）

    @Test
    fun `旧模型值归一化为 deepseek-flash`() {
        assertEquals(DeepSeekModel.FLASH, DeepSeekModel.normalize("deepseek-chat"))
        assertEquals(DeepSeekModel.FLASH, DeepSeekModel.normalize("deepseek-reasoner"))
        assertEquals(DeepSeekModel.FLASH, DeepSeekModel.normalize("deepseek"))
        assertEquals(DeepSeekModel.FLASH, DeepSeekModel.normalize("  deepseek-chat  "))
        assertEquals(DeepSeekModel.FLASH, DeepSeekModel.normalize("not-a-model"))
        assertEquals(DeepSeekModel.FLASH, DeepSeekModel.normalize(null))
        assertEquals(DeepSeekModel.FLASH, DeepSeekModel.normalize(""))
        assertEquals(DeepSeekModel.FLASH, DeepSeekModel.normalize("DEEPSEEK-FLASH"))
    }

    @Test
    fun `deepseek-v4-pro 保留不迁移`() {
        assertEquals(DeepSeekModel.V4_PRO, DeepSeekModel.normalize("deepseek-v4-pro"))
        assertFalse(DeepSeekModel.isLegacy("deepseek-v4-pro"))
        assertFalse(DeepSeekModel.isLegacy("deepseek-flash"))
    }

    @Test
    fun `旧值判定`() {
        assertTrue(DeepSeekModel.isLegacy("deepseek-chat"))
        assertTrue(DeepSeekModel.isLegacy("deepseek-reasoner"))
        assertTrue(DeepSeekModel.isLegacy("DeepSeek"))
        assertFalse(DeepSeekModel.isLegacy(null))
        assertFalse(DeepSeekModel.isLegacy(""))
    }

    @Test
    fun `deepseek-chat 迁移后持久化为 deepseek-flash`() = runBlocking {
        val (settings, dataStore, _) = newSettings()
        val key = stringPreferencesKey("ai_primary_model")
        dataStore.edit { it[key] = "deepseek-chat" }

        settings.migrateLegacyConfigIfNeeded()

        assertEquals("deepseek-flash", dataStore.data.first()[key])
        assertEquals("deepseek-flash", settings.resolvedPrimaryModel())
    }

    @Test
    fun `deepseek-v4-pro 迁移时不改写`() = runBlocking {
        val (settings, dataStore, _) = newSettings()
        val key = stringPreferencesKey("ai_primary_model")
        dataStore.edit { it[key] = "deepseek-v4-pro" }

        settings.migrateLegacyConfigIfNeeded()

        assertEquals("deepseek-v4-pro", dataStore.data.first()[key])
        assertEquals("deepseek-v4-pro", settings.resolvedPrimaryModel())
    }

    @Test
    fun `空模型值迁移时不写入`() = runBlocking {
        val (settings, dataStore, _) = newSettings()
        val key = stringPreferencesKey("ai_primary_model")

        settings.migrateLegacyConfigIfNeeded()

        assertNull(dataStore.data.first()[key])
        assertEquals("deepseek-flash", settings.resolvedPrimaryModel())
    }

    // MARK: - 密钥存储：只走 Keystore，不进明文 DataStore

    @Test
    fun `密钥只进 ApiKeyStore 不进明文 DataStore`() = runBlocking {
        val (settings, dataStore, keyStore) = newSettings()

        settings.primaryAPIKey = "sk-secret-xyz-123"
        settings.setPrimaryModel("deepseek-flash")

        // Keystore 槽位名稳定（iOS Keychain 键 1:1）
        assertEquals("sk-secret-xyz-123", keyStore.get(AiSettings.SecretKeys.PRIMARY))
        assertEquals("ai.primary.apiKey", AiSettings.SecretKeys.PRIMARY)

        // DataStore 明文里没有任何密钥材料
        val prefs = dataStore.data.first().asMap()
        for ((k, v) in prefs) {
            assertFalse("DataStore 键名不得含密钥标识：$k", k.name.contains("apiKey", ignoreCase = true))
            if (v is String) {
                assertFalse("DataStore 明文不得含密钥值：$k", v.contains("sk-secret-xyz-123"))
            }
        }
    }

    @Test
    fun `清空密钥删除 Keystore 条目`() = runBlocking {
        val (settings, _, keyStore) = newSettings()
        settings.primaryAPIKey = "sk-secret-xyz-123"
        settings.primaryAPIKey = ""
        assertEquals("", keyStore.get(AiSettings.SecretKeys.PRIMARY))
        assertFalse(settings.isPrimaryKeySaved)
    }

    @Test
    fun `旧版搜索 Key 迁移到 tavily 槽位`() = runBlocking {
        val (settings, _, keyStore) = newSettings()
        keyStore.put(AiSettings.SecretKeys.LEGACY_SEARCH, "legacy-search-key")

        settings.migrateLegacySearchCredentialIfNeeded()

        assertEquals("legacy-search-key", settings.tavilySearchAPIKey)
        assertEquals("", keyStore.get(AiSettings.SecretKeys.LEGACY_SEARCH))
        // 搜索默认 disabled → 旧 Key 迁移后自动启用 tavily（1:1 iOS）
        assertEquals(
            SearchProviderSelection.TAVILY,
            settings.searchProviderSelection.first()
        )
    }

    @Test
    fun `tavily 已有 Key 时不迁移旧槽位`() = runBlocking {
        val (settings, _, keyStore) = newSettings()
        keyStore.put(AiSettings.SecretKeys.TAVILY_SEARCH, "new-key")
        keyStore.put(AiSettings.SecretKeys.LEGACY_SEARCH, "legacy-key")

        settings.migrateLegacySearchCredentialIfNeeded()

        assertEquals("new-key", settings.tavilySearchAPIKey)
        assertEquals("legacy-key", keyStore.get(AiSettings.SecretKeys.LEGACY_SEARCH))
    }

    // MARK: - HTTP 状态码 → 失败分类

    @Test
    fun `http 状态码映射`() {
        assertEquals(ProviderFailureKind.UNAUTHORIZED, OpenAiCompatProvider.httpFailureKind(401))
        assertEquals(ProviderFailureKind.UNAUTHORIZED, OpenAiCompatProvider.httpFailureKind(403))
        assertEquals(ProviderFailureKind.TIMEOUT, OpenAiCompatProvider.httpFailureKind(408))
        assertEquals(ProviderFailureKind.RATE_LIMITED, OpenAiCompatProvider.httpFailureKind(429))
        assertEquals(ProviderFailureKind.SERVER_ERROR, OpenAiCompatProvider.httpFailureKind(500))
        assertEquals(ProviderFailureKind.SERVER_ERROR, OpenAiCompatProvider.httpFailureKind(503))
        assertEquals(ProviderFailureKind.CLIENT_ERROR, OpenAiCompatProvider.httpFailureKind(400))
        assertEquals(ProviderFailureKind.CLIENT_ERROR, OpenAiCompatProvider.httpFailureKind(404))
        assertEquals(ProviderFailureKind.CLIENT_ERROR, OpenAiCompatProvider.httpFailureKind(413))
    }

    @Test
    fun `换链白名单仅网络超时429与5xx`() {
        val allowed = setOf(
            ProviderFailureKind.NETWORK,
            ProviderFailureKind.TIMEOUT,
            ProviderFailureKind.RATE_LIMITED,
            ProviderFailureKind.SERVER_ERROR
        )
        for (kind in ProviderFailureKind.entries) {
            val f = ProviderFailure(kind, "x")
            assertEquals("kind=$kind", allowed.contains(kind), f.allowsFailover)
        }
    }

    // MARK: - ProviderChain：只 failover 1 次

    @Test
    fun `429 换链一次且仅一次`() = runBlocking {
        val primary = FakeProvider(failure(ProviderFailureKind.RATE_LIMITED, "HTTP 429"))
        val fallback = FakeProvider(Result.success(ProviderTurn(text = "pong")))
        val chain = ProviderChain(primary, fallback)

        val result = chain.chat("sys", emptyList(), emptyList())

        assertTrue(result.isSuccess)
        assertEquals(1, primary.calls)
        assertEquals(1, fallback.calls)
    }

    @Test
    fun `401 不换链`() = runBlocking {
        val primary = FakeProvider(failure(ProviderFailureKind.UNAUTHORIZED, "HTTP 401"))
        val fallback = FakeProvider(Result.success(ProviderTurn(text = "pong")))
        val chain = ProviderChain(primary, fallback)

        val result = chain.chat("sys", emptyList(), emptyList())

        assertTrue(result.isFailure)
        assertEquals(ProviderFailureKind.UNAUTHORIZED, (result.exceptionOrNull() as ProviderException).failure.kind)
        assertEquals(1, primary.calls)
        assertEquals(0, fallback.calls)
    }

    @Test
    fun `其他 4xx 不换链`() = runBlocking {
        val primary = FakeProvider(failure(ProviderFailureKind.CLIENT_ERROR, "HTTP 400"))
        val fallback = FakeProvider(Result.success(ProviderTurn(text = "pong")))
        val chain = ProviderChain(primary, fallback)

        val result = chain.chat("sys", emptyList(), emptyList())

        assertTrue(result.isFailure)
        assertEquals(0, fallback.calls)
    }

    @Test
    fun `解析错误不换链`() = runBlocking {
        val primary = FakeProvider(failure(ProviderFailureKind.PARSE_ERROR, "bad json"))
        val fallback = FakeProvider(Result.success(ProviderTurn(text = "pong")))
        val chain = ProviderChain(primary, fallback)

        val result = chain.chat("sys", emptyList(), emptyList())

        assertTrue(result.isFailure)
        assertEquals(0, fallback.calls)
    }

    @Test
    fun `主备都失败只请求两次即上限1次`() = runBlocking {
        val primary = FakeProvider(failure(ProviderFailureKind.NETWORK, "down"))
        val fallback = FakeProvider(failure(ProviderFailureKind.SERVER_ERROR, "HTTP 500"))
        val chain = ProviderChain(primary, fallback)

        val result = chain.chat("sys", emptyList(), emptyList())

        assertTrue(result.isFailure)
        assertEquals(1, primary.calls)
        assertEquals(1, fallback.calls)
        // 返回的是 fallback 的失败（最后一次尝试），不再继续
        assertEquals(
            ProviderFailureKind.SERVER_ERROR,
            (result.exceptionOrNull() as ProviderException).failure.kind
        )
    }

    @Test
    fun `非 ProviderException 不换链`() = runBlocking {
        val primary = FakeProvider(Result.failure(RuntimeException("boom")))
        val fallback = FakeProvider(Result.success(ProviderTurn(text = "pong")))
        val chain = ProviderChain(primary, fallback)

        val result = chain.chat("sys", emptyList(), emptyList())

        assertTrue(result.isFailure)
        assertEquals(0, fallback.calls)
    }

    @Test
    fun `主链路未配置直接失败不碰 fallback`() = runBlocking {
        val fallback = FakeProvider(Result.success(ProviderTurn(text = "pong")))
        val chain = ProviderChain(null, fallback)

        val result = chain.chat("sys", emptyList(), emptyList())

        assertTrue(result.isFailure)
        assertEquals(
            ProviderFailureKind.NOT_CONFIGURED,
            (result.exceptionOrNull() as ProviderException).failure.kind
        )
        assertEquals(0, fallback.calls)
    }

    // MARK: - ping 连接测试语义

    @Test
    fun `ping 用最小 chat 无工具无业务数据`() = runBlocking {
        val fake = FakeProvider(Result.success(ProviderTurn(text = "pong")))
        val tester = ProviderConnectionTester()

        val state = tester.test(fake)

        assertTrue(state is ConnectionTestState.Success)
        assertEquals(1, fake.lastMessages!!.size)
        assertEquals("user", fake.lastMessages!![0].role)
        assertEquals("ping", fake.lastMessages!![0].content)
        assertTrue(fake.lastTools!!.isEmpty())
    }

    @Test
    fun `空响应判失败`() = runBlocking {
        val fake = FakeProvider(Result.success(ProviderTurn(text = "   ")))
        val state = ProviderConnectionTester().test(fake)
        assertTrue(state is ConnectionTestState.Failure)
        assertTrue((state as ConnectionTestState.Failure).message.contains("空响应"))
    }

    @Test
    fun `ping 触发工具调用判失败`() = runBlocking {
        val fake = FakeProvider(
            Result.success(
                ProviderTurn(
                    text = null,
                    toolCalls = listOf(
                        ToolCall("call_1", ToolName.SEARCH_RECORDS, "{}")
                    )
                )
            )
        )
        val state = ProviderConnectionTester().test(fake)
        assertTrue(state is ConnectionTestState.Failure)
        assertTrue((state as ConnectionTestState.Failure).message.contains("服务响应异常"))
    }

    @Test
    fun `ping 401 失败文案`() = runBlocking {
        val fake = FakeProvider(failure(ProviderFailureKind.UNAUTHORIZED, "HTTP 401"))
        val state = ProviderConnectionTester().test(fake)
        assertTrue(state is ConnectionTestState.Failure)
        assertTrue((state as ConnectionTestState.Failure).message.contains("401/403"))
    }

    @Test
    fun `未配置 provider 返回 NotConfigured`() = runBlocking {
        val state = ProviderConnectionTester().test(null)
        assertTrue(state is ConnectionTestState.NotConfigured)
    }

    // MARK: - fail-closed 装配

    @Test
    fun `存储目录被文件占用时抛 AiInitException`() {
        val blocked = tmp.newFile("AI") // 同名文件占用目录路径
        try {
            AiAssembly.requireWritableDir(blocked)
            fail("应抛 AiInitException")
        } catch (e: AiInitException) {
            assertTrue(e.message!!.contains("AI 本地存储目录不可用"))
        }
    }

    @Test
    fun `存储目录正常时创建并返回`() {
        val dir = File(tmp.root, "ai_dir_ok")
        val got = AiAssembly.requireWritableDir(dir)
        assertTrue(got.isDirectory)
    }
}
