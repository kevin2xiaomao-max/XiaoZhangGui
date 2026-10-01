package com.xiaozhanggui.app.domain.ai

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * 自然语言经营周期解析。对应 iOS `AI/Context/BusinessPeriodParser.swift`。
 *
 * 先去空格再按顺序匹配；顺序敏感：对比类 > 半年 > 3个月 > 上月 > 本月 > 7天 > 昨天 > 今天；
 * 无命中返回 null。
 */
enum class BusinessPeriod {
    TODAY,
    YESTERDAY,
    LAST_SEVEN_DAYS,
    THIS_MONTH,
    LAST_MONTH,
    LAST_THREE_MONTHS,
    LAST_SIX_MONTHS,
    THIS_MONTH_COMPARED_WITH_LAST_MONTH,
    LAST_THREE_MONTHS_COMPARED_WITH_THIS_MONTH
}

class BusinessPeriodParser {
    fun parse(text: String): BusinessPeriod? {
        val t = text.replace(" ", "")
        if ((t.contains("三个月") || t.contains("3个月")) &&
            (t.contains("这个月") || t.contains("本月")) && t.contains("对比")
        ) return BusinessPeriod.LAST_THREE_MONTHS_COMPARED_WITH_THIS_MONTH
        if ((t.contains("这个月") || t.contains("本月")) &&
            (t.contains("上个月") || t.contains("上月")) && t.contains("对比")
        ) return BusinessPeriod.THIS_MONTH_COMPARED_WITH_LAST_MONTH
        if (t.contains("最近6个月") || t.contains("近6个月") || t.contains("近半年"))
            return BusinessPeriod.LAST_SIX_MONTHS
        if (t.contains("最近3个月") || t.contains("近三个月") || t.contains("三个月"))
            return BusinessPeriod.LAST_THREE_MONTHS
        if (t.contains("上个月") || t.contains("上月")) return BusinessPeriod.LAST_MONTH
        if (t.contains("这个月") || t.contains("本月")) return BusinessPeriod.THIS_MONTH
        if (t.contains("最近7天") || t.contains("最近七天") || t.contains("最近一周") ||
            t.contains("近一周") || t.contains("过去一周") || t.contains("这一周") || t.contains("本周")
        ) return BusinessPeriod.LAST_SEVEN_DAYS
        if (t.contains("昨天")) return BusinessPeriod.YESTERDAY
        if (t.contains("今天")) return BusinessPeriod.TODAY
        return null
    }

    /**
     * 周期边界（startInclusive → endExclusive，epoch millis）。
     * lastThreeMonths / lastThreeMonthsComparedWithThisMonth 取「今天往前推 3 个月到今天」
     * 的滚动窗口（非自然月对齐），与 iOS bounds 一致。
     */
    fun bounds(
        period: BusinessPeriod,
        now: Long = System.currentTimeMillis()
    ): Pair<Long, Long> {
        val zone = ZoneId.systemDefault()
        val today: LocalDate = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
        val todayStart = today.atStartOfDay(zone).toInstant().toEpochMilli()
        fun atStart(d: LocalDate): Long = d.atStartOfDay(zone).toInstant().toEpochMilli()

        return when (period) {
            BusinessPeriod.TODAY ->
                todayStart to atStart(today.plusDays(1))
            BusinessPeriod.YESTERDAY ->
                atStart(today.minusDays(1)) to todayStart
            BusinessPeriod.LAST_SEVEN_DAYS ->
                // 今起倒推 6 天，共 7 天含今天
                atStart(today.minusDays(6)) to atStart(today.plusDays(1))
            BusinessPeriod.THIS_MONTH, BusinessPeriod.THIS_MONTH_COMPARED_WITH_LAST_MONTH -> {
                val start = today.withDayOfMonth(1)
                atStart(start) to atStart(start.plusMonths(1))
            }
            BusinessPeriod.LAST_MONTH -> {
                val start = today.withDayOfMonth(1).minusMonths(1)
                atStart(start) to atStart(start.plusMonths(1))
            }
            BusinessPeriod.LAST_THREE_MONTHS,
            BusinessPeriod.LAST_THREE_MONTHS_COMPARED_WITH_THIS_MONTH ->
                atStart(today.minusMonths(3)) to todayStart
            BusinessPeriod.LAST_SIX_MONTHS ->
                atStart(today.minusMonths(6)) to todayStart
        }
    }
}
