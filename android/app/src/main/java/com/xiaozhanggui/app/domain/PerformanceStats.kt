package com.xiaozhanggui.app.domain

import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity

/**
 * 业绩派生。对应 iOS PerformanceModel。
 * - 区间：今日 / 本周（近 7 天，today-6 到今日终点）/ 本月（1 日 0 点到下月 1 日 -1 秒）/ 自定义
 * - 趋势：日/周→7 天，按日聚合，label="M/d"；月→30 天
 * - 净额 = 收入 - 支出；上期为 0 时变化百分比为 null
 */
enum class PerformancePeriod { TODAY, WEEK, MONTH, CUSTOM }

data class PerformanceStats(
    val income: Double,
    val expense: Double,
    val net: Double,
    /** 与等长上一区间相比的收入变化百分比；上期为 0 → null */
    val incomeChangePercent: Double?
)

data class TrendPoint(val label: String, val amount: Double)

/** 收入来源占比 */
data class IncomeSourceSummary(
    val store: Double,
    val meituan: Double,
    val other: Double
) {
    val total: Double get() = store + meituan + other
    fun ratio(v: Double): Double = if (total > 0) v / total else 0.0
}

/** 合并收支记录行（按日期倒序） */
data class MoneyRecord(
    val id: String,
    val title: String,
    val amount: Double, // 收入为正，支出为负
    val date: Long,
    val source: String,
    val isIncome: Boolean
)

object PerformanceStats2 {

    /** 区间起止（epoch millis，左闭右开） */
    fun range(
        period: PerformancePeriod,
        customStart: Long = 0L,
        customEnd: Long = 0L,
        nowMillis: Long = System.currentTimeMillis()
    ): Pair<Long, Long> {
        val todayStart = DateExt.startOfDay(nowMillis)
        return when (period) {
            PerformancePeriod.TODAY -> todayStart to todayStart + 24 * 3600 * 1000L
            PerformancePeriod.WEEK -> {
                val start = todayStart - 6 * 24 * 3600 * 1000L
                start to todayStart + 24 * 3600 * 1000L
            }
            PerformancePeriod.MONTH -> {
                val start = DateExt.startOfMonth(nowMillis)
                start to DateExt.startOfNextMonth(nowMillis)
            }
            PerformancePeriod.CUSTOM -> customStart to customEnd
        }
    }

    fun compute(
        period: PerformancePeriod,
        performances: List<PerformanceEntity>,
        expenses: List<ExpenseEntity>,
        customStart: Long = 0L,
        customEnd: Long = 0L,
        nowMillis: Long = System.currentTimeMillis()
    ): PerformanceStats {
        val (start, end) = range(period, customStart, customEnd, nowMillis)
        val income = performances.filter { it.date in start until end }.sumOf { it.amount }
        val expense = expenses.filter { it.date in start until end }.sumOf { it.amount }
        // 上一区间
        val len = end - start
        val prevIncome = performances.filter { it.date in (start - len) until start }.sumOf { it.amount }
        val change = if (prevIncome == 0.0) null
        else (income - prevIncome) / prevIncome * 100
        return PerformanceStats(income, expense, income - expense, change)
    }

    /** 7 天趋势（日/周周期），label="M/d" */
    fun last7Days(
        performances: List<PerformanceEntity>,
        nowMillis: Long = System.currentTimeMillis()
    ): List<TrendPoint> {
        val todayStart = DateExt.startOfDay(nowMillis)
        return (6 downTo 0).map { back ->
            val dayStart = todayStart - back * 24 * 3600 * 1000L
            val dayEnd = dayStart + 24 * 3600 * 1000L
            val sum = performances.filter { it.date in dayStart until dayEnd }.sumOf { it.amount }
            TrendPoint(Format.monthDay(dayStart).replace("月", "/").replace("日", ""), sum)
        }
    }

    /** 30 天趋势（月周期） */
    fun last30Days(
        performances: List<PerformanceEntity>,
        nowMillis: Long = System.currentTimeMillis()
    ): List<TrendPoint> {
        val todayStart = DateExt.startOfDay(nowMillis)
        return (29 downTo 0).map { back ->
            val dayStart = todayStart - back * 24 * 3600 * 1000L
            val dayEnd = dayStart + 24 * 3600 * 1000L
            val sum = performances.filter { it.date in dayStart until dayEnd }.sumOf { it.amount }
            TrendPoint(Format.monthDay(dayStart).replace("月", "/").replace("日", ""), sum)
        }
    }

    /** 收入来源占比（对应 iOS IncomeSourceSummary.compute） */
    fun incomeSourceSummary(performances: List<PerformanceEntity>): IncomeSourceSummary {
        var store = 0.0; var meituan = 0.0; var other = 0.0
        for (p in performances) {
            when (resolveIncomeSource(p)) {
                "门店" -> store += p.amount
                "美团" -> meituan += p.amount
                else -> other += p.amount
            }
        }
        return IncomeSourceSummary(store, meituan, other)
    }

    /**
     * 收入来源派生（对应 iOS IncomeSource.from(performance:)）：
     * ① incomeSource 字段非空且匹配枚举 → 直接用；
     * ② 为空时查 paymentMethod（"美团"/"meituan"→美团；"门店"/"store"→门店）；
     * ③ 仍为空 → from(note:)。
     */
    fun resolveIncomeSource(p: PerformanceEntity): String {
        val field = p.incomeSource.trim()
        if (field == "门店" || field == "美团" || field == "其他") return field
        val pm = p.paymentMethod
        if (pm.contains("美团") || pm.contains("meituan", ignoreCase = true)) return "美团"
        if (pm.contains("门店") || pm.contains("store", ignoreCase = true)) return "门店"
        return com.xiaozhanggui.app.data.db.IncomeSource.fromNote(p.note)
    }

    /** 收支合并按日期倒序（对应 iOS MoneyRecord.merged） */
    fun merged(
        performances: List<PerformanceEntity>,
        expenses: List<ExpenseEntity>
    ): List<MoneyRecord> {
        val list = mutableListOf<MoneyRecord>()
        for (p in performances) {
            list.add(
                MoneyRecord(
                    id = "p-${p.id}",
                    title = DisplayLogic.performanceTitle(p),
                    amount = p.amount,
                    date = p.date,
                    source = DisplayLogic.recordSourceLabel(p),
                    isIncome = true
                )
            )
        }
        for (e in expenses) {
            list.add(
                MoneyRecord(
                    id = "e-${e.id}",
                    title = DisplayLogic.expenseTitle(e),
                    amount = -e.amount,
                    date = e.date,
                    source = e.category,
                    isIncome = false
                )
            )
        }
        return list.sortedByDescending { it.date }
    }
}
