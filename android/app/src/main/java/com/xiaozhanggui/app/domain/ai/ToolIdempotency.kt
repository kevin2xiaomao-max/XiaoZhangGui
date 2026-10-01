package com.xiaozhanggui.app.domain.ai

import java.math.BigDecimal
import java.math.RoundingMode
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID

/**
 * AI 幂等（toolCallID + 业务指纹）。对应 iOS `AI/Tools/ToolIdempotency.swift`。
 *
 * 红线：AI 绝不允许因重复响应 / 重试 / 崩溃恢复把营业额、待办、配送写两次。
 * - toolCallID：每次 ToolCall 生成即固定，重试同一调用复用同一 ID；
 * - 业务指纹：同一业务内容（金额+日期+来源 / 客户+时间+商品）稳定可比。
 *
 * 指纹格式与 iOS 1:1：
 * - 营业额：`rev|<金额2位>|<日期yyyyMMdd>|<来源>|<备注>`
 * - 待办：`todo|<标题>|<到期分钟yyyyMMddHHmm>|<优先级>`
 * - 备忘：`memo|<标题>`
 * - 配送：`del|<客户>|<房号地址>|<分钟>|<商品名>|<数量>|<金额>`
 * - 查询：`search|<kinds排序>|<query>`（仅日志去重，不产生写入）
 */
object ToolIdempotency {

    fun newCallId(): String = "call_${UUID.randomUUID()}"

    fun fingerprint(call: ToolCall): String = fingerprint(call.decodeArguments())

    fun fingerprint(arguments: ToolArguments): String = when (arguments) {
        is ToolArguments.Revenue -> {
            val a = arguments.args
            "rev|${fmt2(a.amount ?: 0.0)}|${day(a.date)}|${norm(a.source)}|${norm(a.note)}"
        }
        is ToolArguments.Todo -> {
            val a = arguments.args
            "todo|${norm(a.title)}|${minute(a.dueDate)}|${a.priority ?: 0}"
        }
        is ToolArguments.Memo -> "memo|${norm(arguments.args.title)}"
        is ToolArguments.Delivery -> {
            val a = arguments.args
            "del|${norm(a.customer)}|${norm(a.roomOrAddress)}|${minute(a.deliveryTime)}|" +
                "${norm(a.goodsName)}|${norm(a.quantity)}|${fmt2(a.amount ?: 0.0)}"
        }
        is ToolArguments.SearchRecords -> {
            val a = arguments.args
            val kinds = a.kinds.map { it.wireName }.sorted().joinToString(",")
            "search|$kinds|${norm(a.query)}"
        }
    }

    // MARK: - 私有格式化

    /** 金额先按 iOS 语义 round 到 2 位（half away from zero），再格式化为 2 位小数。 */
    private fun fmt2(value: Double): String {
        val rounded = BigDecimal(value).setScale(2, RoundingMode.HALF_UP)
        return String.format(Locale.US, "%.2f", rounded)
    }

    private fun norm(value: String?): String = (value ?: "").trim()

    private val zone: ZoneId get() = ZoneId.systemDefault()
    private val dayFormatter: DateTimeFormatter =
        DateTimeFormatter.ofPattern("yyyyMMdd", Locale.US)
    private val minuteFormatter: DateTimeFormatter =
        DateTimeFormatter.ofPattern("yyyyMMddHHmm", Locale.US)

    private fun day(millis: Long?): String =
        if (millis == null) "na"
        else Instant.ofEpochMilli(millis).atZone(zone).format(dayFormatter)

    private fun minute(millis: Long?): String =
        if (millis == null) "na"
        else Instant.ofEpochMilli(millis).atZone(zone).format(minuteFormatter)
}
