package com.xiaozhanggui.app.data.ai

import android.content.Context
import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.data.repository.ExpiryRepository
import com.xiaozhanggui.app.data.repository.GoodsRepository
import com.xiaozhanggui.app.data.repository.MemoRepository
import com.xiaozhanggui.app.data.repository.PerformanceRepository
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.domain.ai.ExecutionJournal
import com.xiaozhanggui.app.domain.ai.FileExecutionJournal
import com.xiaozhanggui.app.domain.ai.FilePendingActionStore
import com.xiaozhanggui.app.domain.ai.InMemoryConversationStore
import com.xiaozhanggui.app.domain.ai.PendingActionStore
import java.io.File

/**
 * AI 依赖装配工厂（新文件，集中创建，避免散落在 UI / Application）。
 * 对应 iOS AgentEnvironment.makeLive 的装配职责。
 *
 * - AI 侧持久化（pending-actions / execution-journal）落在 `<filesDir>/AI/`；
 * - Provider 链按 AiSettings 构建：未配置时 primary 为 null（fail-closed，
 *   AgentCore 本地 CREATE 照常、worldChat 明确告知）；
 * - Release 红线：绝不装配 Mock Provider；
 * - fail-closed：存储目录不可用 / 装配异常直接抛 [AiInitException]，不静默降级。
 */
data class AiDependencies(
    val agentCore: AgentCore,
    val settings: AiSettings,
    val pendingStore: PendingActionStore,
    val journal: ExecutionJournal,
    val connectionTester: ProviderConnectionTester = ProviderConnectionTester()
)

/**
 * AI 装配失败（fail-closed）：AI 本地存储不可用等初始化失败时直接抛错，
 * 调用方（ViewModel）必须显式呈现给用户，**不许静默降级、不许假装成功**。
 * 对应 iOS `AgentEnvironment.makeLive` 的 fail-closed 语义。
 */
class AiInitException(message: String, cause: Throwable? = null) : Exception(message, cause)

object AiAssembly {

    /**
     * AI 本地存储目录（`<filesDir>/AI`）。
     * fail-closed：目录不可写 / 创建失败时直接抛 [AiInitException]，
     * R29 Storage 不可用态必须显式呈现。
     */
    fun requireAiDir(context: Context): File = requireWritableDir(File(context.filesDir, "AI"))

    /**
     * 纯函数：目录可用性断言（fail-closed，可单测）。
     * 目录不存在则创建；不可写 / 创建失败抛 [AiInitException]。
     */
    internal fun requireWritableDir(dir: File): File {
        val ready = runCatching { dir.isDirectory || dir.mkdirs() }.getOrDefault(false) &&
            runCatching { dir.canWrite() }.getOrDefault(false)
        if (!ready) {
            throw AiInitException("AI 本地存储目录不可用：${dir.absolutePath}。请检查存储空间与应用存储权限。")
        }
        return dir
    }

    /**
     * 构建完整 AI 依赖。suspend：AiSettings 的读取是 DataStore Flow。
     * 设置变更后重新调用本方法重建 AgentCore（或仅重建 ProviderChain）。
     */
    suspend fun build(
        context: Context,
        moneyRepository: PerformanceRepository,
        todoRepository: TodoRepository,
        memoRepository: MemoRepository,
        customerRepository: CustomerRepository,
        expiryRepository: ExpiryRepository,
        goodsRepository: GoodsRepository
    ): AiDependencies {
        val settings = AiSettings(context)
        settings.migrateLegacyConfigIfNeeded()
        settings.migrateLegacySearchCredentialIfNeeded()

        val dir = requireAiDir(context)
        val pendingStore = FilePendingActionStore(dir)
        val journal = FileExecutionJournal(dir)
        val conversation = InMemoryConversationStore()

        val toolExecutor = RepositoryToolExecutor(
            moneyRepository = moneyRepository,
            todoRepository = todoRepository,
            memoRepository = memoRepository,
            customerRepository = customerRepository,
            journal = journal
        )
        val contextReader = BusinessContextReader(
            moneyRepository, todoRepository, memoRepository, customerRepository, expiryRepository
        )
        val insightReader = BusinessInsightReader(
            moneyRepository, todoRepository, customerRepository, expiryRepository, goodsRepository
        )
        val goodsLookupSkill = GoodsLookupSkill(goodsRepository)

        val agentCore = AgentCore(
            providerChain = settings.buildChain(),
            contextReader = contextReader,
            insightReader = insightReader,
            goodsLookupSkill = goodsLookupSkill,
            toolExecutor = toolExecutor,
            journal = journal,
            conversation = conversation,
            pending = pendingStore
        )

        return AiDependencies(
            agentCore = agentCore,
            settings = settings,
            pendingStore = pendingStore,
            journal = journal
        )
    }

    /**
     * 仅重建 Provider 链（设置页保存后调用，无需重建整个 AgentCore 时使用）。
     * 调用方负责把新链注入持有 AgentCore 的 ViewModel。
     */
    suspend fun rebuildChain(settings: AiSettings): ProviderChain = settings.buildChain()
}
