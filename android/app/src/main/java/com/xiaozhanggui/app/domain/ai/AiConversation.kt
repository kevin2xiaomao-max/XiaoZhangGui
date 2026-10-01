package com.xiaozhanggui.app.domain.ai

import java.util.UUID
import kotlinx.serialization.Serializable

/**
 * AI 对话消息模型。对应 iOS `AI/Conversation/AIConversationModels.swift` 与
 * `AIChatView.swift` 的 UiMessage / AiRole。
 *
 * 对话历史为内存态（应用重启不恢复），ActionProposal 在确认前单独持久化。
 */
@Serializable
enum class AiRole(val wire: String) {
    @kotlinx.serialization.SerialName("user") USER("user"),
    @kotlinx.serialization.SerialName("assistant") ASSISTANT("assistant"),
    @kotlinx.serialization.SerialName("tool") TOOL("tool");

    companion object {
        fun fromWire(value: String): AiRole? = entries.firstOrNull { it.wire == value }
    }
}

@Serializable
data class AiUiMessage(
    val id: String = UUID.randomUUID().toString(),
    val role: AiRole,
    val text: String,
    val proposalId: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    /** 错误回复：显示红色 + 「重试」按钮（重发上一条用户原文） */
    val isError: Boolean = false
) {
    val isUser: Boolean get() = role == AiRole.USER
}

interface ConversationStore {
    suspend fun messages(): List<AiUiMessage>
    suspend fun append(message: AiUiMessage)
    suspend fun clear()
}

class InMemoryConversationStore : ConversationStore {
    private val lock = Any()
    private val items = mutableListOf<AiUiMessage>()

    override suspend fun messages(): List<AiUiMessage> = synchronized(lock) { items.toList() }
    override suspend fun append(message: AiUiMessage) {
        synchronized(lock) { items.add(message) }
    }
    override suspend fun clear() {
        synchronized(lock) { items.clear() }
    }
}
