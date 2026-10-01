package com.xiaozhanggui.app.domain

import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * 格式化。对应 iOS Utilities/Format.swift。
 */
object Format {
    private val zone: ZoneId get() = ZoneId.systemDefault()
    private val zh: Locale = Locale.CHINA

    private fun moneyFormat(): DecimalFormat {
        val symbols = DecimalFormatSymbols(zh)
        return DecimalFormat("¥#,##0.00", symbols)
    }

    private fun intFormat(): DecimalFormat {
        val symbols = DecimalFormatSymbols(zh)
        return DecimalFormat("#,##0", symbols)
    }

    /** ¥1,234.00（千分位 + 2 位小数） */
    fun money(v: Double): String = moneyFormat().format(v)

    /** 11,500（Hero 大数字） */
    fun groupedInt(v: Double): String = intFormat().format(v)

    /** 整数用 groupedInt，否则 money */
    fun groupedAmount(v: Double): String =
        if (v == kotlin.math.floor(v) && !v.isInfinite()) groupedInt(v) else money(v)

    private fun zdt(millis: Long): ZonedDateTime =
        ZonedDateTime.ofInstant(Instant.ofEpochMilli(millis), zone)

    /** 2026年10月2日 */
    fun formatDate(millis: Long): String =
        DateTimeFormatter.ofPattern("yyyy年M月d日", zh).format(zdt(millis))

    /** HH:mm */
    fun time(millis: Long): String =
        DateTimeFormatter.ofPattern("HH:mm", zh).format(zdt(millis))

    /** 年月日时分 */
    fun dateTime(millis: Long): String =
        DateTimeFormatter.ofPattern("yyyy年M月d日 HH:mm", zh).format(zdt(millis))

    /** X月X日 HH:mm（待办截止） */
    fun monthDayTime(millis: Long): String =
        DateTimeFormatter.ofPattern("M月d日 HH:mm", zh).format(zdt(millis))

    /** X月X日（全天） */
    fun monthDay(millis: Long): String =
        DateTimeFormatter.ofPattern("M月d日", zh).format(zdt(millis))

    /** MM月dd日 HH:mm（备忘卡片） */
    fun memoTime(millis: Long): String =
        DateTimeFormatter.ofPattern("MM月dd日 HH:mm", zh).format(zdt(millis))

    /** MM-dd HH:mm（客户需求行） */
    fun shortDateTime(millis: Long): String =
        DateTimeFormatter.ofPattern("MM-dd HH:mm", zh).format(zdt(millis))

    /** 2026年10月02日 */
    fun yyyyMMdd(millis: Long): String =
        DateTimeFormatter.ofPattern("yyyy年MM月dd日", zh).format(zdt(millis))
}
