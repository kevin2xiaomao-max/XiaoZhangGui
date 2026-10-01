package com.xiaozhanggui.app.data.ai

import com.xiaozhanggui.app.domain.ai.ActionProposal
import com.xiaozhanggui.app.domain.ai.AiRole
import com.xiaozhanggui.app.domain.ai.AiUiMessage
import com.xiaozhanggui.app.domain.ai.BusinessInsightKind
import com.xiaozhanggui.app.domain.ai.BusinessRecordKind
import com.xiaozhanggui.app.domain.ai.ConversationStore
import com.xiaozhanggui.app.domain.ai.CorrectionParser
import com.xiaozhanggui.app.domain.ai.CustomerPaymentIntent
import com.xiaozhanggui.app.domain.ai.ExecutionJournal
import com.xiaozhanggui.app.domain.ai.IntentKind
import com.xiaozhanggui.app.domain.ai.IntentRouter
import com.xiaozhanggui.app.domain.ai.JournalEntry
import com.xiaozhanggui.app.domain.ai.LocalBusinessParser
import com.xiaozhanggui.app.domain.ai.LocalParseResult
import com.xiaozhanggui.app.domain.ai.PendingActionStore
import com.xiaozhanggui.app.domain.ai.PendingFieldCorrection
import com.xiaozhanggui.app.domain.ai.PendingFieldCorrectionParser
import com.xiaozhanggui.app.domain.ai.ProposalStatus
import com.xiaozhanggui.app.domain.ai.ToolArguments
import com.xiaozhanggui.app.domain.ai.ToolCall
import com.xiaozhanggui.app.domain.ai.ToolCatalog
import com.xiaozhanggui.app.domain.ai.ToolDefinition
import com.xiaozhanggui.app.domain.ai.ToolExecutionResult
import com.xiaozhanggui.app.domain.ai.ToolIdempotency
import com.xiaozhanggui.app.domain.ai.ToolName
import java.util.UUID

/**
 * AI Agent 编排（薄层）。对应 iOS `AI/Core/AgentCore.swift`。
 *
 * 职责（且仅这些）：
 * 用户输入 → 意图分类 → 最小上下文（脱敏）→ Provider 链 →
 *   文本回复 或 单个 ToolCall → 参数 / 权限 / 幂等校验 → ActionCard（CREATE 必确认）
 *
 * 红线：
 * - AgentCore 不持有 Repository；执行只经 RepositoryToolExecutor；
 * - Live 环境绝不允许 Mock：provider 链为空时本地 CREATE 照常走 0-Token，
 *   worldChat 明确告知未配置，不伪装回复；
 * - F0 已放弃 Fathom：单意图 / 单卡确认，不需要多步 Orchestrator。
 */
data class AgentTurnResult(
    val userMessage: AiUiMessage,
    val assistantMessage: AiUiMessage?,
    val proposal: ActionProposal?,
    /** 本轮被纠正替换而取消的旧 proposal（UI 必须立即移除旧卡） */
    val cancelledProposalIds: List<String> = emptyList()
)

class AgentCore(
    private val providerChain: ProviderChain,
    private val router: IntentRouter = IntentRouter(),
    private val contextReader: BusinessContextReader,
    private val insightReader: BusinessInsightReader,
    private val goodsLookupSkill: GoodsLookupSkill,
    private val toolExecutor: RepositoryToolExecutor,
    private val journal: ExecutionJournal,
    private val conversation: ConversationStore,
    private val pending: PendingActionStore,
    private val localParser: LocalBusinessParser = LocalBusinessParser()
) {
    private val toolDefinitions: List<ToolDefinition> = ToolCatalog.definitions()

    companion object {
        /**
         * 没有天气工具时的固定回复（P0-1：必须包含「当前无法查询实时天气」原义）。
         * 对应 iOS AgentCore.weatherUnsupportedText。
         */
        const val WEATHER_UNSUPPORTED_TEXT: String =
            "当前无法查询实时天气，这个版本还没有接入天气查询；" +
                "店里的经营数据（营业额、待办、备忘、配送）随时可以直接问我。"
    }

    // MARK: 读

    suspend fun messages(): List<AiUiMessage> = conversation.messages()
    suspend fun pendingProposals(): List<ActionProposal> = pending.pending()

    // MARK: 一轮对话

    suspend fun send(raw: String): AgentTurnResult {
        val text = raw.trim()
        val userMessage = AiUiMessage(role = AiRole.USER, text = text)
        // 1) 用户原文先持久化（失败也不丢话）
        conversation.append(userMessage)

        if (text.isEmpty()) {
            return AgentTurnResult(userMessage, null, null)
        }

        return try {
            runTurn(text, userMessage)
        } catch (e: Exception) {
            // 2) 失败：保留原文，追加可见的错误回复，提供重试，不脑补。
            val errorMessage = AiUiMessage(role = AiRole.ASSISTANT, text = userFacingError(e), isError = true)
            conversation.append(errorMessage)
            AgentTurnResult(userMessage, errorMessage, null)
        }
    }

    private suspend fun runTurn(text: String, userMessage: AiUiMessage): AgentTurnResult {
        // P0-6：客户订单「未收款」语义。当前模型没有收款状态字段，只能明确告知，
        // 绝不降级成 Todo / Memo，也不写任何业务数据。
        if (CustomerPaymentIntent.isUnpaidCustomerOrder(text)) {
            return appendAssistant(CustomerPaymentIntent.unsupportedMessage, userMessage)
        }

        // P0-5：仅当挂着未确认卡片时才识别纠正话术（避免普通否定句误伤）。
        val activePending = pending.pending()

        if (activePending.size == 1) {
            val proposal = activePending.first()
            val current = decodeArgumentsOrNull(proposal)
            if (current != null) {
                when (val fix = PendingFieldCorrectionParser.parse(text, current)) {
                    is PendingFieldCorrection.Cancel -> {
                        pending.upsert(proposal.copy(status = ProposalStatus.CANCELLED))
                        val reply = appendAssistant("好的，刚才那条已取消。", userMessage)
                        return reply.copy(proposal = null, cancelledProposalIds = listOf(proposal.id))
                    }
                    is PendingFieldCorrection.FollowUp ->
                        return appendAssistant(fix.question, userMessage)
                    is PendingFieldCorrection.Update -> {
                        val updated = proposal.copy(
                            argumentsJson = fix.arguments.encode(),
                            status = ProposalStatus.PENDING,
                            resultText = null
                        )
                        pending.upsert(updated)
                        val assistant = AiUiMessage(
                            role = AiRole.ASSISTANT, text = fix.message, proposalId = proposal.id
                        )
                        conversation.append(assistant)
                        return AgentTurnResult(userMessage, assistant, updated)
                    }
                    null -> Unit
                }
            }
        }

        val correction = if (activePending.isEmpty()) null else CorrectionParser.detect(text)
        if (correction != null) {
            val cancelledIds = activePending.map { it.id }
            for (old in activePending) {
                pending.upsert(old.copy(status = ProposalStatus.CANCELLED))
            }
            val cleaned = correction.cleanedText
            if (cleaned.isEmpty()) {
                val reply = appendAssistant(
                    "好的，上一条已取消。你想改成记录什么？直接把新内容发给我就行。",
                    userMessage
                )
                return reply.copy(cancelledProposalIds = cancelledIds)
            }
            var intent = router.classify(cleaned)
            if (correction.targetTool != null) {
                intent = IntentKind.BusinessAction(correction.targetTool)
            }
            val result = handleIntent(intent, cleaned, text, userMessage)
            return result.copy(cancelledProposalIds = cancelledIds)
        }

        val intent = router.classify(text)
        return handleIntent(intent, text, text, userMessage)
    }

    private suspend fun handleIntent(
        intent: IntentKind,
        workingText: String,
        originalText: String,
        userMessage: AiUiMessage
    ): AgentTurnResult {
        return when (intent) {
            is IntentKind.BusinessAction -> {
                // Free First：本地高置信规则 0 Token 直接出卡 / 追问；
                // 本地无把握（返回 null）才允许上云。
                when (val local = localParser.parse(workingText, intent)) {
                    is LocalParseResult.Tool -> {
                        val call = ToolCall(
                            callId = ToolIdempotency.newCallId(),
                            name = local.arguments.toolName,
                            argumentsJson = local.arguments.toToolCall().argumentsJson
                        )
                        handleToolCall(call, userMessage)
                    }
                    is LocalParseResult.Clarify -> appendAssistant(local.message, userMessage)
                    null -> remoteTurn(intent, workingText, originalText, userMessage)
                }
            }

            is IntentKind.BusinessQuery ->
                // Lite：READ 全部本地聚合回答（0 Token，数据不出设备）。
                // workingText 透传给周期解析（"上个月营业额"→上月区间）。
                appendAssistant(contextReader.answer(intent.kind, workingText), userMessage)

            is IntentKind.WeatherQuery ->
                appendAssistant(WEATHER_UNSUPPORTED_TEXT, userMessage)

            is IntentKind.GoodsQuery ->
                appendAssistant(goodsLookupSkill.lookup(intent.query), userMessage)

            is IntentKind.BusinessInsight -> {
                val pack = insightReader.groundingPack()
                if (intent.kind == BusinessInsightKind.Advice) {
                    if (!pack.hasBusinessData) {
                        return appendAssistant(
                            "目前还没有足够的店铺数据可以分析。先记录营业额、待办或商品库存后再问我吧。",
                            userMessage
                        )
                    }
                    // 建议类走云端（Lite 不外发经营原始数据，context 恒空）
                    return remoteTurn(intent, workingText, originalText, userMessage)
                }
                appendAssistant(BusinessAnswerComposer.answer(intent.kind, pack), userMessage)
            }

            is IntentKind.WorldChat, is IntentKind.LocalZeroToken -> {
                MetaReply.reply(workingText)?.let { return appendAssistant(it, userMessage) }
                remoteTurn(intent, workingText, originalText, userMessage)
            }
        }
    }

    /**
     * 上云一轮：仅在本地无把握（CREATE）、建议类分析或普通聊天时调用。
     * Lite 不把经营数据随云端 CREATE / 聊天外发（READ 已本地回答），context 恒空。
     * 无可用 Provider（未配置 Key）时：明确告知，不伪装 Mock 回复（Release 红线）。
     */
    private suspend fun remoteTurn(
        intent: IntentKind,
        workingText: String,
        originalText: String,
        userMessage: AiUiMessage
    ): AgentTurnResult {
        if (!providerChain.hasPrimary) {
            return appendAssistant(
                "AI 云端还没配置（需要在设置里填入 API Key）。不过记账、记配送、记备忘、记待办这些本地功能现在就能用，直接说就行。",
                userMessage
            )
        }

        // 多轮纠正时发送给模型的是剥掉话术的 workingText（原文仍保留在本地会话里）
        val history = conversation.messages()
            .map { msg ->
                when (msg.role) {
                    AiRole.USER -> ProviderMessage(role = "user", content = msg.text)
                    AiRole.ASSISTANT -> ProviderMessage(role = "assistant", content = msg.text)
                    AiRole.TOOL -> ProviderMessage(role = "tool", content = msg.text)
                }
            }
            .toMutableList()
        val lastUserIndex = history.indexOfLast { it.role == "user" }
        if (lastUserIndex >= 0 && workingText != originalText) {
            history[lastUserIndex] = ProviderMessage(role = "user", content = workingText)
        }

        val result = runCatching {
            providerChain.chat(OpenAiCompatProvider.systemPrompt, history, toolDefinitions)
                .getOrThrow()
        }
        val turn = result.getOrElse { e ->
            // ProviderFailure / 网络错误保留类型化错误：由 send() 经 userFacingError 统一映射中文
            throw e
        }

        if (turn.toolCalls.isNotEmpty()) {
            return handleToolCall(turn.toolCalls.first(), userMessage)
        }
        val reply = turn.text?.takeIf { it.isNotBlank() } ?: "我没太明白，能换个说法吗？"
        return appendAssistant(reply, userMessage)
    }

    private suspend fun appendAssistant(
        content: String,
        userMessage: AiUiMessage,
        proposal: ActionProposal? = null
    ): AgentTurnResult {
        val message = AiUiMessage(role = AiRole.ASSISTANT, text = content, proposalId = proposal?.id)
        conversation.append(message)
        return AgentTurnResult(userMessage, message, proposal)
    }

    private suspend fun handleToolCall(call: ToolCall, userMessage: AiUiMessage): AgentTurnResult {
        if (!ToolCatalog.isRegistered(call.name)) {
            throw ProviderException(
                ProviderFailure(ProviderFailureKind.PARSE_ERROR, "不支持的工具：${call.name.wireName}")
            )
        }
        // READ：权限允许自动执行，但结果只在本机聚合回答（0 Token、不出设备）。
        if (call.name == ToolName.SEARCH_RECORDS) {
            val searchArgs = (call.decodeArguments() as? ToolArguments.SearchRecords)?.args
            val kinds = searchArgs?.kinds?.takeIf { it.isNotEmpty() }
                ?: listOf(
                    BusinessRecordKind.REVENUE_TODAY,
                    BusinessRecordKind.TODO_TODAY,
                    BusinessRecordKind.RECENT_MEMO,
                    BusinessRecordKind.EXPIRING_GOODS,
                    BusinessRecordKind.DELIVERY
                )
            val parts = kinds.map { contextReader.answer(it, searchArgs?.query) }
            return appendAssistant(parts.joinToString("\n\n"), userMessage)
        }

        val arguments = call.decodeArguments()
        val validationErrors = ToolCatalog.validate(call)
        if (validationErrors.isNotEmpty()) {
            return appendAssistant(
                "信息还不完整：${validationErrors.joinToString("、")}。你可以补充后再发一次。",
                userMessage
            )
        }

        val fingerprint = ToolIdempotency.fingerprint(call)
        if (journal.isFingerprintUsed(fingerprint)) {
            return appendAssistant("这条记录已经处理过，不会重复保存。", userMessage)
        }

        val proposal = ActionProposal(
            toolName = call.name,
            argumentsJson = call.argumentsJson,
            status = ProposalStatus.PENDING
        )
        pending.upsert(proposal)
        journal.append(
            JournalEntry(
                toolCallId = call.callId,
                fingerprint = fingerprint,
                toolName = call.name.wireName,
                status = ProposalStatus.PENDING.wire,
                recordId = null,
                createdAt = System.currentTimeMillis()
            )
        )

        val message = AiUiMessage(
            role = AiRole.ASSISTANT,
            text = "准备记录，请确认：",
            proposalId = proposal.id
        )
        conversation.append(message)
        return AgentTurnResult(userMessage, message, proposal)
    }

    // MARK: 清空对话

    /**
     * 清空当前聊天：消息 + 未确认 ActionCard 全部清除，重启后仍为空。
     * 刻意不清 ExecutionJournal：已真实写入业务库的数据与幂等防重记录绝不受影响。
     */
    suspend fun clearConversation() {
        conversation.clear()
        pending.clear()
    }

    // MARK: ActionCard 操作

    /**
     * 用户点「确认记录」。只接受 status == pending 的卡；
     * 真实执行经 RepositoryToolExecutor（双重幂等预检）。
     */
    suspend fun confirm(proposalId: String): ActionProposal? {
        val proposal = pending.proposal(proposalId) ?: return null
        if (proposal.status != ProposalStatus.PENDING) return null

        pending.upsert(proposal.copy(status = ProposalStatus.CONFIRMED))
        val call = ToolCall(
            callId = UUID.randomUUID().toString(),
            name = proposal.toolName,
            argumentsJson = proposal.argumentsJson
        )
        val result = toolExecutor.execute(call)
        val updated = when (result) {
            is ToolExecutionResult.Executed -> proposal.copy(
                status = ProposalStatus.EXECUTED,
                resultText = result.summary
            )
            is ToolExecutionResult.Duplicate -> proposal.copy(
                status = ProposalStatus.DUPLICATE,
                resultText = "与已处理的操作重复，已跳过"
            )
            is ToolExecutionResult.Failed -> proposal.copy(
                status = ProposalStatus.FAILED,
                resultText = result.reason
            )
        }
        // 账本兜底：执行器已在成功时 markExecuted（upsert 语义）；
        // 测试替身未写账本时这里再推进一次，保证判重生效。
        if (result is ToolExecutionResult.Executed) {
            journal.markExecuted(
                JournalEntry(
                    toolCallId = call.callId,
                    fingerprint = ToolIdempotency.fingerprint(call),
                    toolName = call.name.wireName,
                    status = ProposalStatus.EXECUTED.wire,
                    recordId = result.recordId,
                    createdAt = System.currentTimeMillis()
                )
            )
        }
        pending.upsert(updated)
        return updated
    }

    /** 用户删除待确认项 */
    suspend fun cancel(proposalId: String) {
        val proposal = pending.proposal(proposalId) ?: return
        pending.upsert(proposal.copy(status = ProposalStatus.CANCELLED))
    }

    /**
     * 失败卡「重试保存」：仅 failed 状态可重试，先重置为 pending 再走 confirm。
     * （iOS ActionCard 失败态按钮文案为「重试保存」，此处让它真正可重试。）
     */
    suspend fun retry(proposalId: String): ActionProposal? {
        val proposal = pending.proposal(proposalId) ?: return null
        if (proposal.status != ProposalStatus.FAILED) return null
        pending.upsert(proposal.copy(status = ProposalStatus.PENDING, resultText = null))
        return confirm(proposalId)
    }

    /**
     * 用户点「修改」：取消当前卡，返回该卡对应的上一条用户原文，
     * 以便用户改写重发（旧卡立即失效）。
     */
    suspend fun modify(proposalId: String): String? {
        val proposal = pending.proposal(proposalId) ?: return null
        cancel(proposalId)
        val messages = conversation.messages()
        val assistantIndex = messages.indexOfLast { it.proposalId == proposal.id }
        if (assistantIndex > 0) {
            for (index in assistantIndex - 1 downTo 0) {
                if (messages[index].role == AiRole.USER) return messages[index].text
            }
        }
        return null
    }

    // MARK: - 错误映射

    private fun userFacingError(e: Throwable): String {
        val failure = (e as? ProviderException)?.failure
        return when (failure?.kind) {
            ProviderFailureKind.NOT_CONFIGURED -> "AI 还没配置：在设置里填入 API Key 后再试（你刚说的话已保留）。"
            ProviderFailureKind.UNAUTHORIZED -> "API Key 无效或无权限，请检查设置里的 Key（你刚说的话已保留）。"
            ProviderFailureKind.TIMEOUT -> "请求超时，请稍后重试（你刚说的话已保留）。"
            ProviderFailureKind.NETWORK -> "网络不可达，请检查网络后重试（你刚说的话已保留）。"
            ProviderFailureKind.SERVER_ERROR -> "AI 服务暂时异常，请稍后重试（你刚说的话已保留）。"
            ProviderFailureKind.PARSE_ERROR -> "AI 返回的内容解析失败，请重试（你刚说的话已保留）。"
            ProviderFailureKind.CANCELLED -> "请求已取消（你刚说的话已保留）。"
            null -> "处理失败，请重试（你刚说的话已保留）"
        }
    }

    private fun decodeArgumentsOrNull(proposal: ActionProposal): ToolArguments? =
        runCatching {
            ToolCall(
                callId = "decode",
                name = proposal.toolName,
                argumentsJson = proposal.argumentsJson
            ).decodeArguments()
        }.getOrNull()
}
