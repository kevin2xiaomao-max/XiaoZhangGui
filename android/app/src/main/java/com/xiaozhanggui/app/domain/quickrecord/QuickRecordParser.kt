package com.xiaozhanggui.app.domain.quickrecord

import com.xiaozhanggui.app.domain.Format
import java.time.DateTimeException
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.temporal.TemporalAdjusters

/**
 * 快速记一笔自然语言解析器。
 *
 * 1:1 对应 iOS `XiaoZhangGui/Features/QuickRecord/QuickRecordParser.swift`
 *（LocalQuickRecordParser / AmountPhraseParser / QuantityPhraseParser /
 * DatePhraseParser，含 AI 专用 `resolve()`；中文数字对应
 * `XiaoZhangGui/Utilities/ChineseNumber.swift`）。
 *
 * 红线：
 * - 与 VoiceParser（语音页解析器）完全独立，不得合并。两套规则不同，
 *   此处无 expense 类型（GATE C #5）。
 * - 纯 Kotlin，无 Android 依赖，可被单元测试直接调用；日期以 epoch millis
 *   传递，按系统默认时区解释（与 domain.Format / domain.DateExt 一致）。
 * - 保存闸门见 [canSaveQuickRecord]：trim 非空即保存，识别不了的句子由
 *   parser 兜底为备忘，保证每一句话都不丢。
 */
enum class QuickRecordKind {
    PERFORMANCE,
    TODO,
    CUSTOMER,
    EXPIRY,
    MEMO,
}

/** 解析草稿。对应 iOS QuickRecordDraft；date 为 epoch millis（null = 未识别到时间）。 */
data class QuickRecordDraft(
    val kind: QuickRecordKind,
    val title: String,
    val amount: Double?,
    val date: Long?,
    val quantity: Int?,
    val customer: String?,
    val note: String,
    val raw: String,
) {
    /** 对应 iOS QuickRecordDraft.summary。 */
    val summary: String
        get() = when (kind) {
            QuickRecordKind.PERFORMANCE -> "记入业绩 ${Format.money(amount ?: 0.0)}"
            QuickRecordKind.TODO -> date?.let { "待办 · ${Format.monthDayTime(it)}" } ?: "待办"
            QuickRecordKind.CUSTOMER -> "客户配送 · ${customer ?: title}"
            QuickRecordKind.EXPIRY -> "临时商品 · $title"
            QuickRecordKind.MEMO -> "备忘"
        }
}

/**
 * 保存闸门：唯一条件是「trim 后非空」。对应 iOS QuickRecordSavePolicy。
 * 类型识别结果不参与能否保存的判断。
 */
fun canSaveQuickRecord(rawText: String): Boolean = rawText.trim().isNotEmpty()

/** 本地规则解析。对应 iOS LocalQuickRecordParser。 */
object LocalQuickRecordParser {

    fun parse(text: String, nowMillis: Long = System.currentTimeMillis()): QuickRecordDraft {
        val trimmed = text.trim()
        val date = DatePhraseParser.parse(trimmed, nowMillis)
        val amount = AmountPhraseParser.parse(trimmed)
        val quantity = QuantityPhraseParser.parse(trimmed)

        // V3.3 真机 hotfix 定稿的分流顺序：
        // 1) 营业额 → 2) 显式备忘 → 3) 待办 → 4) 配送 → 5) 临期 → 6) 备忘兜底。
        // 任何规则都识别不了的非空句子一律落「备忘」，保证用户的每一句话都能保存。
        if (isPerformance(trimmed, amount)) {
            return QuickRecordDraft(
                kind = QuickRecordKind.PERFORMANCE,
                title = "营业额",
                amount = amount,
                date = date ?: nowMillis,
                quantity = null,
                customer = null,
                note = trimmed,
                raw = trimmed,
            )
        }
        if (isExplicitMemo(trimmed)) {
            return QuickRecordDraft(
                kind = QuickRecordKind.MEMO,
                title = trimmed.take(20),
                amount = null,
                date = date,
                quantity = null,
                customer = null,
                note = trimmed,
                raw = trimmed,
            )
        }
        if (isTodo(trimmed)) {
            return QuickRecordDraft(
                kind = QuickRecordKind.TODO,
                title = trimmed,
                amount = null,
                date = date,
                quantity = null,
                customer = null,
                note = trimmed,
                raw = trimmed,
            )
        }
        if (isCustomer(trimmed)) {
            return QuickRecordDraft(
                kind = QuickRecordKind.CUSTOMER,
                title = trimmed,
                amount = null,
                date = date,
                quantity = null,
                customer = customerName(trimmed) ?: "客户",
                note = trimmed,
                raw = trimmed,
            )
        }
        if (isExpiry(trimmed)) {
            val zone = ZoneId.systemDefault()
            val fallback = ZonedDateTime.ofInstant(Instant.ofEpochMilli(nowMillis), zone)
                .plusDays(1).toInstant().toEpochMilli()
            return QuickRecordDraft(
                kind = QuickRecordKind.EXPIRY,
                title = expiryName(trimmed),
                amount = null,
                date = date ?: fallback,
                quantity = quantity ?: 1,
                customer = null,
                note = trimmed,
                raw = trimmed,
            )
        }
        // 兜底：非空但无法识别（如「卡卡卡」「供应商周五过来」）→ 备忘
        return QuickRecordDraft(
            kind = QuickRecordKind.MEMO,
            title = trimmed.take(20),
            amount = null,
            date = date,
            quantity = null,
            customer = null,
            note = trimmed,
            raw = trimmed,
        )
    }

    private fun isPerformance(text: String, amount: Double?): Boolean =
        amount != null && revenueSignals.any { text.contains(it) }

    /**
     * 金额 +（营收词 / 收款渠道词）即判定营业额，覆盖「今天美团680」这类口语。
     * 对应 iOS revenueSignals。
     */
    private val revenueSignals = listOf(
        "营业额", "营收", "收入", "卖了", "收款", "入账", "进账",
        "美团", "饿了么", "抖音", "团购", "外卖", "收钱吧",
    )

    /**
     * 明确的动作 / 待办信号（不含「送」：配送在下一步单独识别）。
     * 对应 iOS todoSignals（逐字复制，含「进」等短词——「进货花了500」命中此表判待办，
     * QuickRecord 链路无 expense 类型，GATE C #5）。
     */
    private val todoSignals = listOf(
        "联系", "打电话", "回电", "通话",
        "买", "进货", "进", "拿货", "提货", "订货", "下单", "补货", "上架",
        "整理", "打扫", "清理", "盘点", "对账", "核对", "清点",
        "催", "取货", "取件", "寄", "发货", "送修", "维修", "修一下",
        "预约", "安装", "搬", "交费", "交班", "带", "办理",
        "准备", "安排", "检查", "打印", "复印", "报名", "提醒",
    )

    private fun isTodo(text: String): Boolean = todoSignals.any { text.contains(it) }

    private fun isExplicitMemo(text: String): Boolean =
        listOf("记一下", "记个备忘", "备忘", "记下来").any { text.contains(it) }

    private fun isCustomer(text: String): Boolean {
        if (listOf("配送", "送货", "送到", "客户").any { text.contains(it) }) return true
        // 「给302送…」「给张老板送…」这类房号 / 人称配送口语
        return Regex("""给[^，。；\s]{0,12}送""").containsMatchIn(text)
    }

    private fun isExpiry(text: String): Boolean =
        listOf("退货", "临期", "过期", "到期").any { text.contains(it) }

    private fun customerName(text: String): String? {
        var cleaned = text
        for (token in listOf("今天", "明天", "后天", "月底")) {
            cleaned = cleaned.replace(token, "")
        }
        // 优先：给302送… / 给张老板送…
        Regex("""给\s*([^\s，。；]{1,12}?)\s*送""").find(cleaned)?.let {
            return it.groupValues[1]
        }
        // 其次：张老板 / 302房 / 别墅 / 店
        Regex("""([一-龥A-Za-z0-9]{1,8})(老板|别墅|房|店)""").find(cleaned)?.let {
            return it.value
        }
        return null
    }

    private fun expiryName(text: String): String {
        val stripped = text
            .replace("退货", "")
            .replace("临期", "")
            .replace("月底", "")
            .replace("明天", "")
            .replace("后天", "")
            .trim()
        return stripped.ifEmpty { "临时商品" }
    }
}

/** 金额提取。对应 iOS AmountPhraseParser。 */
object AmountPhraseParser {
    private val arabic = Regex("""(\d+(?:\.\d+)?)(?:元|块|块钱)?""")
    private val chinese = Regex("[一二三四五六七八九十百千万两零]+")

    /**
     * ①阿拉伯数字优先（`(\d+(?:\.\d+)?)(?:元|块|块钱)?` 取首个 > 0），②中文数字其次。
     * 注意与 iOS 相同的「数字误伤」行为：纯数字无单位也能提取（如「明天下午3点…」会先
     * 命中 3），分流时仅营业额分支消费 amount，其余分支不受影响。
     */
    fun parse(text: String): Double? {
        arabic.find(text)?.let {
            val value = it.groupValues[1].toDoubleOrNull()
            if (value != null && value > 0) return value
        }
        chinese.find(text)?.value?.let {
            val value = ChineseNumber.parse(it)
            if (value != null && value > 0) return value.toDouble()
        }
        return null
    }
}

/** 数量提取。对应 iOS QuantityPhraseParser（只有「两箱」特殊处理，无三箱等通用中文数字）。 */
object QuantityPhraseParser {
    private val pattern = Regex("""(\d+)\s*(箱|件|瓶|袋|个|份)""")

    fun parse(text: String): Int? {
        pattern.find(text)?.let { return it.groupValues[1].toIntOrNull() }
        if (text.contains("两箱")) return 2
        return null
    }
}

/** 日期 / 时间提取。对应 iOS DatePhraseParser（含 AI 专用 resolve）。 */
object DatePhraseParser {

    /**
     * 今天 / 明天 / 后天 / 月底（月末日 00:00）/ 周X / N月N日，再叠加时间。
     * 返回 epoch millis；无任何时间词返回 null。
     *
     * 与 iOS 一致的细节：
     * - 「今天/明天/后天」保留 now 的时分（明天 = now + 1 天）；「月底」「周X」
     *   「N月N日」落在当天 00:00。
     * - 周X：firstWeekday = 周日，同周 → +7 天（周五说「周五」= 下周五）。
     * - N月N日：非法日期（2月30日）拒绝；已过去的日期跨年回退到次年。
     * - 多个日期词同时出现时靠后的覆盖靠前的（与 iOS 的连续 if 赋值一致）。
     */
    fun parse(text: String, nowMillis: Long = System.currentTimeMillis()): Long? {
        val zone = ZoneId.systemDefault()
        val now = ZonedDateTime.ofInstant(Instant.ofEpochMilli(nowMillis), zone)
        var date = now
        var matched = false

        if (text.contains("今天")) { date = now; matched = true }
        if (text.contains("明天")) { date = now.plusDays(1); matched = true }
        if (text.contains("后天")) { date = now.plusDays(2); matched = true }
        if (text.contains("月底")) {
            date = now.toLocalDate().with(TemporalAdjusters.lastDayOfMonth()).atStartOfDay(zone)
            matched = true
        }
        weekdayOffset(text, now)?.let { date = it; matched = true }
        monthDay(text, now)?.let { date = it; matched = true }
        parseTime(text, date)?.let { date = it; matched = true }
        return if (matched) date.toInstant().toEpochMilli() else null
    }

    private fun monthDay(text: String, now: ZonedDateTime): ZonedDateTime? {
        val zone = now.zone
        val m = Regex("""(\d{1,2})月(\d{1,2})日""").find(text) ?: return null
        val month = m.groupValues[1].toIntOrNull() ?: return null
        val day = m.groupValues[2].toIntOrNull() ?: return null
        if (month !in 1..12 || day !in 1..31) return null
        val today = now.toLocalDate()
        fun candidate(year: Int): ZonedDateTime? = try {
            // LocalDate.of 对非法日期（2月30日）直接抛异常，等价于 iOS 的
            // month/day 回绕校验（candidate.month != month 即拒绝）。
            LocalDate.of(year, month, day).atStartOfDay(zone)
        } catch (e: DateTimeException) {
            null
        }
        val cand = candidate(today.year) ?: return null
        // 跨年回退：当年已过去的日期顺延到次年（iOS：candidate < startOfDay(now) → +1 年）
        return if (cand.toLocalDate().isBefore(today)) candidate(today.year + 1) else cand
    }

    private fun weekdayOffset(text: String, now: ZonedDateTime): ZonedDateTime? {
        val zone = now.zone
        val map = listOf(
            "周一" to 2, "星期一" to 2,
            "周二" to 3, "星期二" to 3,
            "周三" to 4, "星期三" to 4,
            "周四" to 5, "星期四" to 5,
            "周五" to 6, "星期五" to 6,
            "周六" to 7, "星期六" to 7,
            "周日" to 1, "周天" to 1, "星期日" to 1,
        )
        val pair = map.firstOrNull { text.contains(it.first) } ?: return null
        // iOS firstWeekday = 周日：周日=1 … 周六=7；java.time 周一=1 … 周日=7，做换算。
        val current = now.dayOfWeek.value % 7 + 1
        var delta = pair.second - current
        if (delta < 0) delta += 7
        if (delta == 0) delta = 7
        return now.toLocalDate().atStartOfDay(zone).plusDays(delta.toLong())
    }

    /**
     * `(上午|下午|晚上)?\s*(\d{1,2})(?:点|:|：)(\d{1,2})?`；
     * 下午/晚上 < 12 则 +12；上午 12 点 → 0。
     * iOS `Calendar.date(from:)` 对超范围分量返回 nil，此处等价处理为「无时间」。
     */
    private fun parseTime(text: String, on: ZonedDateTime): ZonedDateTime? {
        val m = Regex("""(上午|下午|晚上)?\s*(\d{1,2})(?:点|:|：)(\d{1,2})?""").find(text)
            ?: return null
        val period = m.groupValues[1]
        var hour = m.groupValues[2].toIntOrNull() ?: return null
        val minute = m.groups[3]?.value?.toIntOrNull() ?: 0
        if (hour !in 0..23 || minute !in 0..59) return null
        if ((period.contains("下午") || period.contains("晚上")) && hour < 12) hour += 12
        if (period.contains("上午") && hour == 12) hour = 0
        return on.toLocalDate().atTime(hour, minute).atZone(on.zone)
    }

    // MARK: - AI 对话专用：带「歧义时段」判定的解析（V3.3 P0-3，纯新增，不改变 parse 的既有行为）

    /** resolve 的结果：要么是确定时间，要么是需要向用户澄清的裸「N点」。 */
    sealed interface Resolution {
        /** 成功解析到确定时间（epoch millis）。 */
        data class Date(val millis: Long) : Resolution

        /**
         * 出现「N点」但没有上午 / 下午 / 晚上等限定词，无法确定凌晨还是下午。
         * 关联值为命中的时间原文（如「3点」）。调用方必须追问澄清，禁止回落当前时间。
         */
        data class AmbiguousClock(val token: String) : Resolution
    }

    /**
     * 与 parse 共用同一套日期规则，但区分三种情况：
     * - 「明天下午3点」→ 明天 15:00；「明天上午3点」→ 明天 03:00；
     * - 「明天3点」→ [Resolution.AmbiguousClock]("3点")；
     * - 只有日期（如「明天进货」）→ [Resolution.Date](明天)；无任何时间词 → null。
     * QuickRecord 链路继续使用 parse，本方法为 AI 链路纯新增。
     *
     * 注意：与 iOS 实现一致，resolve 不处理「N月N日」（parse 才有）。
     */
    fun resolve(text: String, nowMillis: Long = System.currentTimeMillis()): Resolution? {
        val zone = ZoneId.systemDefault()
        val now = ZonedDateTime.ofInstant(Instant.ofEpochMilli(nowMillis), zone)
        var base = now
        var dayMatched = false

        if (text.contains("今天")) { base = now; dayMatched = true }
        if (text.contains("明天")) { base = now.plusDays(1); dayMatched = true }
        if (text.contains("后天")) { base = now.plusDays(2); dayMatched = true }
        if (text.contains("月底")) {
            base = now.toLocalDate().with(TemporalAdjusters.lastDayOfMonth()).atStartOfDay(zone)
            dayMatched = true
        }
        weekdayOffset(text, now)?.let { base = it; dayMatched = true }

        val clock = clockMatch(text)
            ?: return if (dayMatched) Resolution.Date(base.toInstant().toEpochMilli()) else null
        if (clock.ambiguous) return Resolution.AmbiguousClock(clock.token)

        val resolved = base.toLocalDate().atTime(clock.hour, clock.minute).atZone(zone)
        return Resolution.Date(resolved.toInstant().toEpochMilli())
    }

    private data class Clock(
        val token: String,
        val hour: Int,
        val minute: Int,
        val ambiguous: Boolean,
    )

    private fun clockMatch(text: String): Clock? {
        val m = Regex(
            """(凌晨|早上|早晨|上午|中午|下午|傍晚|晚上|晚间)?\s*(\d{1,2})(?:点|:|：)\s*(\d{1,2})?\s*分?"""
        ).find(text) ?: return null
        val period = m.groupValues[1]
        val hour = m.groupValues[2].toIntOrNull() ?: return null
        val minute = m.groups[3]?.value?.toIntOrNull() ?: 0
        if (hour !in 0..23 || minute !in 0..59) return null

        // 无任何时段限定：1~11 点无法区分凌晨 / 下午（如「3点」），必须澄清；
        // 12 点约定为中午、13 点及以上本身就是 24 小时制，无需澄清。
        val ambiguous = period.isEmpty() && hour in 1..11

        var resolvedHour = hour
        if ((period.contains("下午") || period.contains("傍晚") ||
                    period.contains("晚上") || period.contains("晚间") ||
                    period.contains("中午")) && hour < 12
        ) {
            resolvedHour = hour + 12
        }
        if ((period.contains("上午") || period.contains("凌晨")) && hour == 12) {
            resolvedHour = 0
        }
        return Clock(
            token = m.value,
            hour = resolvedHour,
            minute = minute,
            ambiguous = ambiguous,
        )
    }
}

/**
 * 中文数字解析。1:1 对应 iOS `XiaoZhangGui/Utilities/ChineseNumber.swift`。
 * 支持阿拉伯数字与「三百二十五」式中文数字。
 */
internal object ChineseNumber {
    private val digits = mapOf(
        '零' to 0, '一' to 1, '二' to 2, '两' to 2, '三' to 3, '四' to 4,
        '五' to 5, '六' to 6, '七' to 7, '八' to 8, '九' to 9,
    )

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
