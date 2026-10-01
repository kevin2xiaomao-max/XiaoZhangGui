package com.xiaozhanggui.app.data.ai

/**
 * 连接测试（ping）。对应 iOS `AI/Providers/ProviderConnectionTester.swift`。
 *
 * 状态机：notConfigured / unverified / testing / success / failure。
 * 设置页的测试胶囊只对 success 显示绿色。
 */
sealed class ConnectionTestState {
    object NotConfigured : ConnectionTestState()
    object Unverified : ConnectionTestState()
    object Testing : ConnectionTestState()
    /** 往返耗时（毫秒） */
    data class Success(val latencyMs: Long) : ConnectionTestState()
    data class Failure(val message: String) : ConnectionTestState()
}

class ProviderConnectionTester {

    /**
     * 向 provider 发送一次最小聊天请求（无工具），测连通性。
     * 测试前后不改动任何数据。
     */
    suspend fun test(provider: AIProvider?): ConnectionTestState {
        if (provider == null) return ConnectionTestState.NotConfigured
        val start = System.currentTimeMillis()
        val result = provider.chat(
            systemPrompt = OpenAiCompatProvider.systemPrompt,
            messages = listOf(ProviderMessage(role = "user", content = "ping")),
            tools = emptyList()
        )
        return if (result.isSuccess) {
            ConnectionTestState.Success(System.currentTimeMillis() - start)
        } else {
            val failure = (result.exceptionOrNull() as? ProviderException)?.failure
            val message = when (failure?.kind) {
                ProviderFailureKind.NOT_CONFIGURED -> "未配置 BaseURL / Key"
                ProviderFailureKind.UNAUTHORIZED -> "Key 无效或无权限（401/403）"
                ProviderFailureKind.TIMEOUT -> "连接超时（20s）"
                ProviderFailureKind.NETWORK -> "网络不可达：${failure.message}"
                ProviderFailureKind.SERVER_ERROR -> "服务异常：${failure.message}"
                ProviderFailureKind.PARSE_ERROR -> "响应解析失败"
                ProviderFailureKind.CANCELLED -> "已取消"
                null -> result.exceptionOrNull()?.message ?: "未知错误"
            }
            ConnectionTestState.Failure(message)
        }
    }
}
