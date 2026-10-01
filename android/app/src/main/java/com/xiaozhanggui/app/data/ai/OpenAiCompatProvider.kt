package com.xiaozhanggui.app.data.ai

import com.xiaozhanggui.app.domain.ai.ToolArguments
import com.xiaozhanggui.app.domain.ai.ToolCall
import com.xiaozhanggui.app.domain.ai.ToolDefinition
import com.xiaozhanggui.app.domain.ai.ToolName
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

/**
 * OpenAI-compatible Provider（OpenAI / DeepSeek / 通义 / Ollama 等）。
 * 对应 iOS `AI/Providers/OpenAICompatProvider.swift`。
 *
 * - 单次 POST `{baseURL}/chat/completions`（baseURL 去尾斜杠，兼容 `…/v1` 与 `…/v1/` 写法）
 * - temperature 0.2（经营数字不许发散）
 * - 请求 20s 超时；失败按 ProviderFailureKind 分类，401/403 标注 UNAUTHORIZED（链路只跳 1 次）
 * - 第三方类型不出文件：响应解析用局域 @Serializable DTO
 */
class OpenAiCompatProvider(
    val baseURL: String,
    val apiKey: String,
    val model: String,
    private val client: OkHttpClient = defaultClient
) : AIProvider {

    override val displayName: String
        get() = "OpenAI 兼容（$model）"

    companion object {
        /**
         * 系统提示词（6 条规则）1:1 对应 iOS OpenAICompatProvider.systemPrompt：
         * 1. 你是小掌柜 AI 助手，只处理店铺经营事务。
         * 2. 只使用提供的工具写数据；不要脑补不存在的客户 / 商品 / 金额。
         * 3. 金额一律用元；时间必须明确到可执行。
         * 4. 用户未确认的动作不要自行落库；工具调用即代表需要用户确认。
         * 5. 不知道就说不知道，不要编数字。
         * 6. 隐私：经营数据仅用于回答当前问题，不对外泄露完整手机号等敏感信息。
         */
        val systemPrompt: String = buildString {
            appendLine("你是小掌柜 AI 助手，专门帮小店老板处理店铺经营事务。")
            appendLine("规则：")
            appendLine("1. 只处理经营相关请求（记账、配送、备忘、待办、经营查询）；非经营问题简短回答。")
            appendLine("2. 写数据必须调用工具，不许在对话文本里编造客户名、商品名或金额；不知道就说不知道。")
            appendLine("3. 金额一律用元；时间必须明确（今天/明天/几点几分），不明确就追问，不许脑补。")
            appendLine("4. 工具调用代表需要用户确认的动作，永远等用户确认后再执行，不要假设已确认。")
            appendLine("5. 回答经营数据问题时，只引用工具返回的结果，不许凭空编数字。")
            appendLine("6. 隐私：完整手机号等敏感信息不要完整展示，回答中做脱敏处理。")
        }.trimEnd()

        private val defaultClient: OkHttpClient by lazy {
            OkHttpClient.Builder()
                .connectTimeout(20, TimeUnit.SECONDS)
                .readTimeout(20, TimeUnit.SECONDS)
                .writeTimeout(20, TimeUnit.SECONDS)
                .build()
        }

        private val json: Json = Json { ignoreUnknownKeys = true }
    }

    // MARK: - 局域响应 DTO（第三方类型不出文件）

    @Serializable
    private data class ChatResponse(
        val choices: List<Choice> = emptyList(),
        val model: String? = null
    )

    @Serializable
    private data class Choice(
        val message: ResponseMessage? = null,
        @SerialName("finish_reason") val finishReason: String? = null
    )

    @Serializable
    private data class ResponseMessage(
        val role: String? = null,
        val content: String? = null,
        @SerialName("tool_calls") val toolCalls: List<ResponseToolCall> = emptyList()
    )

    @Serializable
    private data class ResponseToolCall(
        val id: String? = null,
        val type: String? = null,
        val function: ResponseFunction? = null
    )

    @Serializable
    private data class ResponseFunction(
        val name: String? = null,
        val arguments: String? = null
    )

    override suspend fun chat(
        systemPrompt: String,
        messages: List<ProviderMessage>,
        tools: List<ToolDefinition>
    ): Result<ProviderTurn> = withContext(Dispatchers.IO) {
        runCatching { doChat(systemPrompt, messages, tools) }
    }

    private fun doChat(
        systemPrompt: String,
        messages: List<ProviderMessage>,
        tools: List<ToolDefinition>
    ): ProviderTurn {
        val endpoint = baseURL.trimEnd('/') + "/chat/completions"
        val body = buildRequestBody(systemPrompt, messages, tools)
        val request = Request.Builder()
            .url(endpoint)
            .addHeader("Authorization", "Bearer $apiKey")
            .addHeader("Content-Type", "application/json")
            .post(body.toRequestBody("application/json".toMediaType()))
            .build()

        val response = runCatching { client.newCall(request).execute() }.getOrElse { e ->
            throw ProviderException(
                ProviderFailure(
                    kind = if (e is java.net.SocketTimeoutException) ProviderFailureKind.TIMEOUT
                    else ProviderFailureKind.NETWORK,
                    message = e.message ?: "网络请求失败"
                )
            )
        }
        return response.use {
            val raw = it.body?.string().orEmpty()
            if (!it.isSuccessful) {
                val kind = when (it.code) {
                    401, 403 -> ProviderFailureKind.UNAUTHORIZED
                    408 -> ProviderFailureKind.TIMEOUT
                    in 500..599 -> ProviderFailureKind.SERVER_ERROR
                    else -> ProviderFailureKind.SERVER_ERROR
                }
                throw ProviderException(
                    ProviderFailure(
                        kind = kind,
                        message = "HTTP ${it.code}：${raw.take(200)}",
                        httpStatus = it.code
                    )
                )
            }
            val parsed = runCatching { json.decodeFromString(ChatResponse.serializer(), raw) }
                .getOrElse { e ->
                    throw ProviderException(
                        ProviderFailure(
                            kind = ProviderFailureKind.PARSE_ERROR,
                            message = "响应解析失败：${e.message}"
                        )
                    )
                }
            val message = parsed.choices.firstOrNull()?.message
                ?: throw ProviderException(
                    ProviderFailure(
                        kind = ProviderFailureKind.PARSE_ERROR,
                        message = "响应中没有 choices/message"
                    )
                )
            val calls = message.toolCalls.mapNotNull { tc ->
                val wire = tc.function?.name ?: return@mapNotNull null
                val name = ToolName.fromWireName(wire) ?: return@mapNotNull null
                ToolCall(
                    callId = tc.id ?: "call_${java.util.UUID.randomUUID()}",
                    name = name,
                    argumentsJson = tc.function.arguments ?: "{}"
                )
            }
            ProviderTurn(
                text = message.content,
                toolCalls = calls,
                modelUsed = parsed.model
            )
        }
    }

    /**
     * 手工拼 JSON 请求体（避免把局域 DTO 泄到请求模型外）。
     * tools 参数 schema 直接透传 ToolDefinition.parametersJson。
     */
    private fun buildRequestBody(
        systemPrompt: String,
        messages: List<ProviderMessage>,
        tools: List<ToolDefinition>
    ): String {
        val sb = StringBuilder()
        sb.append("{\"model\":").append(escapeJson(model))
        sb.append(",\"temperature\":0.2")
        sb.append(",\"messages\":[")
        sb.append("{\"role\":\"system\",\"content\":").append(escapeJson(systemPrompt)).append("}")
        for (m in messages) {
            sb.append(",")
            when (m.role) {
                "tool" -> sb.append("{\"role\":\"tool\",\"tool_call_id\":")
                    .append(escapeJson(m.toolCallId ?: ""))
                    .append(",\"content\":").append(escapeJson(m.content ?: "")).append("}")
                "assistant" -> {
                    sb.append("{\"role\":\"assistant\"")
                    if (!m.content.isNullOrEmpty()) {
                        sb.append(",\"content\":").append(escapeJson(m.content))
                    }
                    if (m.toolCalls.isNotEmpty()) {
                        sb.append(",\"tool_calls\":[")
                        m.toolCalls.forEachIndexed { index, tc ->
                            if (index > 0) sb.append(",")
                            sb.append("{\"id\":").append(escapeJson(tc.callId))
                                .append(",\"type\":\"function\",\"function\":{\"name\":")
                                .append(escapeJson(tc.name.wireName))
                                .append(",\"arguments\":").append(escapeJson(tc.argumentsJson))
                                .append("}}")
                        }
                        sb.append("]")
                    }
                    sb.append("}")
                }
                else -> sb.append("{\"role\":").append(escapeJson(m.role))
                    .append(",\"content\":").append(escapeJson(m.content ?: "")).append("}")
            }
        }
        sb.append("]")
        if (tools.isNotEmpty()) {
            sb.append(",\"tools\":[")
            tools.forEachIndexed { index, def ->
                if (index > 0) sb.append(",")
                sb.append("{\"type\":\"function\",\"function\":{\"name\":")
                    .append(escapeJson(def.name.wireName))
                    .append(",\"description\":").append(escapeJson(def.description))
                    .append(",\"parameters\":").append(json.encodeToString(JsonObject.serializer(), def.parameters))
                    .append("}}")
            }
            sb.append("]")
        }
        sb.append("}")
        return sb.toString()
    }

    private fun escapeJson(value: String): String {
        val sb = StringBuilder(value.length + 2)
        sb.append('"')
        for (ch in value) {
            when (ch) {
                '"' -> sb.append("\\\"")
                '\\' -> sb.append("\\\\")
                '\n' -> sb.append("\\n")
                '\r' -> sb.append("\\r")
                '\t' -> sb.append("\\t")
                '\b' -> sb.append("\\b")
                else -> if (ch < ' ') sb.append("\\u%04x".format(ch.code)) else sb.append(ch)
            }
        }
        sb.append('"')
        return sb.toString()
    }
}

/** 携带 ProviderFailure 的内部异常（RepositoryToolExecutor / ProviderChain 消费）。 */
class ProviderException(val failure: ProviderFailure) : Exception(failure.message)
