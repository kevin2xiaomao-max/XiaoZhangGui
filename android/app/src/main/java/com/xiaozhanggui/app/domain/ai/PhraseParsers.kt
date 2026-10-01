package com.xiaozhanggui.app.domain.ai

import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * 中文短语解析器。对应 iOS：
 * - `Utilities/ChineseNumber.swift`（ChineseNumber）
 * - `Features/QuickRecord/QuickRecordParser.swift` 的 AmountPhraseParser / DatePhraseParser（含 AI 专用 resolve / ambiguousClock）
 *
 * 全部为 0-Token 本地规则；日期一律 epoch millis（系统默认时区解释，对应 iOS Calendar.current）。
 */
object ChineseNumber {
    private val digits: Map<Char, Int> = mapOf(
        '零' to 0, '一' to 1, '二' to 2, '两' to 2, '三' to 3, '四' to 4,
        '五' to 5, '六' to 6, '七' to 7, '八' to 8, '九' to 9
    )

    /** 支持阿拉伯数字与"三百二十五"式中文数字 */
    fun parse(value: String): Int? {
        value.toIntOrNull()?.let { return it }
        var total = 0
        var section = 0
        var digit = 0
        for (ch in value) {
            when (ch) {
                '十', '百', '千' -> {
                    val unit = if (ch == '十') 10 else if (ch == '百') 100 else 1000
                    section += (if (digit == 0) 1 else digit) * unit
                    digit = 0
                }
                '万' -> {
                    total += (section + digit) * 10000
                    section = 0
                    digit = 0
                }
                else -> digit = digits[ch] ?: digit
            }
        }
        return total + section + digit
    }
}

object AmountPhraseParser {
    private val arabicRegex = Regex("""(\d+(?:\.\d+)?)(?:元|块|块钱)?""")
    private val chineseRegex = Regex("""[一二三四五六七八九十百千万两零]+""")

    fun parse(text: String): Double? {
        arabicRegex.find(text)?.let { match ->
            match.groupValues[1].toDoubleOrNull()?.takeIf { it > 0 }?.let { return it }
        }
        chineseRegex.find(text)?.let { match ->
            ChineseNumber.parse(match.value)?.takeIf { it > 0 }?.let { return it.toDouble() }
        }
        return null
    }
}

/** resolve 的结果：要么是确定时间，要么是需要向用户澄清的裸「N点」。 */
sealed class TimeResolution {
    /** 成功解析到确定时间（epoch millis） */
    data class Date(val millis: Long) : TimeResolution()
    /**
     * 出现「N点」但没有上午 / 下午 / 晚上等限定词，无法确定凌晨还是下午。
     * 关联值为命中的时间原文（如「3点」）。调用方必须追问澄清，禁止回落当前时间。
     */
    data class AmbiguousClock(val token: String) : TimeResolution()
}

object DatePhraseParser {
    private val zone: ZoneId get() = ZoneId.systemDefault()
    private const val DAY_MILLIS = 24L * 3600 * 1000

    private fun startOfDay(millis: Long): Long =
        Instant.ofEpochMilli(millis).atZone(zone).toLocalDate()
            .atStartOfDay(zone).toInstant().toEpochMilli()

    private fun localDate(millis: Long): LocalDate =
        Instant.ofEpochMilli(millis).atZone(zone).toLocalDate()

    fun parse(text: String, now: Long = System.currentTimeMillis()): Long? {
        var date = now
        var matched = false

        if (text.contains("今天")) { date = now; matched = true }
        if (text.contains("明天")) { date = now + DAY_MILLIS; matched = true }
        if (text.contains("后天")) { date = now + 2 * DAY_MILLIS; matched = true }
        if (text.contains("月底")) {
            date = localDate(now).withDayOfMonth(localDate(now).lengthOfMonth())
                .atStartOfDay(zone).toInstant().toEpochMilli()
            matched = true
        }
        weekdayOffset(text, now)?.let { date = it; matched = true }
        monthDay(text, now)?.let { date = it; matched = true }
        parseTime(text, date)?.let { date = it; matched = true }
        return if (matched) date else null
    }

    private fun monthDay(text: String, now: Long): Long? {
        val match = Regex("""(\d{1,2})月(\d{1,2})日""").find(text) ?: return null
        val month = match.groupValues[1].toIntOrNull() ?: return null
        val day = match.groupValues[2].toIntOrNull() ?: return null
        if (month !in 1..12 || day !in 1..31) return null
        val today = localDate(now)
        fun candidate(year: Int): LocalDate? = runCatching {
            val c = LocalDate.of(year, month, day)
            if (c.monthValue == month && c.dayOfMonth == day) c else null
        }.getOrNull()
        val thisYear = candidate(today.year) ?: return null
        // 跨年回退：已过去则取次年（对应 iOS monthDay）
        val picked = if (thisYear.isBefore(today)) {
            candidate(today.year + 1) ?: return null
        } else thisYear
        return picked.atStartOfDay(zone).toInstant().toEpochMilli()
    }

    /**
     * 周X 偏移：firstWeekday=周日（对齐 iOS weekdayOffset）；
     * 同周 → +7 天（即"周五"在周五说 = 下周五）。
     */
    private fun weekdayOffset(text: String, now: Long): Long? {
        val map = listOf(
            "周一" to DayOfWeek.MONDAY, "星期一" to DayOfWeek.MONDAY,
            "周二" to DayOfWeek.TUESDAY, "星期二" to DayOfWeek.TUESDAY,
            "周三" to DayOfWeek.WEDNESDAY, "星期三" to DayOfWeek.WEDNESDAY,
            "周四" to DayOfWeek.THURSDAY, "星期四" to DayOfWeek.THURSDAY,
            "周五" to DayOfWeek.FRIDAY, "星期五" to DayOfWeek.FRIDAY,
            "周六" to DayOfWeek.SATURDAY, "星期六" to DayOfWeek.SATURDAY,
            "周日" to DayOfWeek.SUNDAY, "周天" to DayOfWeek.SUNDAY, "星期日" to DayOfWeek.SUNDAY
        )
        val target = map.firstOrNull { text.contains(it.first) }?.second ?: return null
        val current = localDate(now).dayOfWeek
        var delta = target.value - current.value
        if (delta < 0) delta += 7
        if (delta == 0) delta = 7
        return startOfDay(now) + delta * DAY_MILLIS
    }

    private fun parseTime(text: String, date: Long): Long? {
        val match = Regex("""(上午|下午|晚上)?\s*(\d{1,2})(?:点|:|：)(\d{1,2})?""").find(text)
            ?: return null
        val period = match.groupValues[1]
        var hour = match.groupValues[2].toIntOrNull() ?: return null
        val minute = match.groupValues[3].toIntOrNull() ?: 0
        if ((period.contains("下午") || period.contains("晚上")) && hour < 12) hour += 12
        if (period.contains("上午") && hour == 12) hour = 0
        val day = localDate(date)
        return day.atTime(hour, minute).atZone(zone).toInstant().toEpochMilli()
    }

    // MARK: - AI 对话专用：带「歧义时段」判定的解析（对应 iOS resolve）

    /**
     * 与 parse 共用同一套日期规则，但区分三种情况：
     * - 「明天下午3点」→ 明天 15:00；「明天上午3点」→ 明天 03:00；
     * - 「明天3点」→ AmbiguousClock("3点")；
     * - 只有日期（如「明天进货」）→ Date(明天，保持当前时刻)；无任何时间词 → null。
     */
    fun resolve(text: String, now: Long = System.currentTimeMillis()): TimeResolution? {
        var base = now
        var dayMatched = false

        if (text.contains("今天")) { base = now; dayMatched = true }
        if (text.contains("明天")) { base = now + DAY_MILLIS; dayMatched = true }
        if (text.contains("后天")) { base = now + 2 * DAY_MILLIS; dayMatched = true }
        if (text.contains("月底")) {
            base = localDate(now).withDayOfMonth(localDate(now).lengthOfMonth())
                .atStartOfDay(zone).toInstant().toEpochMilli()
            dayMatched = true
        }
        weekdayOffset(text, now)?.let { base = it; dayMatched = true }

        val clock = clockMatch(text) ?: return if (dayMatched) TimeResolution.Date(base) else null
        if (clock.ambiguous) return TimeResolution.AmbiguousClock(clock.token)

        val day = localDate(base)
        return TimeResolution.Date(
            day.atTime(clock.hour, clock.minute).atZone(zone).toInstant().toEpochMilli()
        )
    }

    private data class Clock(val token: String, val hour: Int, val minute: Int, val ambiguous: Boolean)

    private fun clockMatch(text: String): Clock? {
        val match = Regex(
            """(凌晨|早上|早晨|上午|中午|下午|傍晚|晚上|晚间)?\s*(\d{1,2})(?:点|:|：)\s*(\d{1,2})?\s*分?"""
        ).find(text) ?: return null
        val period = match.groupValues[1]
        val hour = match.groupValues[2].toIntOrNull() ?: return null
        val minute = match.groupValues[3].toIntOrNull() ?: 0
        if (hour !in 0..23) return null

        // 无任何时段限定：1~11 点无法区分凌晨 / 下午（如「3点」），必须澄清；
        // 12 点约定为中午、13 点及以上本身就是 24 小时制，无需澄清。
        val ambiguous = period.isEmpty() && hour in 1..11

        var resolvedHour = hour
        if ((period.contains("下午") || period.contains("傍晚") || period.contains("晚上") ||
                period.contains("晚间") || period.contains("中午")) && hour < 12) {
            resolvedHour = hour + 12
        }
        if ((period.contains("上午") || period.contains("凌晨")) && hour == 12) {
            resolvedHour = 0
        }
        return Clock(token = match.value, hour = resolvedHour, minute = minute, ambiguous = ambiguous)
    }
}
