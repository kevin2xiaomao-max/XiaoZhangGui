package com.xiaozhanggui.app.data.ai

import com.xiaozhanggui.app.data.repository.GoodsRepository
import kotlinx.coroutines.flow.first

/**
 * 本地 Skill（0 Token，不需要 API Key）。对应 iOS `AI/Skills/`。
 *
 * - GoodsLookupSkill：店内商品 READ，不生成 ActionCard；
 * - MetaReply：寒暄 / 元问题（你好、谢谢、你是谁）的固定回复；
 * - WeatherSkill：本版本无天气工具，明确告知用户当前不支持，绝不编天气。
 */

/** 店内商品查询：名字模糊匹配本地商品库，返回进价 / 售价 / 库存。 */
class GoodsLookupSkill(private val goodsRepository: GoodsRepository) {

    suspend fun lookup(query: String): String {
        val all = goodsRepository.observeAll().first()
        if (all.isEmpty()) return "店里还没有录入商品。"
        val keywords = query
            .replace(Regex("多少钱|进价|售价|库存|毛利|有没有|还有多少|的"), "")
            .trim()
        val matches = if (keywords.isEmpty()) {
            all
        } else {
            all.filter { it.name.contains(keywords) || keywords.contains(it.name) }
        }
        if (matches.isEmpty()) return "没找到「$query」相关的商品。"
        val lines = matches.take(5).map { g ->
            val price = "售价 ¥${fmt(g.salePrice)}"
            val cost = if (g.purchasePrice > 0) "，进价 ¥${fmt(g.purchasePrice)}" else ""
            val stock = "，库存 ${g.stock}"
            "- ${g.name}：$price$cost$stock"
        }
        return lines.joinToString("\n")
    }

    private fun fmt(value: Double): String {
        val rounded = kotlin.math.round(value * 100) / 100.0
        return if (rounded == kotlin.math.floor(rounded)) rounded.toLong().toString()
        else "%.2f".format(rounded).trimEnd('0')
    }
}

/** 寒暄与元问题：固定友好回复，0 Token。对应 iOS MetaReply。 */
object MetaReply {
    private val replies: List<Pair<List<String>, String>> = listOf(
        listOf("你好", "您好", "hi", "hello", "在吗") to
            "你好呀，我是你的小掌柜 AI 助手。可以帮你记账、记配送、记备忘、记待办，也可以查今天的营业额和配送单。",
        listOf("谢谢", "感谢", "辛苦") to "不客气，这是我应该做的。",
        listOf("再见", "拜拜", "晚安") to "再见，生意兴隆！",
        listOf("你是谁", "你的名字", "介绍一下") to
            "我是你的小掌柜 AI 助手，专门帮你打理小店的记账、配送、备忘和待办。",
        listOf("你会什么", "你能做什么", "功能") to
            "我可以：记营业额（如「今天美团680」）、记配送（如「今晚8点送3杯奶茶到幸福路9号」）、记备忘、记待办，还能查今天的营业额、配送单、临期商品和待办。"
    )

    /** 命中则返回固定回复，否则 null（继续走正常流程）。 */
    fun reply(text: String): String? {
        val t = text.trim()
        if (t.length > 12) return null
        return replies.firstOrNull { (keys, _) -> keys.any { t.contains(it) } }?.second
    }
}

/**
 * 天气查询：本版本没有天气工具。明确告知用户当前不支持天气查询，
 * 绝不把天气问句误判成待办 / 备忘（IntentRouter 已将其路由到 WeatherQuery）。
 */
object WeatherSkill {
    fun reply(text: String): String =
        "我现在还查不了天气（没有接入天气服务）。需要记待办或备忘的话，直接告诉我就行。"
}
