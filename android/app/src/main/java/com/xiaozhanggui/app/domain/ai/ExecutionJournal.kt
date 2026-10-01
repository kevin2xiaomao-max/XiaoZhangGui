package com.xiaozhanggui.app.domain.ai

import java.io.File
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer

/**
 * 执行日志 / 幂等账本（AI 侧状态，非业务数据）。
 * 对应 iOS `AI/Tools/ExecutionJournal.swift`。
 *
 * 记录每个 toolCallID / 业务指纹的处理状态，用于防重复落库与崩溃恢复。
 * 存 filesDir/AI（JSON），不进 Room。
 * 文件损坏：隔离损坏文件并以空账本启动，绝不崩溃。
 */
@Serializable
data class JournalEntry(
    val toolCallId: String,
    val fingerprint: String,
    /** 工具 wire 名（如 "recordRevenue"） */
    val toolName: String,
    /** pending / executed / failed / duplicate / cancelled */
    val status: String,
    val recordId: String? = null,
    val createdAt: Long = System.currentTimeMillis()
)

interface ExecutionJournal {
    suspend fun append(entry: JournalEntry)
    /**
     * 状态推进（pending → executed / failed）：同一 toolCallId 已存在则替换，
     * 不存在则追加。真实执行成功后必须用本方法，确保崩溃恢复时能查到 executed。
     */
    suspend fun markExecuted(entry: JournalEntry)
    suspend fun has(callId: String): Boolean
    /** 只认 executed 状态（pending / failed 不算已执行）。 */
    suspend fun isFingerprintUsed(fingerprint: String): Boolean
    suspend fun entries(): List<JournalEntry>
}

/** 测试与内存用账本。 */
class InMemoryExecutionJournal : ExecutionJournal {
    private val lock = Any()
    private val storage = mutableListOf<JournalEntry>()

    override suspend fun append(entry: JournalEntry) = synchronized(lock) {
        if (storage.none { it.toolCallId == entry.toolCallId }) storage.add(entry)
    }

    override suspend fun markExecuted(entry: JournalEntry) {
        synchronized(lock) {
            val index = storage.indexOfFirst { it.toolCallId == entry.toolCallId }
            if (index >= 0) storage[index] = entry else storage.add(entry)
        }
    }

    override suspend fun has(callId: String): Boolean = synchronized(lock) {
        storage.any { it.toolCallId == callId }
    }

    override suspend fun isFingerprintUsed(fingerprint: String): Boolean = synchronized(lock) {
        storage.any { it.fingerprint == fingerprint && it.status == "executed" }
    }

    override suspend fun entries(): List<JournalEntry> = synchronized(lock) {
        storage.toList()
    }
}

/**
 * JSON 文件账本。对应 iOS FileExecutionJournal：
 * - 落盘 `<dir>/execution-journal.json`（调用方传入 filesDir/AI 目录）；
 * - markExecuted 为 upsert（替换 pending / 追加）；
 * - 文件损坏时隔离重命名为 `execution-journal.json.corrupt-<epochMillis>` 并以空账本启动；
 * - 写入原子（临时文件 + rename）。
 */
class FileExecutionJournal(private val dir: File) : ExecutionJournal {
    private val lock = Any()
    private val file: File get() = File(dir, "execution-journal.json")
    private val storage: MutableList<JournalEntry> = read().toMutableList()

    private fun read(): List<JournalEntry> {
        val f = file
        if (!f.exists()) return emptyList()
        return try {
            aiJson.decodeFromString(ListSerializer(JournalEntry.serializer()), f.readText())
        } catch (e: Exception) {
            val bad = File(dir, "execution-journal.json.corrupt-${System.currentTimeMillis()}")
            runCatching { f.renameTo(bad) }
            emptyList()
        }
    }

    private fun persist() {
        val f = file
        runCatching { dir.mkdirs() }
        val snapshot = synchronized(lock) { storage.toList() }
        val text = runCatching {
            aiJson.encodeToString(ListSerializer(JournalEntry.serializer()), snapshot)
        }.getOrNull() ?: return
        val tmp = File(dir, "execution-journal.json.tmp")
        runCatching {
            tmp.writeText(text)
            if (!tmp.renameTo(f)) {
                f.delete()
                tmp.renameTo(f)
            }
        }
    }

    override suspend fun append(entry: JournalEntry) {
        synchronized(lock) {
            if (storage.none { it.toolCallId == entry.toolCallId }) storage.add(entry)
        }
        persist()
    }

    override suspend fun markExecuted(entry: JournalEntry) {
        synchronized(lock) {
            val index = storage.indexOfFirst { it.toolCallId == entry.toolCallId }
            if (index >= 0) storage[index] = entry else storage.add(entry)
        }
        persist()
    }

    override suspend fun has(callId: String): Boolean = synchronized(lock) {
        storage.any { it.toolCallId == callId }
    }

    override suspend fun isFingerprintUsed(fingerprint: String): Boolean = synchronized(lock) {
        storage.any { it.fingerprint == fingerprint && it.status == "executed" }
    }

    override suspend fun entries(): List<JournalEntry> = synchronized(lock) {
        storage.toList()
    }
}
