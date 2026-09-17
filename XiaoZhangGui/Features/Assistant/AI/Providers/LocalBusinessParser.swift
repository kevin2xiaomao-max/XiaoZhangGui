import Foundation

// MARK: - V3.3 Lite · 本地业务解析（Free First · 0 Token）
//
// AI REAL 起，Foundation 阶段在 MockBusinessParser 中验证过的四范例解析规则
// 产品化为正式本地层（同一套 AmountPhraseParser / DatePhraseParser / ChineseNumber）：
// - 命中高置信规则时直接产出 ToolArguments（0 Token），由 AgentCore 直接出 ActionCard；
// - 信息不足时产出 .clarify 追问（仍 0 Token）；
// - 返回 nil 表示本地无把握，才允许上云（DeepSeek / fallback）。
// 纯规则、无网络、无 Key 依赖；未配置 API Key 时本地 CREATE 照常工作。

enum LocalParseResult: Equatable, Sendable {
    /// 高置信：直接生成结构化动作
    case tool(ToolArguments)
    /// 识别到意图但信息不足，追问用户补充（绝不脑补缺失字段）
    case clarify(String)
}

struct LocalBusinessParser {
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

    /// 仅处理 businessAction；businessQuery / worldChat 返回 nil
    /// （查询走本地聚合回答，普通聊天走云端）。
    func parse(_ raw: String, intent: IntentKind, now: Date = Date()) -> LocalParseResult? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        switch intent {
        case .businessAction(let tool):
            switch tool {
            case .recordRevenue: return parseRevenue(text, now: now)
            case .createTodo: return parseTodo(text, now: now)
            case .createMemo: return parseMemo(text)
            case .createDelivery: return parseDelivery(text, now: now)
            case .searchRecords: return nil
            }
        case .businessQuery, .worldChat, .localZeroToken:
            return nil
        }
    }

    // MARK: 营业额

    private func parseRevenue(_ text: String, now: Date) -> LocalParseResult {
        guard let amount = AmountPhraseParser.parse(text), amount > 0 else {
            return .clarify("记营业额需要金额，例如「今天美团680」。")
        }
        let source = Self.revenueSources.first(where: { text.contains($0) })
        let date = DatePhraseParser.parse(text, now: now) ?? now
        return .tool(.recordRevenue(RevenueArguments(
            amount: amount,
            source: source,
            date: date,
            note: source == nil ? text : nil
        )))
    }

    // MARK: 待办

    private func parseTodo(_ text: String, now: Date) -> LocalParseResult {
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
            return .clarify("待办内容是什么？例如「明天下两箱可乐」。")
        }
        return .tool(.createTodo(TodoArguments(title: title, detail: text, dueDate: due, priority: 0)))
    }

    // MARK: 备忘

    private func parseMemo(_ text: String) -> LocalParseResult {
        var title = text
        for prefix in ["帮我记一下", "帮我记录一下", "记录一下", "记一下", "记一笔",
                       "备忘", "备注", "帮我记", "记个"] {
            if title.hasPrefix(prefix) { title = String(title.dropFirst(prefix.count)) }
        }
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: " ，,。.:："))
        guard !title.isEmpty else {
            return .clarify("备忘内容是什么？例如「记一下供应商周五来」。")
        }
        return .tool(.createMemo(MemoArguments(title: String(title.prefix(20)), content: text)))
    }

    // MARK: 配送

    private func parseDelivery(_ text: String, now: Date) -> LocalParseResult {
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
            return .clarify("配送需要客户房号或商品，例如「今晚8点给302送两箱怡宝」。")
        }

        return .tool(.createDelivery(DeliveryArguments(
            customer: room,
            roomOrAddress: room,
            phone: phone,
            content: content,
            goodsName: goodsName.isEmpty ? nil : goodsName,
            quantity: quantityText,
            deliveryTime: deliveryTime,
            deliveryTimeText: deliveryTimeText,
            note: nil
        )))
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
