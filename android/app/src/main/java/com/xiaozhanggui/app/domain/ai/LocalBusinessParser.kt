package com.xiaozhanggui.app.domain.ai

/**
 * 本地业务解析（Free First · 0 Token）。对应 iOS `AI/Providers/LocalBusinessParser.swift`。
 *
 * - 命中高置信规则时直接产出 ToolArguments（0 Token），由 AgentCore 直接出 ActionCard；
 * - 信息不足时产出 Clarify 追问（仍 0 Token）；
 * - 返回 null 表示本地无把握，才允许上云。
 * 纯规则、无网络、无 Key 依赖；未配置 API Key 时本地 CREATE 照常工作。
 *
 * 只处理 businessAction（recordRevenue/createTodo/createMemo/createDelivery），
 * 其余意图返回 null（查询走本地聚合回答，普通聊天走云端）。
 */
sealed class LocalParseResult {
    /** 高置信：直接生成结构化动作 */
    data class Tool(val arguments: ToolArguments) : LocalParseResult()

    /** 识别到意图但信息不足，追问用户补充（绝不脑补缺失字段） */
    data class Clarify(val message: String) : LocalParseResult()
}

class LocalBusinessParser(private val router: IntentRouter = IntentRouter()) {

    companion object {
        private val revenueSources = listOf(
            "美团", "饿了么", "抖音", "快手", "微信", "支付宝", "现金",
            "扫呗", "团购", "云闪付", "收钱码", "京东", "淘宝", "拼多多"
        )

        private val phoneRegex = Regex("""1\d{10}""")
        private val timeTextRegex = Regex(
            """(今天|明天|后天|今晚|明晚)?\s*(凌晨|早上|早晨|上午|中午|下午|傍晚|晚上|晚间)?\s*""" +
                """\d{1,2}\s*[点:：]\s*\d{0,2}\s*分?"""
        )

        /** 「一共45元 / 共45元 / 45元 / 45块」——只认真钱，不会把「8点」「3杯」「9号」当金额 */
        private val amountRegex = Regex("""(?:一共|共|合计)?\s*(\d+(?:\.\d+)?)\s*(?:元|块|块钱)""")

        /** 「给302送」中的纯数字房号（不匹配「幸福路9号」「45元」） */
        private val roomAfterGeiRegex = Regex("""给\s*(\d{2,5})\s*送""")

        /** 「送到302室 / 送至12栋」中的数字房号 */
        private val roomAfterDaoRegex = Regex("""(?:到|去|送至|送到|送往)\s*(\d{2,5}\s*(?:室|房|号|幢|栋|单元)?)""")

        /** 「给阿东送」「客户阿东」中的中文人名 */
        private val namedCustomerRegex =
            Regex("""(?:给\s*|客户\s*[:：是]?\s*|客人\s*[:：是]?\s*|顾客\s*[:：是]?\s*)([一-龥]{2,4})\s*送""")

        /** 带单位商品：3杯 / 两箱 / 12瓶（杯为 P0-2 真机词，单位表必须包含） */
        private val itemWithUnitRegex = Regex(
            """([0-9]+|[一二两三四五六七八九十]+)\s*""" +
                """(杯|箱|件|瓶|袋|个|份|包|条|桶|提|扎|盒|罐|打|套|支|只)"""
        )

        /** 「百年糊涂×2 / 王老吉 x3」式多商品 */
        private val crossItemRegex = Regex("""([一-龥A-Za-z][一-龥A-Za-z0-9]{0,9})\s*[×xX*]\s*([0-9]+)""")

        private val memoPrefixes = listOf(
            "帮我记一下", "帮我记录一下", "记录一下", "记一下", "记一笔",
            "备忘", "备注", "帮我记", "记个"
        )

        private val todoStripTokens = listOf(
            "今天", "明天", "后天", "下周", "周末", "月底",
            "周一", "周二", "周三", "周四", "周五", "周六", "周日",
            "星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期天",
            "今晚", "明晚", "凌晨", "早上", "早晨", "上午", "中午", "下午", "傍晚", "晚上",
            "记得", "帮我", "提醒我", "要", "去"
        )
    }

    private data class DeliveryItem(val name: String, val quantity: String)

    fun parse(
        raw: String,
        intent: IntentKind,
        now: Long = System.currentTimeMillis()
    ): LocalParseResult? {
        val text = raw.trim()
        if (text.isEmpty()) return null
        return when (intent) {
            is IntentKind.BusinessAction -> when (intent.tool) {
                ToolName.RECORD_REVENUE -> parseRevenue(text, now)
                ToolName.CREATE_TODO -> parseTodo(text, now)
                ToolName.CREATE_MEMO -> parseMemo(text)
                ToolName.CREATE_DELIVERY -> parseDelivery(text, now)
                ToolName.SEARCH_RECORDS -> null
            }
            else -> null
        }
    }

    // MARK: 营业额

    private fun parseRevenue(text: String, now: Long): LocalParseResult {
        val amount = AmountPhraseParser.parse(text)
        if (amount == null || amount <= 0) {
            return LocalParseResult.Clarify("记营业额需要金额，例如「今天美团680」。")
        }
        val source = revenueSources.firstOrNull { text.contains(it) }
        val date = DatePhraseParser.parse(text, now) ?: now
        return LocalParseResult.Tool(
            ToolArguments.Revenue(
                RevenueArguments(
                    amount = amount,
                    source = source,
                    date = date,
                    note = if (source == null) text else null
                )
            )
        )
    }

    // MARK: 待办

    private fun parseTodo(text: String, now: Long): LocalParseResult {
        // "今晚/明晚"不是 resolve 认识的"晚上"，先归一化
        val normalized = text
            .replace("今晚", "今天晚上")
            .replace("明晚", "明天晚上")

        // P0-3：「明天3点」这类裸数字点有歧义，必须追问「凌晨还是下午」，
        // 绝不允许静默回落当前时间。
        when (val r = DatePhraseParser.resolve(normalized, now)) {
            is TimeResolution.AmbiguousClock ->
                return LocalParseResult.Clarify(
                    "你说的「${r.token}」是凌晨${r.token}还是下午${r.token}？请补充时段，例如「明天下午3点」。"
                )
            else -> Unit
        }
        val due: Long? = when (val r = DatePhraseParser.resolve(normalized, now)) {
            is TimeResolution.Date -> r.millis
            else -> null
        }

        var title = text
        // 剥掉命中的整段时间原文（如「明天下午3点」），避免标题残留时间
        timeTextRegex.find(text)?.let { title = title.replace(it.value, "") }
        for (token in todoStripTokens) {
            title = title.replace(token, "")
        }
        title = title.trim()
        if (title.isEmpty()) {
            return LocalParseResult.Clarify("待办内容是什么？例如「明天下两箱可乐」。")
        }
        return LocalParseResult.Tool(
            ToolArguments.Todo(TodoArguments(title = title, detail = text, dueDate = due, priority = 0))
        )
    }

    // MARK: 备忘

    private fun parseMemo(text: String): LocalParseResult {
        var title = text
        for (prefix in memoPrefixes) {
            if (title.startsWith(prefix)) title = title.removePrefix(prefix)
        }
        title = title.trim(' ', '，', ',', '。', '.', ':', '：')
        if (title.isEmpty()) {
            return LocalParseResult.Clarify("备忘内容是什么？例如「记一下供应商周五来」。")
        }
        return LocalParseResult.Tool(
            ToolArguments.Memo(MemoArguments(title = title.take(20), content = text))
        )
    }

    // MARK: 配送

    private fun parseDelivery(text: String, now: Long): LocalParseResult {
        // "今晚"不是 resolve 认识的"晚上"，先归一化再解析时间
        val normalized = text
            .replace("今晚", "今天晚上")
            .replace("明晚", "明天晚上")

        // P0-2：配送时间同样不允许歧义回落（「3点」必须追问，不得用当前时间）
        val deliveryTime: Long? = when (val r = DatePhraseParser.resolve(normalized, now)) {
            is TimeResolution.Date -> r.millis
            is TimeResolution.AmbiguousClock ->
                return LocalParseResult.Clarify(
                    "你说的「${r.token}」是凌晨${r.token}还是下午${r.token}？请补充时段，例如「晚上8点」。"
                )
            else -> null
        }
        // 时间原文取用户原始说法（如「今晚8点」）
        val deliveryTimeText = timeTextRegex.find(text)?.value

        val phone = phoneRegex.find(text)?.value
        val amount = firstAmount(text)

        // 地址：街道地址（幸福路9号）与纯数字房号（给302送 / 送到302室）严格区分
        val streetAddress = router.streetAddress(text)
        val namedCustomer = firstNamedCustomer(text)
        val roomAfterGei = roomAfterGeiRegex.find(text)?.groupValues?.get(1)?.trim()
        val roomAfterDao = roomAfterDaoRegex.find(text)?.groupValues?.get(1)?.trim()

        // customer：只接受明确人名；无名时留空（P0-2 真机句 customer 必须为空）。
        // 旧范例「给302送」沿用历史行为：纯数字房号同时作为客户标识与房号。
        val customer = namedCustomer ?: roomAfterGei?.takeIf { it.isNotEmpty() }
        val roomOrAddress = streetAddress
            ?: roomAfterDao?.takeIf { it.isNotEmpty() }
            ?: (if (namedCustomer == null) roomAfterGei?.takeIf { it.isNotEmpty() } else null)

        val items = extractItems(text)
        val quantityText = items.firstOrNull()?.quantity
        val goodsName = items.firstOrNull()?.name
        val content: String? = if (items.isEmpty()) null else items.joinToString("、") { item ->
            listOf(item.name, item.quantity).filter { it.isNotEmpty() }.joinToString(" ")
        }

        if (roomOrAddress == null && content == null) {
            return LocalParseResult.Clarify("配送需要地址或商品，例如「今晚8点送3杯珍珠奶茶到幸福路9号，一共45元」。")
        }

        return LocalParseResult.Tool(
            ToolArguments.Delivery(
                DeliveryArguments(
                    customer = customer,
                    roomOrAddress = roomOrAddress,
                    phone = phone,
                    content = content,
                    goodsName = goodsName,
                    quantity = quantityText,
                    deliveryTime = deliveryTime,
                    deliveryTimeText = deliveryTimeText,
                    note = null,
                    amount = amount
                )
            )
        )
    }

    // MARK: - 配送字段提取（P0-2）

    private fun firstAmount(text: String): Double? {
        val match = amountRegex.find(text) ?: return null
        val value = match.groupValues[1].toDoubleOrNull() ?: return null
        return if (value > 0) value else null
    }

    private fun firstNamedCustomer(text: String): String? {
        val match = namedCustomerRegex.find(text) ?: return null
        return match.groupValues[1].trim().takeIf { it.isNotEmpty() }
    }

    /**
     * 抽取商品行：优先「商品×N」式（可多行），否则「N + 单位 + 商品名」。
     * 只在「送」之后的正文里抽（避免把「给阿东送」「今晚8点」抓成商品）；
     * 商品出现在「送到」之前的少数语序再回退全文。
     */
    private fun extractItems(text: String): List<DeliveryItem> {
        val body = if (text.contains("送")) text.substringAfter("送") else text
        val inBody = extractItemMatches(body)
        if (!inBody.isNullOrEmpty()) return inBody
        return extractItemMatches(text) ?: emptyList()
    }

    private fun extractItemMatches(text: String): List<DeliveryItem>? {
        val cross = crossItemRegex.findAll(text).toList()
        if (cross.isNotEmpty()) {
            return cross.map { match ->
                DeliveryItem(
                    name = match.groupValues[1],
                    quantity = "×" + match.groupValues[2]
                )
            }
        }

        val matches = itemWithUnitRegex.findAll(text).toList()
        if (matches.isEmpty()) return null
        return matches.map { match ->
            val quantity = match.value
            // 数量+单位之后的连续中英文 / 数字即商品名，遇到 到/去/送/标点/下一串数字 即止
            var name = ""
            var rest = text.substring(match.range.last + 1)
            val sb = StringBuilder()
            for (ch in rest) {
                if ("到去送，,。；;（()） \n\t".contains(ch)) break
                if (ch.isDigit() && sb.isNotEmpty()) break
                sb.append(ch)
            }
            name = sb.toString().trim()
            DeliveryItem(name = name, quantity = quantity)
        }
    }
}
