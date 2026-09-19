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

    private static let phoneRegex = try? NSRegularExpression(pattern: #"1\d{10}"#)
    private static let timeTextRegex = try? NSRegularExpression(
        pattern: #"(今天|明天|后天|今晚|明晚)?\s*(凌晨|早上|早晨|上午|中午|下午|傍晚|晚上|晚间)?\s*\d{1,2}\s*[点:：]\s*\d{0,2}\s*分?"#)
    /// 「一共45元 / 共45元 / 45元 / 45块」——只认真钱，不会把「8点」「3杯」「9号」当金额
    private static let amountRegex = try? NSRegularExpression(
        pattern: #"(?:一共|共|合计)?\s*(\d+(?:\.\d+)?)\s*(?:元|块|块钱)"#)
    /// 「给302送」中的纯数字房号（不匹配「幸福路9号」「45元」）
    private static let roomAfterGeiRegex = try? NSRegularExpression(pattern: #"给\s*(\d{2,5})\s*送"#)
    /// 「送到302室 / 送至12栋」中的数字房号
    private static let roomAfterDaoRegex = try? NSRegularExpression(
        pattern: #"(?:到|去|送至|送到|送往)\s*(\d{2,5}\s*(?:室|房|号|幢|栋|单元)?)"#)
    /// 「给阿东送」「客户阿东」中的中文人名
    private static let namedCustomerRegex = try? NSRegularExpression(
        pattern: #"(?:给\s*|客户\s*[:：是]?\s*|客人\s*[:：是]?\s*|顾客\s*[:：是]?\s*)([一-龥]{2,4})\s*送"#)
    /// 带单位商品：3杯 / 两箱 / 12瓶（杯为 P0-2 真机词，单位表必须包含）
    private static let itemWithUnitRegex = try? NSRegularExpression(
        pattern: #"([0-9]+|[一二两三四五六七八九十]+)\s*(杯|箱|件|瓶|袋|个|份|包|条|桶|提|扎|盒|罐|打|套|支|只)"#)
    /// 「百年糊涂×2 / 王老吉 x3」式多商品
    private static let crossItemRegex = try? NSRegularExpression(
        pattern: #"([一-龥A-Za-z][一-龥A-Za-z0-9]{0,9})\s*[×xX*]\s*([0-9]+)"#)

    private struct DeliveryItem: Equatable {
        let name: String
        let quantity: String
    }

    /// 仅处理 businessAction；businessQuery / worldChat / 外部查询返回 nil
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
        case .businessQuery, .worldChat, .localZeroToken, .weatherQuery, .goodsQuery:
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
        // “今晚/明晚”不是 resolve 认识的“晚上”，先归一化
        let normalized = text
            .replacingOccurrences(of: "今晚", with: "今天晚上")
            .replacingOccurrences(of: "明晚", with: "明天晚上")

        // P0-3：「明天3点」这类裸数字点有歧义，必须追问「凌晨还是下午」，
        // 绝不允许静默回落当前时间。
        switch DatePhraseParser.resolve(normalized, now: now) {
        case .some(.ambiguousClock(let token)):
            return .clarify("你说的「\(token)」是凌晨\(token)还是下午\(token)？请补充时段，例如「明天下午3点」。")
        default:
            break
        }
        let due: Date? = {
            if case .some(.date(let d)) = DatePhraseParser.resolve(normalized, now: now) { return d }
            return nil
        }()

        var title = text
        // 剥掉命中的整段时间原文（如「明天下午3点」），避免标题残留时间
        if let timeText = firstMatch(Self.timeTextRegex, in: text) {
            title = title.replacingOccurrences(of: timeText, with: "")
        }
        let patterns = [
            "今天", "明天", "后天", "下周", "周末", "月底",
            "周一", "周二", "周三", "周四", "周五", "周六", "周日",
            "星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期天",
            "今晚", "明晚", "凌晨", "早上", "早晨", "上午", "中午", "下午", "傍晚", "晚上",
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
        // “今晚”不是 resolve 认识的“晚上”，先归一化再解析时间
        let normalized = text
            .replacingOccurrences(of: "今晚", with: "今天晚上")
            .replacingOccurrences(of: "明晚", with: "明天晚上")

        // P0-2：配送时间同样不允许歧义回落（「3点」必须追问，不得用当前时间）
        var deliveryTime: Date?
        switch DatePhraseParser.resolve(normalized, now: now) {
        case .some(.date(let d)):
            deliveryTime = d
        case .some(.ambiguousClock(let token)):
            return .clarify("你说的「\(token)」是凌晨\(token)还是下午\(token)？请补充时段，例如「晚上8点」。")
        case .none:
            deliveryTime = nil
        }
        // 时间原文取用户原始说法（如「今晚8点」）
        let deliveryTimeText = firstMatch(Self.timeTextRegex, in: text)

        let phone = firstMatch(Self.phoneRegex, in: text)
        let amount = firstAmount(in: text)

        // 地址：街道地址（幸福路9号）与纯数字房号（给302送 / 送到302室）严格区分
        let streetAddress = router.streetAddress(in: text)
        let namedCustomer = firstNamedCustomer(in: text)
        let roomAfterGei = firstMatch(Self.roomAfterGeiRegex, captureGroup: 1, in: text)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let roomAfterDao = firstMatch(Self.roomAfterDaoRegex, captureGroup: 1, in: text)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // customer：只接受明确人名；无名时留空（P0-2 真机句 customer 必须为空）。
        // 旧范例「给302送」沿用历史行为：纯数字房号同时作为客户标识与房号。
        let customer = namedCustomer ?? roomAfterGei
        let roomOrAddress = streetAddress
            ?? roomAfterDao
            ?? (namedCustomer == nil && roomAfterGei != nil ? roomAfterGei : nil)

        let items = extractItems(in: text)
        let quantityText = items.first?.quantity
        let goodsName = items.first?.name
        let content: String? = items.isEmpty
            ? nil
            : items.map { item in
                [item.name, item.quantity].filter { !$0.isEmpty }.joined(separator: " ")
            }.joined(separator: "、")

        guard roomOrAddress != nil || content != nil else {
            return .clarify("配送需要地址或商品，例如「今晚8点送3杯珍珠奶茶到幸福路9号，一共45元」。")
        }

        return .tool(.createDelivery(DeliveryArguments(
            customer: customer,
            roomOrAddress: roomOrAddress,
            phone: phone,
            content: content,
            goodsName: goodsName,
            quantity: quantityText,
            deliveryTime: deliveryTime,
            deliveryTimeText: deliveryTimeText,
            note: nil,
            amount: amount
        )))
    }

    // MARK: - 配送字段提取（P0-2）

    private func firstAmount(in text: String) -> Double? {
        guard let regex = Self.amountRegex,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(match.range(at: 1), in: text),
              let value = Double(text[r]), value > 0 else { return nil }
        return value
    }

    private func firstNamedCustomer(in text: String) -> String? {
        guard let regex = Self.namedCustomerRegex,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 抽取商品行：优先「商品×N」式（可多行），否则「N + 单位 + 商品名」。
    /// 只在「送」之后的正文里抽（避免把「给阿东送」「今晚8点」抓成商品）；
    /// 商品出现在「送到」之前的少数语序再回退全文。
    private func extractItems(in text: String) -> [DeliveryItem] {
        let body: String = {
            if let range = text.range(of: "送") { return String(text[range.upperBound...]) }
            return text
        }()
        if let items = extractItemMatches(in: body), !items.isEmpty { return items }
        return extractItemMatches(in: text) ?? []
    }

    private func extractItemMatches(in text: String) -> [DeliveryItem]? {
        let fullRange = NSRange(text.startIndex..., in: text)

        if let cross = Self.crossItemRegex {
            let matches = cross.matches(in: text, range: fullRange)
            if !matches.isEmpty {
                return matches.compactMap { match in
                    guard let nameRange = Range(match.range(at: 1), in: text),
                          let numRange = Range(match.range(at: 2), in: text) else { return nil }
                    return DeliveryItem(name: String(text[nameRange]),
                                        quantity: "×" + String(text[numRange]))
                }
            }
        }

        guard let regex = Self.itemWithUnitRegex else { return [] }
        let matches = regex.matches(in: text, range: fullRange)
        guard !matches.isEmpty else { return nil }
        return matches.map { match in
            let quantity: String = {
                if let r = Range(match.range, in: text) { return String(text[r]) }
                return ""
            }()
            // 数量+单位之后的连续中英文 / 数字即商品名，遇到 到/去/送/标点/下一串数字 即止
            var name = ""
            if let r = Range(match.range, in: text) {
                for ch in text[r.upperBound...] {
                    if "到去送，,。；;（()） \n\t".contains(ch) { break }
                    if ch.isNumber && !name.isEmpty { break }
                    name.append(ch)
                }
            }
            name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return DeliveryItem(name: name, quantity: quantity)
        }
    }

    // MARK: - 工具

    private func firstMatch(_ regex: NSRegularExpression?, in text: String) -> String? {
        guard let regex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range, in: text) else { return nil }
        return String(text[r])
    }

    private func firstMatch(_ regex: NSRegularExpression?, captureGroup: Int, in text: String) -> String? {
        guard let regex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: captureGroup), in: text) else { return nil }
        return String(text[r])
    }
}
