package com.xiaozhanggui.app.domain.ai

/**
 * 多轮纠正识别（纯规则、0 Token）。对应 iOS `AI/Core/CorrectionParser.swift`。
 *
 * 真机场景：ActionCard 已挂出一个 pending proposal，用户说
 * 「没有，是帮我记录备忘了，是没收到钱」/「不是，改成备忘，没收到钱」。
 * 正确处理：旧 proposal 立即失效 → 剥掉纠正话术 → 按新业务类型重新出卡。
 * 本文件只负责识别与清洗；取消旧 pending、出卡由 AgentCore 编排。
 */

/** 一次纠正的解析结果。 */
data class Correction(
    /** 剥掉纠正话术后的真实业务内容（如「没收到钱」）；可能为空（用户只表达了否定） */
    val cleanedText: String,
    /** 用户明确点出的新业务类型（如「改成备忘」→ CREATE_MEMO）；null 表示交给意图分类器 */
    val targetTool: ToolName?
)

object CorrectionParser {
    /** 强纠正信号：仅在句首出现才认可（避免「没有货了再进点」这类正常表达误伤）。 */
    private val strongCues = listOf(
        "不是", "不对", "搞错", "弄错", "错了", "应该是",
        "改成", "改为", "记成", "记为", "换成", "重新记", "没有"
    )

    /** 纠正框架词（按长度降序替换；只表语气 / 改类型，不含业务内容） */
    private val frameWords = listOf(
        "应该是", "重新记", "搞错了", "搞错", "弄错", "错了",
        "改成", "改为", "记成", "记为", "换成", "不是", "不对",
        "帮我", "记录", "记一下", "记一笔", "记个", "没有",
        "应该", "重新", "这个", "那个", "一条", "一个", "一下"
    )

    /** 框架剥离后，句首可能残留的虚字（只裁句首，避免误伤正文中的「的 / 了」） */
    private val leadingFiller = "是了的啊呀吧呢嘛喂，,。.:： ".toSet()

    private val separators = setOf('，', ',', '。', '；', ';', '、', ' ', '\n', '\t')

    fun detect(raw: String): Correction? {
        val text = raw.trim()
        if (text.isEmpty()) return null

        val prefix = text.take(8)
        if (strongCues.none { prefix.contains(it) }) return null

        val segments = text.split(*separators.toCharArray())
            .map { it.trim() }
            .filter { it.isNotEmpty() }

        var tool: ToolName? = null
        val contents = mutableListOf<String>()

        for (segment in segments) {
            val stripped = stripFrames(segment)
            if (stripped.isEmpty()) continue

            val announced = announcedType(stripped)
            if (announced != null) {
                tool = announced.first
                val remainder = stripped
                    .replace(announced.second, "")
                    .trimStart { it in leadingFiller }
                if (remainder.isNotEmpty()) contents.add(remainder)
            } else {
                contents.add(stripped)
            }
        }

        val cleaned = contents.joinToString("，").trim()
        return Correction(cleanedText = cleaned, targetTool = tool)
    }

    private fun stripFrames(segment: String): String {
        var result = segment
        for (word in frameWords) {
            result = result.replace(word, "")
        }
        // 反复剥句首虚字与单字「记 / 成」，直到稳定
        var previous: String
        do {
            previous = result
            result = result.trimStart { it in leadingFiller }
            if (result.startsWith("记")) result = result.drop(1)
            if (result.startsWith("成")) result = result.drop(1)
            result = result.trimStart { it in leadingFiller }
        } while (result != previous)
        return result
    }

    private fun announcedType(stripped: String): Pair<ToolName, String>? {
        // 顺序敏感：备忘先于待办；「收款」要排除「没收到钱」（收款二字不连续，天然安全）
        if (stripped.contains("备忘") || stripped.contains("备注")) {
            return ToolName.CREATE_MEMO to if (stripped.contains("备忘")) "备忘" else "备注"
        }
        if (stripped.contains("待办")) return ToolName.CREATE_TODO to "待办"
        if (stripped.contains("提醒")) return ToolName.CREATE_TODO to "提醒"
        if (stripped.contains("事项") || stripped.contains("任务")) {
            return ToolName.CREATE_TODO to if (stripped.contains("事项")) "事项" else "任务"
        }
        if (stripped.contains("配送") || stripped.contains("送货") || stripped.contains("快递")) {
            val keyword = when {
                stripped.contains("配送") -> "配送"
                stripped.contains("送货") -> "送货"
                else -> "快递"
            }
            return ToolName.CREATE_DELIVERY to keyword
        }
        if (stripped.contains("营业额") || stripped.contains("营收")) {
            return ToolName.RECORD_REVENUE to if (stripped.contains("营业额")) "营业额" else "营收"
        }
        if (stripped.contains("收入") || stripped.contains("到账") || stripped.contains("收款")) {
            val keyword = when {
                stripped.contains("收入") -> "收入"
                stripped.contains("到账") -> "到账"
                else -> "收款"
            }
            return ToolName.RECORD_REVENUE to keyword
        }
        return null
    }
}

sealed class PendingFieldCorrection {
    data class Update(val arguments: ToolArguments, val message: String) : PendingFieldCorrection()
    object Cancel : PendingFieldCorrection()
    data class FollowUp(val question: String) : PendingFieldCorrection()
}

/** 对单个待确认 ActionCard 做字段级修正；不重新解析整条业务记录，也不触碰数据库。 */
object PendingFieldCorrectionParser {
    private val sources = listOf("美团", "饿了么", "微信", "支付宝", "现金", "扫呗", "抖音", "快手")
    private val numberRegex = Regex("""\d+(?:\.\d+)?""")

    fun parse(raw: String, current: ToolArguments, now: Long = System.currentTimeMillis()): PendingFieldCorrection? {
        val text = raw.trim()
        if (listOf("取消刚才那个", "取消刚才的", "刚才那个取消", "不要了", "取消这条").any { text.contains(it) }) {
            return PendingFieldCorrection.Cancel
        }

        return when (current) {
            is ToolArguments.Revenue -> {
                val value = current.args
                if (text.contains("金额") && lastNumber(text) == null) {
                    return PendingFieldCorrection.FollowUp("金额要改成多少？")
                }
                if (text.contains("不是") || text.contains("金额") || text.contains("改成") || text.contains("改为")) {
                    val amount = lastNumber(text)
                    if (amount != null && amount > 0) {
                        val updated = value.copy(amount = amount)
                        return PendingFieldCorrection.Update(
                            ToolArguments.Revenue(updated),
                            "金额已改为 ¥${money(amount)}，请确认。"
                        )
                    }
                }
                val source = sources.firstOrNull { text.contains(it) }
                if (text.contains("来源") && source != null) {
                    return PendingFieldCorrection.Update(
                        ToolArguments.Revenue(value.copy(source = source)),
                        "来源已改为$source，请确认。"
                    )
                }
                null
            }
            is ToolArguments.Todo -> {
                val value = current.args
                if (text.contains("改") || text.contains("刚才")) {
                    when (val r = DatePhraseParser.resolve(text, now)) {
                        is TimeResolution.Date -> PendingFieldCorrection.Update(
                            ToolArguments.Todo(value.copy(dueDate = r.millis)),
                            "待办时间已更新，请确认。"
                        )
                        is TimeResolution.AmbiguousClock -> PendingFieldCorrection.FollowUp(
                            "你说的「${r.token}」是凌晨还是下午？请补充时段。"
                        )
                        else -> if (text.contains("时间") || text.contains("日期")) {
                            PendingFieldCorrection.FollowUp("要改成什么时间？")
                        } else null
                    }
                } else null
            }
            is ToolArguments.Memo, is ToolArguments.Delivery, is ToolArguments.SearchRecords -> null
        }
    }

    private fun lastNumber(text: String): Double? {
        val matches = numberRegex.findAll(text).toList()
        return matches.lastOrNull()?.value?.toDoubleOrNull()
    }

    private fun money(value: Double): String =
        if (value == kotlin.math.round(value)) "%.0f".format(value) else "%.2f".format(value)
}

// MARK: - V3.3 P0-6 · 客户订单「未收款」语义检测
//
// 当前 CustomerRequest 模型没有收款状态字段（详见最终报告的 schema 方案）。
// 红线：识别到该语义时只能明确告知 + 等升级，禁止降级成 Todo / Memo，禁止写库。
object CustomerPaymentIntent {
    /** 未收款的各种口语表达 */
    val unpaidPhrases = listOf(
        "没收到钱", "还没收到钱", "没收钱", "还没收钱",
        "没给钱", "还没给钱", "钱还没给", "钱没给",
        "还没付款", "未付款", "未收款", "还没收款",
        "欠款", "欠钱", "欠着", "还欠", "赊账", "赊着", "挂账"
    )

    /** 表明这笔钱属于「某个客户订单」的语境词 */
    private val customerCues = listOf(
        "客人", "客户", "顾客", "这单", "那一单", "这笔", "那笔", "他的单"
    )

    fun isUnpaidCustomerOrder(text: String): Boolean {
        val unpaid = unpaidPhrases.any { text.contains(it) }
        val customer = customerCues.any { text.contains(it) }
        return unpaid && customer
    }

    const val unsupportedMessage: String =
        "我明白，这是客户这一单「还没收款」。当前版本的客户单还没有收款状态字段，" +
            "我不会把它误记成待办或备忘（本次没有写入任何数据）。下次小升级给客户单加上" +
            "「未收款 / 已收款」后，这里就能直接显示「阿东 · 未收款」。"
}
