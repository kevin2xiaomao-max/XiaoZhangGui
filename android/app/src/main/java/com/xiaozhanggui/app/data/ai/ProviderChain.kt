package com.xiaozhanggui.app.data.ai

/**
 * Provider 链（主链路 + 备用链路）。对应 iOS `AI/Providers/ProviderChain.swift`。
 *
 * 失败隔离策略（1:1 iOS `allowsFailover` 白名单）：
 * - NETWORK / TIMEOUT / 429 / 5xx → 尝试备用链路，**只跳 1 次**（不链式轮询）；
 * - UNAUTHORIZED（401/403）/ CLIENT_ERROR（其他 4xx）/ PARSE_ERROR / CANCELLED → 直接返回失败，不换链；
 * - primary 为 null（未配置）→ 直接返回 NOT_CONFIGURED 失败，不尝试 fallback（fail-closed）；
 * - 非 ProviderException 的异常 → 直接上抛，不换链。
 */
class ProviderChain(
    val primary: AIProvider?,
    private val fallback: AIProvider?
) : AIProvider {

    override val displayName: String
        get() = "链路（${primary?.displayName ?: "未配置"} → ${fallback?.displayName ?: "无备用"}）"

    /** 主链路是否可用（fail-closed：无 Key 时本地 CREATE 照常，worldChat 明确告知）。 */
    val hasPrimary: Boolean get() = primary != null

    override suspend fun chat(
        systemPrompt: String,
        messages: List<ProviderMessage>,
        tools: List<com.xiaozhanggui.app.domain.ai.ToolDefinition>
    ): Result<ProviderTurn> {
        val first = primary
            ?: return Result.failure(
                ProviderException(
                    ProviderFailure(
                        kind = ProviderFailureKind.NOT_CONFIGURED,
                        message = "主链路未配置"
                    )
                )
            )

        val firstResult = first.chat(systemPrompt, messages, tools)
        if (firstResult.isSuccess) return firstResult

        val failure = (firstResult.exceptionOrNull() as? ProviderException)?.failure
            ?: return firstResult
        if (!failure.allowsFailover) return firstResult

        val second = fallback ?: return firstResult
        return second.chat(systemPrompt, messages, tools)
    }
}
