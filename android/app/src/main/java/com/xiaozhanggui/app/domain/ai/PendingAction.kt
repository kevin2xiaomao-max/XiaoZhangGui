package com.xiaozhanggui.app.domain.ai

import java.io.File
import java.util.UUID
import kotlinx.serialization.Serializable

/**
 * 待确认动作（ActionCard 数据）。对应 iOS `AI/Conversation/PendingActionStore.swift` 的 ActionProposal。
 *
 * ActionProposal 在用户确认前持久化：App 被杀 / 崩溃后重开，待确认卡仍在，
 * 不会因重复响应二次落库。仅存 AI 侧 JSON（filesDir/AI），不进 Room。
 */
@Serializable
enum class ProposalStatus(val wire: String) {
    /** 等待用户确认 */
    @kotlinx.serialization.SerialName("pending") PENDING("pending"),
    /** 用户已确认（随后执行） */
    @kotlinx.serialization.SerialName("confirmed") CONFIRMED("confirmed"),
    /** 真实落库成功 */
    @kotlinx.serialization.SerialName("executed") EXECUTED("executed"),
    /** 幂等折叠：与已存在调用 / 业务指纹重复 */
    @kotlinx.serialization.SerialName("duplicate") DUPLICATE("duplicate"),
    /** 执行失败（可重试，不丢卡） */
    @kotlinx.serialization.SerialName("failed") FAILED("failed"),
    /** 用户删除 / 取消该项 */
    @kotlinx.serialization.SerialName("cancelled") CANCELLED("cancelled");

    companion object {
        fun fromWire(value: String): ProposalStatus? = entries.firstOrNull { it.wire == value }
    }
}

/**
 * ActionCard 数据。一次只承载一个 ToolCall（无 ActionBatch）。
 * 对应 iOS ActionProposal（isPreviewOnly / previewAcknowledged 为 Foundation 预览门，
 * Android 只有 live，省略）。
 */
@Serializable
data class ActionProposal(
    val id: String = UUID.randomUUID().toString(),
    val toolName: ToolName,
    val argumentsJson: String,
    val status: ProposalStatus = ProposalStatus.PENDING,
    val createdAt: Long = System.currentTimeMillis(),
    /** 真实执行结果摘要（失败原因 / 已保存文案） */
    val resultText: String? = null
) {
    /** 5 状态文案 1:1 iOS ActionCardView。 */
    val statusText: String
        get() = when (status) {
            ProposalStatus.PENDING -> "待你确认"
            ProposalStatus.CONFIRMED -> "正在保存…"
            ProposalStatus.EXECUTED -> "已保存"
            ProposalStatus.DUPLICATE -> "重复，已跳过"
            ProposalStatus.FAILED -> "失败，可重试"
            ProposalStatus.CANCELLED -> "已取消"
        }

    /** 已决（按钮禁用置灰）：pending / failed 之外均不可再操作。 */
    val isDecided: Boolean = status != ProposalStatus.PENDING && status != ProposalStatus.FAILED
}

interface PendingActionStore {
    /** 返回 pending + failed 状态卡（可重试），按创建时间排序。 */
    suspend fun pending(): List<ActionProposal>
    suspend fun upsert(proposal: ActionProposal)
    suspend fun remove(id: String)
    suspend fun proposal(id: String): ActionProposal?
    /** 清空全部待确认卡（用户清空对话时调用）。已执行记录的幂等日志不受影响。 */
    suspend fun clear()
}

/** 测试与内存用实现。 */
class InMemoryPendingActionStore : PendingActionStore {
    private val lock = Any()
    private val items = mutableMapOf<String, ActionProposal>()

    override suspend fun pending(): List<ActionProposal> = synchronized(lock) {
        items.values
            .filter { it.status == ProposalStatus.PENDING || it.status == ProposalStatus.FAILED }
            .sortedBy { it.createdAt }
    }

    override suspend fun upsert(proposal: ActionProposal) {
        synchronized(lock) { items[proposal.id] = proposal }
    }

    override suspend fun remove(id: String) {
        synchronized(lock) { items.remove(id) }
    }

    override suspend fun proposal(id: String): ActionProposal? = synchronized(lock) {
        items[id]
    }

    override suspend fun clear() {
        synchronized(lock) { items.clear() }
    }
}

/**
 * JSON 文件实现。对应 iOS FilePendingActionStore：
 * - 落盘 `<dir>/pending-actions.json`（调用方传入 filesDir/AI 目录）；
 * - 原子写入（临时文件 + rename）；
 * - 文件损坏时隔离重命名为 `pending-actions.json.corrupt-<epochMillis>` 并以空集合启动，绝不崩溃。
 */
class FilePendingActionStore(private val dir: File) : PendingActionStore {
    private val lock = Any()
    private val file: File get() = File(dir, "pending-actions.json")
    private val items: MutableMap<String, ActionProposal> = read().toMutableMap()

    private fun read(): Map<String, ActionProposal> {
        val f = file
        if (!f.exists()) return emptyMap()
        return try {
            val list = aiJson.decodeFromString(
                kotlinx.serialization.builtins.ListSerializer(ActionProposal.serializer()),
                f.readText()
            )
            list.associateBy { it.id }
        } catch (e: Exception) {
            val bad = File(dir, "pending-actions.json.corrupt-${System.currentTimeMillis()}")
            runCatching { f.renameTo(bad) }
            emptyMap()
        }
    }

    private fun persist() {
        val f = file
        runCatching { dir.mkdirs() }
        val list = synchronized(lock) { items.values.sortedBy { it.createdAt } }
        val text = runCatching {
            aiJson.encodeToString(
                kotlinx.serialization.builtins.ListSerializer(ActionProposal.serializer()),
                list
            )
        }.getOrNull() ?: return
        val tmp = File(dir, "pending-actions.json.tmp")
        runCatching {
            tmp.writeText(text)
            // 原子替换：renameTo 在同一文件系统内是原子操作
            if (!tmp.renameTo(f)) {
                f.delete()
                tmp.renameTo(f)
            }
        }
    }

    override suspend fun pending(): List<ActionProposal> = synchronized(lock) {
        items.values
            .filter { it.status == ProposalStatus.PENDING || it.status == ProposalStatus.FAILED }
            .sortedBy { it.createdAt }
    }

    override suspend fun upsert(proposal: ActionProposal) {
        synchronized(lock) { items[proposal.id] = proposal }
        persist()
    }

    override suspend fun remove(id: String) {
        synchronized(lock) { items.remove(id) }
        persist()
    }

    override suspend fun proposal(id: String): ActionProposal? = synchronized(lock) {
        items[id]
    }

    override suspend fun clear() {
        synchronized(lock) { items.clear() }
        persist()
    }
}
