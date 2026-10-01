package com.xiaozhanggui.app.data.ai

import com.xiaozhanggui.app.domain.ai.ToolCall

/**
 * AI Provider 接口。对应 iOS `AI/Providers/Provider.swift`（AgentCore 的 LLM 依赖）。
 * 模型档位（ModelTier）与 AISettings 交互：Provider 只管做一次请求。
 */
data class ProviderTurn(
    val text: String?,
    val toolCalls: List<ToolCall> = emptyList(),
    /** 原始模型标识（响应的 model 字段） */
    val modelUsed: String? = null
)

enum class ProviderFailureKind {
    NOT_CONFIGURED,
    NETWORK,
    UNAUTHORIZED,
    TIMEOUT,
    SERVER_ERROR,
    PARSE_ERROR,
    CANCELLED
}

/**
 * Provider 失败。对应 iOS AgentError / ProviderError：
 * - NOT_CONFIGURED：未配置 URL / Key（云端链路不可用）；
 * - UNAUTHORIZED(401/403)：Key 错了，不应继续换链。
 */
data class ProviderFailure(
    val kind: ProviderFailureKind,
    val message: String,
    val httpStatus: Int? = null
) {
    /** Provider 链失败隔离：401/403 或被取消不再切换链路 */
    val allowsFailover: Boolean
        get() = kind != ProviderFailureKind.UNAUTHORIZED &&
            kind != ProviderFailureKind.CANCELLED
}

/**
 * 模型提供者：单次 chat 请求。对应 iOS `LLMProvider`。
 * 实现：OpenAiCompatProvider（OpenAI-compatible HTTP）。
 */
interface AIProvider {
    val displayName: String

    /**
     * 执行一次对话轮：发送消息 + 可用工具定义，返回模型文本与/或 tool_calls。
     * 调用方按顺序：发系统提示 → 模型回复（文本或工具调用）→ 本地执行工具 → 把结果回喂模型。
     */
    suspend fun chat(
        systemPrompt: String,
        messages: List<ProviderMessage>,
        tools: List<com.xiaozhanggui.app.domain.ai.ToolDefinition>
    ): Result<ProviderTurn>
}

/** 单条对话消息（请求体）。 */
data class ProviderMessage(
    val role: String,
    val content: String? = null,
    val toolCallId: String? = null,
    val toolCalls: List<ToolCall> = emptyList(),
    val name: String? = null
)
