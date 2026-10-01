package com.xiaozhanggui.app.data.ai

import com.xiaozhanggui.app.data.db.IncomeSource
import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.data.repository.MemoRepository
import com.xiaozhanggui.app.data.repository.PerformanceRepository
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.domain.ai.ExecutionJournal
import com.xiaozhanggui.app.domain.ai.JournalEntry
import com.xiaozhanggui.app.domain.ai.ProposalStatus
import com.xiaozhanggui.app.domain.ai.ToolArguments
import com.xiaozhanggui.app.domain.ai.ToolCall
import com.xiaozhanggui.app.domain.ai.ToolCatalog
import com.xiaozhanggui.app.domain.ai.ToolExecutionResult
import com.xiaozhanggui.app.domain.ai.ToolIdempotency

/**
 * AI 工具真实执行器（data/ai，AI 层之外，AI ToolCall → 现有 Repository 的唯一桥）。
 * 对应 iOS `AI/Integration/RepositoryToolExecutor.swift`（唯一允许写业务库的 AI 入口）。
 *
 * 架构红线：
 * - Provider / AgentCore / ActionCard / IntentRouter 都不持有 Repository；
 * - 不新写第二套保存逻辑，全部调用既有 Repository（内部已做 insert + 通知 + 快照刷新）；
 * - 执行前双重幂等预检（toolCallID + 业务指纹），重复确认 / 重试 / 崩溃恢复都不会写第二次；
 * - 只支持 4 个 CREATE；searchRecords 是 READ，不应到达这里；UPDATE / DELETE 未注册。
 */
class RepositoryToolExecutor(
    private val moneyRepository: PerformanceRepository,
    private val todoRepository: TodoRepository,
    private val memoRepository: MemoRepository,
    private val customerRepository: CustomerRepository,
    private val journal: ExecutionJournal
) {
    suspend fun execute(call: ToolCall): ToolExecutionResult {
        // 幂等预检：只认 executed 状态（pending / failed 不算已执行）
        if (journal.has(call.callId) &&
            journal.entries().any { it.toolCallId == call.callId && it.status == ProposalStatus.EXECUTED.wire }
        ) {
            return ToolExecutionResult.Duplicate(existingToolCallId = call.callId)
        }
        val fingerprint = ToolIdempotency.fingerprint(call)
        if (journal.isFingerprintUsed(fingerprint)) {
            return ToolExecutionResult.Duplicate(existingToolCallId = call.callId)
        }

        // 防御性二次校验（AgentCore 已校验一次，执行层不允许写入非法数据）
        val arguments = call.decodeArguments()
        val violations = ToolCatalog.validate(call)
        if (violations.isNotEmpty()) {
            return ToolExecutionResult.Failed(
                reason = "参数不完整，已阻止写入：${violations.joinToString("；")}"
            )
        }

        val result: ToolExecutionResult = try {
            perform(call, arguments)
        } catch (e: Exception) {
            ToolExecutionResult.Failed(
                reason = "保存失败：${e.message ?: e.toString()}"
            )
        }

        // 真实写库成功后，由唯一执行入口把账本推进为 executed（替换 pending 记录），
        // 保证崩溃恢复 / 重放 / 重复回调时判重生效。
        if (result is ToolExecutionResult.Executed) {
            journal.markExecuted(
                JournalEntry(
                    toolCallId = call.callId,
                    fingerprint = fingerprint,
                    toolName = call.name.wireName,
                    status = ProposalStatus.EXECUTED.wire,
                    recordId = result.recordId,
                    createdAt = System.currentTimeMillis()
                )
            )
        }
        return result
    }

    private suspend fun perform(call: ToolCall, arguments: ToolArguments): ToolExecutionResult {
        return when (arguments) {
            is ToolArguments.Revenue -> executeRevenue(call, arguments.args)
            is ToolArguments.Todo -> executeTodo(call, arguments.args)
            is ToolArguments.Memo -> executeMemo(call, arguments.args)
            is ToolArguments.Delivery -> executeDelivery(call, arguments.args)
            is ToolArguments.SearchRecords ->
                // READ 由 AgentCore 本地聚合回答，永远不应走到执行器
                ToolExecutionResult.Failed(reason = "查询类操作不经过写库执行器")
        }
    }

    // MARK: 营业额

    private suspend fun executeRevenue(
        call: com.xiaozhanggui.app.domain.ai.ToolCall,
        args: com.xiaozhanggui.app.domain.ai.RevenueArguments
    ): ToolExecutionResult {
        val amount = args.amount
        if (amount == null || amount <= 0) {
            return ToolExecutionResult.Failed(reason = "营业额金额缺失或无效")
        }
        val source = args.source?.trim()
        val note = listOf(source, args.note)
            .mapNotNull { it?.trim() }
            .filter { it.isNotEmpty() }
            .joinToString(" ")
        val finalNote = note.ifEmpty { "小掌柜" }
        moneyRepository.add(
            amount = amount,
            note = finalNote,
            date = args.date ?: System.currentTimeMillis(),
            incomeSource = IncomeSource.fromNote(source ?: args.note ?: "")
        )
        return ToolExecutionResult.Executed(
            recordId = call.callId,
            summary = "已记录营业额 ${money(amount)}${if (source != null) "（$source）" else ""}"
        )
    }

    // MARK: 待办

    private suspend fun executeTodo(
        call: ToolCall,
        args: com.xiaozhanggui.app.domain.ai.TodoArguments
    ): ToolExecutionResult {
        val title = args.title?.trim()
        if (title.isNullOrEmpty()) {
            return ToolExecutionResult.Failed(reason = "待办标题缺失")
        }
        val priority = (args.priority ?: 0).coerceIn(0, 2)
        todoRepository.add(
            title = title,
            detail = args.detail?.trim() ?: "",
            dueDate = args.dueDate,
            priority = priority
        )
        return ToolExecutionResult.Executed(
            recordId = call.callId,
            summary = "已新建待办：$title"
        )
    }

    // MARK: 备忘

    private suspend fun executeMemo(
        call: ToolCall,
        args: com.xiaozhanggui.app.domain.ai.MemoArguments
    ): ToolExecutionResult {
        val title = args.title?.trim()
        if (title.isNullOrEmpty()) {
            return ToolExecutionResult.Failed(reason = "备忘标题缺失")
        }
        val content = args.content?.trim()?.takeIf { it.isNotEmpty() } ?: title
        memoRepository.add(title = title, content = content)
        return ToolExecutionResult.Executed(
            recordId = call.callId,
            summary = "已新建备忘：$title"
        )
    }

    // MARK: 配送

    private suspend fun executeDelivery(
        call: ToolCall,
        args: com.xiaozhanggui.app.domain.ai.DeliveryArguments
    ): ToolExecutionResult {
        val customer = args.customer?.trim() ?: ""
        val room = args.roomOrAddress?.trim() ?: if (customer.isEmpty()) "" else customer
        val phone = args.phone?.trim() ?: ""

        var content = args.content?.trim() ?: ""
        if (content.isEmpty()) {
            content = listOf(args.goodsName, args.quantity)
                .mapNotNull { it?.trim() }
                .filter { it.isNotEmpty() }
                .joinToString("")
        }
        val parts = mutableListOf<String>()
        if (content.isNotEmpty()) parts.add(content)
        val amount = args.amount
        if (amount != null && amount > 0) parts.add(money(amount))
        val timeText = args.deliveryTimeText?.trim()
        if (!timeText.isNullOrEmpty()) parts.add("（$timeText）")
        val note = args.note?.trim()
        if (!note.isNullOrEmpty()) parts.add(note)
        val finalContent = parts.joinToString(" ")

        if (customer.isEmpty() && finalContent.isEmpty()) {
            return ToolExecutionResult.Failed(reason = "配送缺少客户与商品信息")
        }

        customerRepository.add(
            customer = customer,
            roomOrAddress = room,
            phone = phone,
            content = finalContent
        )
        val who = if (customer.isEmpty()) "" else "$customer "
        return ToolExecutionResult.Executed(
            recordId = call.callId,
            summary = "已新建配送：$who$finalContent".trim()
        )
    }

    // MARK: 工具

    /** ¥ 金额展示（iOS money()：decimal、最多 2 位小数、无尾零）。 */
    private fun money(value: Double): String {
        val rounded = kotlin.math.round(value * 100) / 100.0
        val text = if (rounded == kotlin.math.floor(rounded)) {
            rounded.toLong().toString()
        } else {
            "%.2f".format(rounded).trimEnd('0')
        }
        return "¥$text"
    }
}
