package com.xiaozhanggui.app.domain.voice

import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.Format
import java.util.Locale

/**
 * 语音记录类型。1:1 对应 iOS VoiceRecordType（rawValue 为中文展示名）。
 */
enum class VoiceRecordType(val title: String) {
    TODO("待办"),
    REVENUE("营业记录"),
    EXPENSE("支出"),
    MEMO("记录"),
    EXPIRY("临期退货"),
    CUSTOMER("客户配送"),
}

/**
 * 语音草稿。1:1 对应 iOS VoiceDraft；时间字段以 epoch millis 表示（Date → Long）。
 */
data class VoiceDraft(
    val type: VoiceRecordType,
    val title: String,
    val detail: String,
    val amount: Double?,
    val dueAt: Long?,
    val expiryDays: Int?,
    val customerName: String?,
    val quantity: Int?,
    val goodsName: String?,
    val original: String,
)

/**
 * 中文数字解析。1:1 移植 iOS Utilities/ChineseNumber.swift。
 *
 * 支持阿拉伯数字与"三百二十五"式中文数字。
 */
internal object ChineseNumber {
    private val digits: Map<Char, Int> = mapOf(
        '零' to 0, '一' to 1, '二' to 2, '两' to 2, '三' to 3,
        '四' to 4, '五' to 5, '六' to 6, '七' to 7, '八' to 8, '九' to 9,
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

/**
 * 语音解析器。1:1 移植 iOS Voice/VoiceModel.swift:76-271（`enum VoiceParser`）。
 *
 * 红线：与 QuickRecordParser 完全独立，不得合并或共享分流逻辑。
 * 关键差异：本解析器支持 expense 类型（GATE C #5），QuickRecord 链路没有支出分支。
 */
object VoiceParser {

    private val recordIntentWords = listOf(
        "提醒", "待办", "记一下", "营业额", "收入",
        "支出", "进货", "过期", "临期", "配送", "客户", "送",
    )

    /** 开头可剥离的填充词（1:1 对应 iOS 的 `^(记一下|提醒我|…|送|送到)+`，顺序不可调）。 */
    private val leadingTokensRegex =
        Regex("^(?:记一下|提醒我|今天|明天|后天|上午|下午|晚上|三点|十点|送|送到)+")

    /**
     * 明显是查询而非记录指令的句子，不应默认生成待办。
     * 含"天气"且无记录意图词 → 拒绝。
     */
    fun isUnsupportedQuery(text: String): Boolean {
        val value = text.trim()
        val asksWeather = value.contains("天气")
        val hasRecordIntent = recordIntentWords.any { value.contains(it) }
        return asksWeather && !hasRecordIntent
    }

    fun parse(rawText: String): VoiceDraft {
        val value = rawText.trim()
        val type = detectType(value)
        val amount = parseAmount(value)
        val due = parseDueTime(value)
        val days = parseExpiryDays(value)
        val quantity = parseQuantity(value)
        val customerName = parseCustomerName(value)
        val goodsName = parseGoodsName(value, type)

        val cleaned = leadingTokensRegex.replaceFirst(value, "").trim()

        val title: String
        val detail: String
        when (type) {
            VoiceRecordType.REVENUE -> {
                title = "记录营业收入"
                detail = amount?.let { "¥%.2f".format(Locale.US, it) } ?: "请补充金额"
            }
            VoiceRecordType.EXPENSE -> {
                title = "记录进货支出"
                detail = amount?.let { "¥%.2f".format(Locale.US, it) } ?: "请补充金额"
            }
            VoiceRecordType.EXPIRY -> {
                val before = value.split("还", limit = 2).first()
                val name = before.split("过", limit = 2).first()
                title = name.trim().ifEmpty { "临期商品" }
                detail = days?.let { "还有 $it 天过期" } ?: value
            }
            VoiceRecordType.MEMO -> {
                title = "语音记录"
                detail = value
            }
            VoiceRecordType.CUSTOMER -> {
                title = when {
                    !goodsName.isNullOrEmpty() -> goodsName
                    cleaned.isNotEmpty() -> cleaned
                    else -> value
                }
                val parts = buildList {
                    customerName?.let { add(it) }
                    quantity?.let { add("$it 件") }
                    due?.let { add(Format.monthDayTime(it)) }
                }
                detail = if (parts.isEmpty()) value else parts.joinToString(" · ")
            }
            VoiceRecordType.TODO -> {
                title = cleaned.ifEmpty { value }
                detail = due?.let { Format.monthDayTime(it) } ?: value
            }
        }

        return VoiceDraft(
            type = type,
            title = title,
            detail = detail,
            amount = amount,
            dueAt = due,
            expiryDays = days,
            customerName = customerName,
            quantity = quantity,
            goodsName = goodsName,
            original = value,
        )
    }

    /**
     * 类型分流（1:1 对应 iOS detectType 的优先级）。
     *
     * 进货/支出/花了 → expense；营业额/收入/卖了/收款/入账 → revenue；
     * 过期/临期/到期 → expiry；配送词或"送"+数量/客户名 → customer；
     * 记一下/备忘/客人 → memo；默认 todo。
     *
     * iOS 为 private；此处放宽为 internal 以便单元测试锁定分流规则。
     */
    internal fun detectType(value: String): VoiceRecordType {
        if (value.contains("进货") || value.contains("支出") || value.contains("花了")) {
            return VoiceRecordType.EXPENSE
        }
        if (value.contains("营业额") || value.contains("收入") || value.contains("卖了") ||
            value.contains("收款") || value.contains("入账")
        ) {
            return VoiceRecordType.REVENUE
        }
        if (value.contains("过期") || value.contains("临期") || value.contains("到期")) {
            return VoiceRecordType.EXPIRY
        }
        // 客户配送：含「送」且有数量/客户名，或明确配送词
        val hasDeliveryWord = value.contains("配送") || value.contains("送货") ||
            value.contains("送到") || value.contains("客户")
        val hasSendWithQuantity =
            value.contains("送") && (parseQuantity(value) != null || parseCustomerName(value) != null)
        if (hasDeliveryWord || hasSendWithQuantity) {
            return VoiceRecordType.CUSTOMER
        }
        if (value.contains("记一下") || value.contains("备忘") || value.contains("客人")) {
            return VoiceRecordType.MEMO
        }
        return VoiceRecordType.TODO
    }

    /**
     * 金额：优先阿拉伯数字，其次中文数字。
     * 正则更宽松：`(\d+(?:\.\d+)?)`，无单位要求（1:1 iOS）。
     */
    fun parseAmount(text: String): Double? {
        val cleaned = text.replace(",", "")
        Regex("""(\d+(?:\.\d+)?)""").find(cleaned)?.let {
            return it.groupValues[1].toDoubleOrNull()
        }
        Regex("""[零一二两三四五六七八九十百千万]+""").find(cleaned)?.let { match ->
            ChineseNumber.parse(match.value)?.let { return it.toDouble() }
        }
        return null
    }

    /**
     * 截止时间：今天/明天/后天 + 上午/下午/晚上 X点/中午（1:1 iOS）。
     * 有具体时间 → 当天该时刻；只有日期词 → 当天零点；都没有 → null。
     */
    fun parseDueTime(text: String): Long? {
        val now = System.currentTimeMillis()
        var day = now
        var matchedDay = false
        if (text.contains("今天")) {
            day = now
            matchedDay = true
        }
        if (text.contains("明天")) {
            day = now + 86_400_000L
            matchedDay = true
        }
        if (text.contains("后天")) {
            day = now + 2 * 86_400_000L
            matchedDay = true
        }

        val period = when {
            text.contains("下午") || text.contains("晚上") -> "pm"
            text.contains("上午") -> "am"
            else -> null
        }

        var hour: Int? = Regex("""([0-9]{1,2})点""").find(text)
            ?.groupValues?.get(1)?.toIntOrNull()
        if (hour == null) {
            hour = Regex("""([一二两三四五六七八九十]+)点""").find(text)
                ?.groupValues?.get(1)?.let { ChineseNumber.parse(it) }
        }
        if (hour == null && text.contains("中午")) {
            hour = 12
        }

        if (hour != null) {
            var h = hour
            if (period == "pm" && h < 12) h += 12
            if (period == "am" && h == 12) h = 0
            if (h !in 0..23) return null
            return DateExt.atTime(day, h, 0)
        }

        if (matchedDay) {
            return DateExt.startOfDay(day)
        }
        return null
    }

    /** 临期天数："还有N天" / "N天后"（N 支持中文数字）。 */
    private fun parseExpiryDays(value: String): Int? {
        Regex("""还有([\d一二两三四五六七八九十百千]+)天""").find(value)?.let {
            return ChineseNumber.parse(it.groupValues[1])
        }
        Regex("""([\d一二两三四五六七八九十百千]+)天后""").find(value)?.let {
            return ChineseNumber.parse(it.groupValues[1])
        }
        return null
    }

    /** 数量：N箱/件/瓶/袋/个/份/条/盒，或中文数字（两箱 → 2）。 */
    fun parseQuantity(text: String): Int? {
        Regex("""(\d+)\s*(箱|件|瓶|袋|个|份|条|盒)""").find(text)?.let {
            return it.groupValues[1].toIntOrNull()
        }
        Regex("""([一二两三四五六七八九十]+)\s*(箱|件|瓶|袋|个|份|条|盒)""").find(text)?.let {
            return ChineseNumber.parse(it.groupValues[1])
        }
        return null
    }

    /** 客户名：常见称呼（X姐/X哥/X老板/X总/…）或 XX店/XX别墅/XX房。返回整段匹配。 */
    fun parseCustomerName(text: String): String? {
        Regex("""[\u4e00-\u9fa5]{1,4}(姐|哥|老板|总|姨|叔|婶|女士|先生)""").find(text)?.let {
            return it.value
        }
        Regex("""[\u4e00-\u9fa5A-Za-z0-9]{1,8}(店|别墅|房)""").find(text)?.let {
            return it.value
        }
        return null
    }

    /**
     * 商品名：仅客户配送语境下有效；去掉客户名/时间词/数量词/动词后的剩余。
     * 替换顺序 1:1 iOS（"送货/送到" 先于 "送"，不可调）。
     */
    fun parseGoodsName(text: String, type: VoiceRecordType): String? {
        if (type != VoiceRecordType.CUSTOMER) return null
        var s = text
        for (token in listOf("今天", "明天", "后天", "上午", "下午", "晚上", "配送", "送货", "送到", "送", "客户", "给", "帮")) {
            s = s.replace(token, " ")
        }
        // 去掉数量词
        s = Regex("""\d+\s*(箱|件|瓶|袋|个|份|条|盒)""").replace(s, " ")
        s = Regex("""[一二两三四五六七八九十]+\s*(箱|件|瓶|袋|个|份|条|盒)""").replace(s, " ")
        // 去掉客户名
        parseCustomerName(text)?.let { name ->
            s = s.replace(name, " ")
        }
        return s.trim().ifEmpty { null }
    }
}

/**
 * 语音保存前校验（GATE C #6）。
 *
 * 对应 iOS VoiceViewModel.save() 开头的 guard：金额缺失必须报错，绝不写 0。
 * 纯函数，便于 JVM 单元测试；ViewModel.save() 在写库前调用，返回非空则阻断保存。
 *
 * @return 错误文案（阻断保存），或 null（允许保存）
 */
fun validateVoiceDraft(draft: VoiceDraft): String? = when (draft.type) {
    VoiceRecordType.REVENUE ->
        if (draft.amount == null || draft.amount <= 0) "请补充收入金额" else null
    VoiceRecordType.EXPENSE ->
        if (draft.amount == null || draft.amount <= 0) "请补充支出金额" else null
    else -> null
}
