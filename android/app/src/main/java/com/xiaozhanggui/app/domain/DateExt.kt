package com.xiaozhanggui.app.domain

import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * 日期工具。对应 iOS Utilities/DateExt.swift。
 * 所有 epoch millis 均按系统默认时区解释。
 */
object DateExt {
    private val zone: ZoneId get() = ZoneId.systemDefault()

    fun startOfDay(millis: Long): Long =
        ZonedDateTime.ofInstant(Instant.ofEpochMilli(millis), zone)
            .toLocalDate().atStartOfDay(zone).toInstant().toEpochMilli()

    /** 当天 23:59:59（对应 iOS endOfDay） */
    fun endOfDay(millis: Long): Long = startOfDay(millis) + 24 * 3600 * 1000L - 1000L

    fun startOfMonth(millis: Long): Long {
        val zdt = ZonedDateTime.ofInstant(Instant.ofEpochMilli(millis), zone)
        return zdt.toLocalDate().withDayOfMonth(1).atStartOfDay(zone).toInstant().toEpochMilli()
    }

    fun startOfNextMonth(millis: Long): Long {
        val zdt = ZonedDateTime.ofInstant(Instant.ofEpochMilli(millis), zone)
        return zdt.toLocalDate().withDayOfMonth(1).plusMonths(1).atStartOfDay(zone).toInstant().toEpochMilli()
    }

    private fun localDate(millis: Long): LocalDate =
        ZonedDateTime.ofInstant(Instant.ofEpochMilli(millis), zone).toLocalDate()

    fun isToday(millis: Long): Boolean = localDate(millis) == LocalDate.now(zone)
    fun isTomorrow(millis: Long): Boolean = localDate(millis) == LocalDate.now(zone).plusDays(1)
    fun isBeforeToday(millis: Long): Boolean = localDate(millis).isBefore(LocalDate.now(zone))
    fun isSameDay(a: Long, b: Long): Boolean = localDate(a) == localDate(b)

    /** 整天数差（到期日 0 点 - 参考日 0 点），对应 iOS days(from:) */
    fun daysBetween(fromMillis: Long, toMillis: Long): Long {
        val from = localDate(fromMillis)
        val to = localDate(toMillis)
        return java.time.temporal.ChronoUnit.DAYS.between(from, to)
    }

    /** 时间段：上午 0-12 / 下午 12-18 / 晚上 18-24（对应 iOS dayPeriod） */
    fun dayPeriod(millis: Long): String {
        val hour = ZonedDateTime.ofInstant(Instant.ofEpochMilli(millis), zone).hour
        return when (hour) {
            in 0..11 -> "上午"
            in 12..17 -> "下午"
            else -> "晚上"
        }
    }

    /** 是否有钟点（非当天 00:00），对应 iOS ScheduleAgenda.hasClock */
    fun hasClock(millis: Long): Boolean {
        val t = LocalTime.from(ZonedDateTime.ofInstant(Instant.ofEpochMilli(millis), zone))
        return t != LocalTime.MIDNIGHT
    }

    fun atTime(dayMillis: Long, hour: Int, minute: Int): Long =
        localDate(dayMillis).atTime(hour, minute).atZone(zone).toInstant().toEpochMilli()
}
