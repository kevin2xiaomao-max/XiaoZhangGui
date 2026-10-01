package com.xiaozhanggui.app.data.ai

import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.data.repository.ExpiryRepository
import com.xiaozhanggui.app.data.repository.GoodsRepository
import com.xiaozhanggui.app.data.repository.PerformanceRepository
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.domain.ai.BusinessInsightKind
import com.xiaozhanggui.app.domain.ai.BusinessPeriod
import com.xiaozhanggui.app.domain.ai.BusinessPeriodParser
import kotlinx.coroutines.flow.first
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * 经营分析的本地上下文包与模板回答。对应 iOS
 * `AI/Context/BusinessContextProvider.groundingPack()` +
 * `AI/Context/BusinessAnswerComposer.answer(for: BusinessInsightKind)`。
 *
 * Insight 除 advice 外全部本地 0-token 回答；advice 由 AgentCore 走云端（本版本直接走云端）。
 * 只保留聚合值和短标题，不承载客户隐私（手机号 / 完整地址默认不进入）。
 */

data class GoodsSummary(
    val name: String,
    val purchasePrice: Double,
    val salePrice: Double,
    val stock: Int,
    val minStock: Int
)

data class DailyRevenueSummary(val day: LocalDate, val amount: Double)

data class BusinessPeriodSummary(
    val period: BusinessPeriod,
    val amount: Double,
    val count: Int,
    val comparisonAmount: Double?,
    val comparisonMonthCount: Int?,
    val comparisonAverageAmount: Double?
)

data class GroundingPack(
    val todayRevenue: Double?,
    val yesterdayRevenue: Double?,
    val sevenDayRevenue: List<DailyRevenueSummary>,
    val unfinishedTodoTitles: List<String>,
    val deliveryPendingCount: Int,
    val deliveryDeliveringCount: Int,
    val expiryTitles: List<String>,
    val goods: List<GoodsSummary>,
    val periodSummaries: List<BusinessPeriodSummary> = emptyList()
) {
    val hasBusinessData: Boolean
        get() = todayRevenue != null || yesterdayRevenue != null ||
            sevenDayRevenue.any { it.amount != 0.0 } ||
            periodSummaries.any { it.amount != 0.0 || (it.comparisonAmount ?: 0.0) != 0.0 || it.count > 0 } ||
            unfinishedTodoTitles.isNotEmpty() || deliveryPendingCount > 0 ||
            deliveryDeliveringCount > 0 || expiryTitles.isNotEmpty() || goods.isNotEmpty()
}

/** 经营上下文聚合（只读 Repository 首值）。 */
class BusinessInsightReader(
    private val moneyRepository: PerformanceRepository,
    private val todoRepository: TodoRepository,
    private val customerRepository: CustomerRepository,
    private val expiryRepository: ExpiryRepository,
    private val goodsRepository: GoodsRepository
) {
    private val zone: ZoneId get() = ZoneId.systemDefault()

    suspend fun groundingPack(now: Long = System.currentTimeMillis()): GroundingPack {
        val parser = BusinessPeriodParser()
        val (todayStart, tomorrowStart) = parser.bounds(BusinessPeriod.TODAY, now)
        val (yesterdayStart, _) = parser.bounds(BusinessPeriod.YESTERDAY, now)
        val (sevenStart, _) = parser.bounds(BusinessPeriod.LAST_SEVEN_DAYS, now)

        val revenues = moneyRepository.observeAll().first()
        fun sumIn(start: Long, end: Long): Double =
            revenues.filter { it.date >= start && it.date < end }.sumOf { it.amount }

        fun optionalSum(start: Long, end: Long): Double? {
            val inRange = revenues.filter { it.date >= start && it.date < end }
            return inRange.sumOf { it.amount }.takeIf { inRange.isNotEmpty() }
        }

        val todayDate = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
        val sevenDay = (0..6).map { back ->
            val day = todayDate.minusDays(back.toLong())
            val start = day.atStartOfDay(zone).toInstant().toEpochMilli()
            DailyRevenueSummary(day, sumIn(start, start + 24L * 3600 * 1000))
        }

        val todos = todoRepository.observeAll().first()
            .filter { !it.isCompleted }
            .map { it.title }
        val customers = customerRepository.observeAll().first()
        val expiries = expiryRepository.observeAll().first()
            .filter { it.expiryDate <= now + 7L * 24 * 3600 * 1000 }
            .map { it.name }
        val goods = goodsRepository.observeAll().first().map {
            GoodsSummary(it.name, it.purchasePrice, it.salePrice, it.stock, it.minStock)
        }

        // periodSummaries：为用户问到的周期预聚合（含对比）
        val periods = listOf(
            BusinessPeriod.THIS_MONTH, BusinessPeriod.LAST_MONTH,
            BusinessPeriod.LAST_THREE_MONTHS, BusinessPeriod.LAST_SIX_MONTHS,
            BusinessPeriod.THIS_MONTH_COMPARED_WITH_LAST_MONTH,
            BusinessPeriod.LAST_THREE_MONTHS_COMPARED_WITH_THIS_MONTH
        )
        val periodSummaries = periods.map { period ->
            val (s, e) = parser.bounds(period, now)
            val inPeriod = revenues.filter { it.date >= s && it.date < e }
            when (period) {
                BusinessPeriod.THIS_MONTH_COMPARED_WITH_LAST_MONTH -> {
                    val (ls, le) = parser.bounds(BusinessPeriod.LAST_MONTH, now)
                    BusinessPeriodSummary(
                        period, inPeriod.sumOf { it.amount }, inPeriod.size,
                        comparisonAmount = revenues.filter { it.date >= ls && it.date < le }.sumOf { it.amount },
                        comparisonMonthCount = 1,
                        comparisonAverageAmount = null
                    )
                }
                BusinessPeriod.LAST_THREE_MONTHS_COMPARED_WITH_THIS_MONTH -> {
                    // 前 3 个完整自然月逐月聚合
                    val monthSums = (1..3).map { back ->
                        val first = todayDate.withDayOfMonth(1).minusMonths(back.toLong())
                        val ms = first.atStartOfDay(zone).toInstant().toEpochMilli()
                        val me = first.plusMonths(1).atStartOfDay(zone).toInstant().toEpochMilli()
                        revenues.filter { it.date >= ms && it.date < me }.sumOf { it.amount }
                    }
                    val withData = monthSums.count { it > 0 }
                    val total = monthSums.sum()
                    BusinessPeriodSummary(
                        period, inPeriod.sumOf { it.amount }, inPeriod.size,
                        comparisonAmount = total,
                        comparisonMonthCount = withData,
                        comparisonAverageAmount = if (withData > 0) total / withData else 0.0
                    )
                }
                else -> BusinessPeriodSummary(
                    period, inPeriod.sumOf { it.amount }, inPeriod.size,
                    comparisonAmount = null, comparisonMonthCount = null, comparisonAverageAmount = null
                )
            }
        }

        return GroundingPack(
            todayRevenue = optionalSum(todayStart, tomorrowStart),
            yesterdayRevenue = optionalSum(yesterdayStart, todayStart),
            sevenDayRevenue = sevenDay,
            unfinishedTodoTitles = todos,
            deliveryPendingCount = customers.count { it.status == "pending" },
            deliveryDeliveringCount = customers.count { it.status == "delivering" },
            expiryTitles = expiries,
            goods = goods,
            periodSummaries = periodSummaries
        )
    }
}

object BusinessAnswerComposer {

    fun answer(insight: BusinessInsightKind, pack: GroundingPack): String {
        if (!pack.hasBusinessData) return "目前还没有足够的店铺数据可以分析。"
        return when (insight) {
            is BusinessInsightKind.Overview ->
                "今天营业额${pack.todayRevenue?.let { money(it) } ?: "暂无记录"}。"
            is BusinessInsightKind.Comparison -> {
                val today = pack.todayRevenue
                    ?: return "今天还没有营业额记录，暂时无法和昨天比较。"
                val yesterday = pack.yesterdayRevenue
                    ?: return "今天营业额 ${money(today)}，昨天没有营业额记录。"
                if (yesterday == 0.0) return "今天营业额 ${money(today)}，昨天营业额为 0，暂不计算百分比。"
                val change = (today - yesterday) / yesterday * 100
                if (kotlin.math.abs(change) < 0.05) return "今天营业额 ${money(today)}，与昨天基本持平。"
                "今天营业额 ${money(today)}，较昨天${if (change > 0) "增长" else "下降"} ${"%.1f".format(kotlin.math.abs(change))}%。"
            }
            is BusinessInsightKind.SevenDayTrend -> {
                val values = pack.sevenDayRevenue.map { it.amount }
                if (values.isEmpty()) return "最近 7 天还没有营业额记录。"
                val total = values.sum()
                if (total <= 0) return "最近 7 天还没有营业额记录。"
                val first = values.take(3).let { it.sum() / maxOf(it.size, 1) }
                val last = values.takeLast(3).let { it.sum() / maxOf(it.size, 1) }
                val direction = when {
                    last > first * 1.05 -> "走高"
                    last < first * 0.95 -> "走低"
                    else -> "基本平稳"
                }
                "最近 7 天营业额合计 ${money(total)}，日均 ${money(total / values.size)}，整体$direction。"
            }
            is BusinessInsightKind.Inventory -> {
                val low = pack.goods.filter { it.stock <= it.minStock }
                if (pack.goods.isEmpty()) return "目前还没有商品库存数据。"
                if (low.isEmpty()) return "已检查 ${pack.goods.size} 个商品，目前没有低库存商品。"
                val names = low.take(5).joinToString("、") { "${it.name}（库存 ${it.stock}）" }
                "有 ${low.size} 个商品需要注意库存：$names。"
            }
            is BusinessInsightKind.Advice -> ""
            is BusinessInsightKind.Period -> {
                val period = insight.period
                val summary = pack.periodSummaries.firstOrNull { it.period == period }
                    ?: return "该时间范围暂无营业额记录。"
                val label = when (period) {
                    BusinessPeriod.TODAY -> "今天"
                    BusinessPeriod.YESTERDAY -> "昨天"
                    BusinessPeriod.LAST_SEVEN_DAYS -> "最近 7 天"
                    BusinessPeriod.THIS_MONTH -> "本月"
                    BusinessPeriod.LAST_MONTH -> "上月"
                    BusinessPeriod.LAST_THREE_MONTHS -> "最近 3 个月"
                    BusinessPeriod.LAST_SIX_MONTHS -> "最近 6 个月"
                    BusinessPeriod.THIS_MONTH_COMPARED_WITH_LAST_MONTH -> "本月与上月"
                    BusinessPeriod.LAST_THREE_MONTHS_COMPARED_WITH_THIS_MONTH -> "本月至今与前 3 个完整自然月"
                }
                val current = "${label}营业额 ${money(summary.amount)}，${if (summary.count > 0) "共 ${summary.count} 笔" else "暂无记录"}。"
                val comparison = summary.comparisonAmount ?: return current
                if (period == BusinessPeriod.THIS_MONTH_COMPARED_WITH_LAST_MONTH) {
                    return current + " 上月营业额 ${money(comparison)}。"
                }
                val months = summary.comparisonMonthCount ?: 0
                val average = summary.comparisonAverageAmount ?: 0.0
                var answer = current + " 前 3 个完整自然月中目前有数据的 $months 个月，合计 ${money(comparison)}，月均 ${money(average)}。"
                if (months < 3) answer += "历史数据不足 3 个月，本次实际比较了 $months 个月。"
                return answer
            }
        }
    }

    private fun money(value: Double): String {
        val rounded = kotlin.math.round(value * 100) / 100.0
        return if (rounded == kotlin.math.floor(rounded)) "¥${rounded.toLong()}"
        else "¥${"%.2f".format(rounded).trimEnd('0')}"
    }
}
