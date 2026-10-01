package com.xiaozhanggui.app.domain.ai

/**
 * 意图分类（纯规则、0 Token、可单测）。对应 iOS `AI/Core/IntentRouter.swift`。
 *
 * classify 路由顺序 1:1 iOS（IntentRouter.swift:56-93）：
 * 1. 天气优先 → 2. 经营分析 → 3. 商品查询 → 4. 经营读问答优先 →
 * 5. 记账 → 6. 配送 → 7. 备忘先于待办 → 8. 待办 → 9. 兜底 worldChat
 */
sealed class IntentKind {
    /** 本地可直接处理（Lite 预留，0 Token） */
    object LocalZeroToken : IntentKind()

    /** 经营写动作（CREATE，必须确认） */
    data class BusinessAction(val tool: ToolName) : IntentKind()

    /** 经营读问答（READ，结果经隐私裁剪） */
    data class BusinessQuery(val kind: BusinessRecordKind) : IntentKind()

    /** 普通聊天 / 世界知识（不带经营数据） */
    object WorldChat : IntentKind()

    /** 实时外部信息查询（天气等）：本版本没有对应工具，本地直接明确告知（0 Token） */
    object WeatherQuery : IntentKind()

    /** 店内商品 READ，不生成 ActionCard */
    data class GoodsQuery(val query: String) : IntentKind()

    /** 店铺经营分析。除 advice 外均本地 0-token 回答。 */
    data class BusinessInsight(val kind: BusinessInsightKind) : IntentKind()
}

/** 对应 iOS BusinessInsightKind（AI/Context/BusinessContextProvider.swift:77-84）。 */
sealed class BusinessInsightKind {
    object Overview : BusinessInsightKind()
    object Comparison : BusinessInsightKind()
    object SevenDayTrend : BusinessInsightKind()
    object Inventory : BusinessInsightKind()
    object Advice : BusinessInsightKind()
    data class Period(val period: BusinessPeriod) : BusinessInsightKind()
}

class IntentRouter {

    companion object {
        /** 金额正则：阿拉伯数字或中文数字 + 可选 元/块 */
        private val amountRegex =
            Regex("""(?:\d+(?:\.\d+)?|[一二两三四五六七八九十百千万零]+)\s*(?:元|块|块钱|圆)?""")

        /** 房号 / 客户号：2~5 位数字，或 "302室/房/号" */
        private val roomRegex = Regex("""\d{2,5}\s*(?:室|房|号|栋|单元)?""")

        private val revenueKeywords = listOf(
            "营业额", "营收", "收入", "卖了", "收款", "入账", "营业额",
            "美团", "饿了么", "微信", "支付宝", "现金", "扫呗", "抖音", "快手", "团购", "到账"
        )
        private val deliveryKeywords = listOf("配送", "送货", "送到", "送水", "跑腿")
        private val memoKeywords = listOf("记一下", "记录一下", "备忘", "备注", "供应商", "记一笔")
        private val queryKeywords = listOf(
            "多少", "几单", "几件", "几条", "几个", "有什么", "还有", "？", "?",
            // P0-1 / P0-4：先判「问」再判「记」——出现疑问词时不能仅因时间词就落 CREATE
            "什么", "怎么", "为什么", "哪", "吗", "呢", "查"
        )

        /** 实时天气类外部信息（本版本没有天气工具，命中即明确告知，绝不出待办 / 备忘卡） */
        private val weatherKeywords = listOf(
            "天气", "天气预报", "气温", "多少度", "几度",
            "下雨", "会下雨", "降雨", "降水", "台风", "冷不冷", "热不热"
        )

        /** 命中天气词的同时若出现这些 CREATE 词，仍按经营记录处理（如「提醒我看天气」） */
        private val createCueWords = listOf("记一下", "记录", "备忘", "备注", "提醒", "待办", "记得")

        /**
         * 街道式地址：「到幸福路9号」「送至解放大道128号3栋」等（必须有 到/送至/地址 引导，
         * 与纯数字房号、时间、金额区分）。
         */
        private val streetAddressRegex = Regex(
            """(?:到|去|送至|送到|送往|地址是|地址为|地址[:：]?)\s*""" +
                """([一-龥A-Za-z][一-龥A-Za-z0-9]{0,15}?(?:路|街|巷|大道|村|小区|花园|大厦|广场|苑|城)""" +
                """\s*\d{0,4}\s*(?:号|幢|栋)?(?:\s*\d{1,4}\s*(?:室|房|单元|楼))?)"""
        )
    }

    fun classify(raw: String, now: Long = System.currentTimeMillis()): IntentKind {
        val text = raw.trim()
        if (text.isEmpty()) return IntentKind.WorldChat

        // 0) 实时外部信息查询（天气）优先于一切 CREATE：
        //    「明天恩平什么天气啊，帮我查下」是 READ，不是「明天 + 新建待办」。
        if (isWeatherQuery(text)) return IntentKind.WeatherQuery

        classifyBusinessInsight(text)?.let { return IntentKind.BusinessInsight(it) }

        if (isGoodsQuery(text)) return IntentKind.GoodsQuery(text)

        // 1) 经营读问答优先（避免"今天还有几单配送"被当成新建配送）
        classifyQuery(text)?.let { return it }

        // 2) 营业额：含来源 / 收款语义，且（有金额 或 有明确收款动作词）
        //    只有来源词没有金额（如"美团怎么开店"）不当成记账，交给后续分类 / worldChat
        val revenueActionCues = listOf("营业额", "营收", "收入", "卖了", "收款", "入账", "到账")
        if (revenueKeywords.any { text.contains(it) } &&
            (hasAmount(text) || revenueActionCues.any { text.contains(it) })
        ) {
            return IntentKind.BusinessAction(ToolName.RECORD_REVENUE)
        }

        // 3) 配送：含"送"语义且能找到房号 / 客户号
        if (isDelivery(text)) {
            return IntentKind.BusinessAction(ToolName.CREATE_DELIVERY)
        }

        // 4) 备忘（"记一下供应商周五来"）先于待办
        if (memoKeywords.any { text.contains(it) }) {
            return IntentKind.BusinessAction(ToolName.CREATE_MEMO)
        }

        // 5) 待办：未来时间 / 动作词
        if (isTodo(text)) {
            return IntentKind.BusinessAction(ToolName.CREATE_TODO)
        }

        // 6) 兜底：普通聊天（不携带任何经营数据）
        return IntentKind.WorldChat
    }

    // MARK: 分类依据（纯函数，亦可被解析层复用）

    fun hasAmount(text: String): Boolean {
        val match = amountRegex.find(text) ?: return false
        val token = match.value
        // 纯中文日期词（如"周五"）不算金额
        val stripped = token.replace(Regex("[元块圆\\s]"), "")
        stripped.toDoubleOrNull()?.let { return it > 0 }
        ChineseNumber.parse(stripped)?.let { return it > 0 }
        return false
    }

    fun isDelivery(text: String): Boolean {
        val hasVerb = text.contains("送") || deliveryKeywords.any { text.contains(it) }
        if (!hasVerb) return false
        // 「送…到幸福路9号」：出现街道式地址即配送
        if (streetAddress(text) != null) return true
        // 「给阿东送…」：中文人名 + 送（无房号也是配送）
        if (Regex("""给\s*[一-龥]{2,4}\s*送""").containsMatchIn(text)) return true
        // "给302送…" / "送…到302" / 含 室|房|号
        if (text.contains("给") && firstRoomNumber(text) != null) return true
        if (firstRoomNumber(text) != null &&
            Regex("""\d{2,5}\s*(室|房|号|栋|单元)""").containsMatchIn(text)
        ) return true
        if (deliveryKeywords.any { text.contains(it) }) return true
        return false
    }

    /** 提取街道式地址（无则 null）。仅供配送判定 / 解析层复用。 */
    fun streetAddress(text: String): String? {
        val match = streetAddressRegex.find(text) ?: return null
        return match.groupValues[1].trim().takeIf { it.isNotEmpty() }
    }

    fun firstRoomNumber(text: String): String? {
        val match = roomRegex.find(text) ?: return null
        return match.value
    }

    private fun isTodo(text: String): Boolean {
        val timeMarkers = listOf(
            "今天", "明天", "后天", "下周", "周一", "周二", "周三", "周四",
            "周五", "周六", "周日", "周末", "月底", "早上", "晚上", "下午", "上午"
        )
        val actionMarkers = listOf(
            "记得", "提醒", "下货", "下单", "进货", "补货", "买", "带",
            "联系", "打电话", "收拾", "整理", "安排", "要做", "跟进"
        )
        val hasAction = actionMarkers.any { text.contains(it) }
        val timeOnly = listOf("今天", "明天", "后天", "下午3点", "上午3点", "晚上8点")
            .contains(text.trim())
        // 时间词本身不是写入意图；但"明天下两箱可乐"仍有明确事项内容。
        if (timeOnly) return false
        return hasAction || (timeMarkers.any { text.contains(it) } && text.length > 2)
    }

    /**
     * 天气等实时外部查询：含天气类词，且不是「记/提醒/备忘」式 CREATE。
     * 「明天恩平什么天气啊，帮我查下」→ true；「提醒我明天看天气」→ false。
     */
    private fun isWeatherQuery(text: String): Boolean {
        if (!weatherKeywords.any { text.contains(it) }) return false
        if (createCueWords.any { text.contains(it) }) return false
        return true
    }

    private fun isGoodsQuery(text: String): Boolean {
        // 解释 / 定义类问题讨论经营概念，不是在查询店内某个商品。
        // 先排除这些知识问法，避免"什么是毛利率"等问题被"毛利" marker 截走。
        val explanationPhrases =
            listOf("什么是", "是什么", "是什么意思", "怎么计算", "如何计算", "怎么提高", "如何提高")
        if (explanationPhrases.any { text.contains(it) }) return false

        val markers = listOf("多少钱", "进价", "售价", "库存", "毛利", "有没有", "还有多少")
        if (!markers.any { text.contains(it) }) return false
        val nonGoodsPhrases =
            listOf("天气", "配送", "送货", "待办", "备忘", "临期", "过期", "明显下降", "什么问题")
        return nonGoodsPhrases.none { text.contains(it) }
    }

    private fun classifyQuery(text: String): IntentKind? {
        val asks = queryKeywords.any { text.contains(it) }
        val looksQuestion = asks || text.endsWith("吗")
        if (!looksQuestion) return null
        if (text.contains("营业额") || text.contains("卖了") || text.contains("收入") || text.contains("营收")) {
            return IntentKind.BusinessQuery(BusinessRecordKind.REVENUE_TODAY)
        }
        if (text.contains("配送") || text.contains("送货") || text.contains("送水") || text.contains("几单")) {
            return IntentKind.BusinessQuery(BusinessRecordKind.DELIVERY)
        }
        if (text.contains("临期") || text.contains("过期") || text.contains("到期") ||
            text.contains("保质期") || text.contains("退货")
        ) {
            return IntentKind.BusinessQuery(BusinessRecordKind.EXPIRING_GOODS)
        }
        if (text.contains("待办") || text.contains("事项") || text.contains("要做") || text.contains("任务")) {
            return IntentKind.BusinessQuery(BusinessRecordKind.TODO_TODAY)
        }
        if (text.contains("备忘") || text.contains("记过") || text.contains("笔记")) {
            return IntentKind.BusinessQuery(BusinessRecordKind.RECENT_MEMO)
        }
        // 是问句但不属于店内经营实体：交云端正常回答。
        // 关键：此时即便句中含「明天」等时间词，也绝不能继续落入 CREATE（P0-1 / P0-4）。
        return IntentKind.WorldChat
    }

    private fun classifyBusinessInsight(text: String): BusinessInsightKind? {
        val period = BusinessPeriodParser().parse(text)
        if (period != null &&
            period != BusinessPeriod.TODAY && period != BusinessPeriod.YESTERDAY &&
            (period != BusinessPeriod.LAST_SEVEN_DAYS ||
                listOf("生意", "业绩", "经营").any { text.contains(it) }) &&
            (listOf("生意", "业绩", "营业额", "营收", "经营").any { text.contains(it) } ||
                period == BusinessPeriod.THIS_MONTH_COMPARED_WITH_LAST_MONTH ||
                period == BusinessPeriod.LAST_THREE_MONTHS_COMPARED_WITH_THIS_MONTH)
        ) {
            return BusinessInsightKind.Period(period)
        }
        // 明确的跨日比较本身就是经营分析信号；不能要求用户重复说"营业额"。
        if (text.contains("今天") && text.contains("昨天") &&
            listOf("比", "对比", "相比", "较").any { text.contains(it) }
        ) {
            return BusinessInsightKind.Comparison
        }
        val businessWords = listOf("生意", "经营", "店里", "店铺", "我的店", "库存", "营业额", "营收")
        if (businessWords.none { text.contains(it) }) return null
        if (text.contains("多少") || text.contains("几笔") || text.contains("几单")) return null
        if (text.contains("结合") && listOf("建议", "分析", "怎么办").any { text.contains(it) }) {
            return BusinessInsightKind.Advice
        }
        if (text.contains("库存") && listOf("注意", "怎么样", "哪些", "风险", "低库存").any { text.contains(it) }) {
            return BusinessInsightKind.Inventory
        }
        if (text.contains("7天") || text.contains("七天") || text.contains("一周") ||
            text.contains("最近生意") || text.contains("趋势")
        ) {
            return BusinessInsightKind.SevenDayTrend
        }
        if (text.contains("比昨天") || text.contains("昨天比") || text.contains("较昨天")) {
            return BusinessInsightKind.Comparison
        }
        if (text.contains("今天") && listOf("怎么样", "如何", "情况", "好不好").any { text.contains(it) }) {
            return BusinessInsightKind.Overview
        }
        return null
    }
}
