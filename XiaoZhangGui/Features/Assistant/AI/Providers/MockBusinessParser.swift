import Foundation

// MARK: - V3.3 Lite · 内置规则解析（仅 Foundation / 预览 / 测试使用）
//
// 这是 MockAIProvider 的确定性本地解析：不联网、0 Token，
// 只覆盖 Lite 四个范例句与常见说法，用来跑通「理解 → 结构化 → ActionCard 预览」。
// FINAL 由真实 Provider 做语义解析，本类降级为兜底 / 测试脚本，不参与正式写库判定。
// 复用现有 AmountPhraseParser / DatePhraseParser / ChineseNumber，不重复造轮子。

enum MockParseResult: Equatable {
    case tool(ToolArguments)
    /// 信息不足，要求用户补充（绝不脑补缺失字段）
    case clarify(String)
}

struct MockBusinessParser {
    private let router = IntentRouter()

    private static let revenueSources = [
        "美团", "饿了么", "抖音", "快手", "微信", "支付宝", "现金",
        "扫呗", "团购", "云闪付", "收钱码", "京东", "淘宝", "拼多多"
    ]

    private static let quantityRegex = try? NSRegularExpression(
        pattern: #"([0-9一二两三四五六七八九十]+)\s*(箱|件|瓶|袋|个|份|包|条|桶|提|扎)"#)
    private static let phoneRegex = try? NSRegularExpression(pattern: #"1\d{10}"#)
    private static let timeTextRegex = try? NSRegularExpression(
        pattern: #"(今天|明天|后天|今晚|明晚)?\s*(上午|下午|晚上|中午)?\s*\d{1,2}\s*[点:：]\s*\d{0,2}\s*分?"#)

    func parse(_ text: String, intent: IntentKind, now: Date = Date()) -> MockParseResult? {
        switch intent {
        case .businessAction(let tool):
            switch tool {
            case .recordRevenue: return parseRevenue(text, now: now)
            case .createTodo: return parseTodo(text, now: now)
            case .createMemo: return parseMemo(text)
            case .createDelivery: return parseDelivery(text, now: now)
            case .searchRecords: return nil
            }
        case .businessQuery:
            // Foundation 未接经营数据，明确告知（FINAL 改走 searchRecords）
            return .clarify("预览版还没有接入你的经营数据；正式版可以在这里查询今日营业额、待办、备忘和配送。")
        case .worldChat, .localZeroToken:
            return nil
        }
    }

    // MARK: 营业额

    private func parseRevenue(_ text: String, now: Date) -> MockParseResult {
        guard let amount = AmountPhraseParser.parse(text), amount > 0 else {
            return .clarify("请补充营业额金额，例如：今天美团680")
        }
        let source = Self.revenueSources.first(where: { text.contains($0) })
        let date = DatePhraseParser.parse(text, now: now) ?? now
        let args = RevenueArguments(
            amount: amount,
            source: source,
            date: date,
            note: source == nil ? text : nil
        )
        return .tool(.recordRevenue(args))
    }

    // MARK: 待办

    private func parseTodo(_ text: String, now: Date) -> MockParseResult {
        let due = DatePhraseParser.parse(text, now: now)
        var title = text
        let patterns = [
            "今天", "明天", "后天", "下周", "周末", "月底",
            "周一", "周二", "周三", "周四", "周五", "周六", "周日",
            "星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期天",
            "记得", "帮我", "提醒我", "要", "去"
        ]
        for token in patterns { title = title.replacingOccurrences(of: token, with: "") }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return .clarify("待办内容是什么？例如：明天下两箱可乐")
        }
        let args = TodoArguments(title: title, detail: text, dueDate: due, priority: 0)
        return .tool(.createTodo(args))
    }

    // MARK: 备忘

    private func parseMemo(_ text: String) -> MockParseResult {
        var title = text
        for prefix in ["帮我记一下", "帮我记录一下", "记录一下", "记一下", "记一笔",
                       "备忘", "备注", "帮我记", "记个"] {
            if title.hasPrefix(prefix) { title = String(title.dropFirst(prefix.count)) }
        }
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: " ，,。.:："))
        guard !title.isEmpty else {
            return .clarify("备忘内容是什么？例如：记一下供应商周五来")
        }
        let args = MemoArguments(title: String(title.prefix(20)), content: text)
        return .tool(.createMemo(args))
    }

    // MARK: 配送

    private func parseDelivery(_ text: String, now: Date) -> MockParseResult {
        // “今晚”不是 DatePhraseParser 认识的“晚上”，先归一化再解析时间
        let normalized = text
            .replacingOccurrences(of: "今晚", with: "今天晚上")
            .replacingOccurrences(of: "明晚", with: "明天晚上")
        let deliveryTime = DatePhraseParser.parse(normalized, now: now)
        let deliveryTimeText = firstMatch(Self.timeTextRegex, in: text)

        let room = router.firstRoomNumber(in: text)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = firstMatch(Self.phoneRegex, in: text)

        // 商品 / 数量：取“送”之后的短语
        var tail = text
        if let range = text.range(of: "送", options: .backwards) {
            tail = String(text[range.upperBound...])
        }
        let quantityText = firstMatch(Self.quantityRegex, in: tail)
        var goodsName = tail
        if let quantityText {
            goodsName = goodsName.replacingOccurrences(of: quantityText, with: "")
        }
        goodsName = goodsName.trimmingCharacters(in: .whitespacesAndNewlines)

        let content: String? = {
            let goods = goodsName.isEmpty ? "" : goodsName
            let qty = quantityText ?? ""
            let joined = [goods, qty].filter { !$0.isEmpty }.joined(separator: " ")
            return joined.isEmpty ? nil : joined
        }()

        guard room != nil || content != nil else {
            return .clarify("请补充送到哪里、送什么，例如：今晚8点给302送两箱怡宝")
        }

        let args = DeliveryArguments(
            customer: room,
            roomOrAddress: room,
            phone: phone,
            content: content,
            goodsName: goodsName.isEmpty ? nil : goodsName,
            quantity: quantityText,
            deliveryTime: deliveryTime,
            deliveryTimeText: deliveryTimeText,
            note: nil
        )
        return .tool(.createDelivery(args))
    }

    // MARK: - 工具

    private func firstMatch(_ regex: NSRegularExpression?, in text: String) -> String? {
        guard let regex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range, in: text) else { return nil }
        return String(text[r])
    }
}
