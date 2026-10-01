package com.xiaozhanggui.app.data.ai

import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.data.repository.ExpiryRepository
import com.xiaozhanggui.app.data.repository.MemoRepository
import com.xiaozhanggui.app.data.repository.PerformanceRepository
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.domain.ai.BusinessPeriod
import com.xiaozhanggui.app.domain.ai.BusinessPeriodParser
import com.xiaozhanggui.app.domain.ai.BusinessRecordKind
import com.xiaozhanggui.app.domain.ai.SearchRecordsArguments
import kotlinx.coroutines.flow.first
import java.time.Instant
import java.time.ZoneId

/**
 * 经营读问答的本地聚合。对应 iOS `AI/Context/BusinessContextProvider.swift`
 * 涉及的经营查询分支（businessQuery → 本地聚合 → 隐私裁剪后回答）。
 *
 * 只读 Repository.observeAll() 的首值；聚合结果经隐私裁剪（手机号脱敏）
 * 后由 AgentCore 转成自然语言回复。无 Key 也可工作。
 */
class BusinessContextReader(
    private val moneyRepository: PerformanceRepository,
    private val todoRepository: TodoRepository,
    private val memoRepository: MemoRepository,
    private val customerRepository: CustomerRepository,
    private val expiryRepository: ExpiryRepository
) {
    private val zone: ZoneId get() = ZoneId.systemDefault()

    private fun startOfDay(millis: Long): Long =
        Instant.ofEpochMilli(millis).atZone(zone).toLocalDate()
            .atStartOfDay(zone).toInstant().toEpochMilli()

    /** 手机号脱敏：13812345678 → 138****5678 */
    private fun maskPhone(phone: String): String =
        if (phone.length >= 7) {
            phone.take(3) + "*".repeat(phone.length - 7) + phone.takeLast(4)
        } else phone

    private fun money(value: Double): String {
        val rounded = kotlin.math.round(value * 100) / 100.0
        return if (rounded == kotlin.math.floor(rounded)) {
            "¥${rounded.toLong()}"
        } else {
            "¥${"%.2f".format(rounded).trimEnd('0')}"
        }
    }

    /**
     * 按记录种类回答。周期词（如"上个月"）从查询原文 query 里解析，
     * 与 iOS BusinessContextProvider 的 period 语义一致。
     */
    suspend fun answer(
        kind: BusinessRecordKind,
        periodText: String? = null,
        now: Long = System.currentTimeMillis()
    ): String {
        return when (kind) {
            BusinessRecordKind.REVENUE_TODAY -> answerRevenue(periodText, now)
            BusinessRecordKind.DELIVERY -> answerDelivery(now)
            BusinessRecordKind.EXPIRING_GOODS -> answerExpiring(now)
            BusinessRecordKind.TODO_TODAY -> answerTodo(now)
            BusinessRecordKind.RECENT_MEMO -> answerMemo()
        }
    }

    suspend fun answer(args: SearchRecordsArguments, now: Long = System.currentTimeMillis()): String {
        val kind = args.kinds.firstOrNull() ?: return "暂无查询条件。"
        return answer(kind, args.query, now)
    }

    // MARK: - 聚合

    private suspend fun answerRevenue(periodText: String?, now: Long): String {
        val parser = BusinessPeriodParser()
        val period = periodText?.let { parser.parse(it) } ?: BusinessPeriod.TODAY
        val (start, end) = parser.bounds(period, now)
        val records = moneyRepository.observeAll().first()
            .filter { it.date >= start && it.date < end }
        if (records.isEmpty()) return "该周期没有营业额记录。"
        val total = records.sumOf { it.amount }
        val periodLabel = when (period) {
            BusinessPeriod.TODAY -> "今天"
            BusinessPeriod.YESTERDAY -> "昨天"
            BusinessPeriod.LAST_SEVEN_DAYS -> "最近7天"
            BusinessPeriod.THIS_MONTH -> "这个月"
            BusinessPeriod.LAST_MONTH -> "上个月"
            BusinessPeriod.LAST_THREE_MONTHS -> "最近3个月"
            BusinessPeriod.LAST_SIX_MONTHS -> "最近6个月"
            BusinessPeriod.THIS_MONTH_COMPARED_WITH_LAST_MONTH,
            BusinessPeriod.LAST_THREE_MONTHS_COMPARED_WITH_THIS_MONTH -> "对比周期"
        }
        return "$periodLabel 共记录 ${records.size} 笔，合计 ${money(total)}。"
    }

    private suspend fun answerDelivery(now: Long): String {
        val todayStart = startOfDay(now)
        val items = customerRepository.observeAll().first()
            .filter { it.createdAt >= todayStart }
        if (items.isEmpty()) return "今天还没有配送单。"
        val pending = items.count { it.status == "pending" }
        val lines = items.take(5).map { item ->
            val who = item.customer.ifEmpty { "（未留客户）" }
            val addr = item.roomOrAddress.ifEmpty { "" }
            val phone = if (item.phone.isNotEmpty()) " ${maskPhone(item.phone)}" else ""
            "- $who $addr$phone：${item.content.take(30)}"
        }
        val summary = "今天共 ${items.size} 单配送${if (pending > 0) "（待处理 $pending 单）" else ""}。"
        return summary + "\n" + lines.joinToString("\n")
    }

    private suspend fun answerExpiring(now: Long): String {
        val soon = now + 7L * 24 * 3600 * 1000
        val items = expiryRepository.observeAll().first()
            .filter { it.expiryDate <= soon }
            .sortedBy { it.expiryDate }
        if (items.isEmpty()) return "7 天内没有临期或过期商品。"
        val lines = items.take(8).map { item ->
            val day = Instant.ofEpochMilli(item.expiryDate).atZone(zone).toLocalDate()
            "- ${item.name}：到期 $day"
        }
        return "7 天内临期 / 已过期共 ${items.size} 件：\n" + lines.joinToString("\n")
    }

    private suspend fun answerTodo(now: Long): String {
        val endOfDay = startOfDay(now) + 24L * 3600 * 1000
        val items = todoRepository.observeAll().first()
            .filter { !it.isCompleted && (it.dueDate == null || it.dueDate < endOfDay) }
            .sortedBy { it.dueDate ?: Long.MAX_VALUE }
        if (items.isEmpty()) return "今天没有待办事项。"
        val lines = items.take(8).map { "- ${it.title}" }
        return "今日待办 ${items.size} 项：\n" + lines.joinToString("\n")
    }

    private suspend fun answerMemo(): String {
        val items = memoRepository.observeAll().first()
            .sortedByDescending { it.createdAt }
            .take(5)
        if (items.isEmpty()) return "还没有备忘记录。"
        return "最近备忘：\n" + items.joinToString("\n") { "- ${it.title}" }
    }
}
