import Foundation

// MARK: - V3.3 Lite · 意图分类（纯规则、0 Token、可单测）
//
// Foundation 阶段先用本地规则做意图分流，这也是 Free First 的第一道闸：
// - worldChat：普通世界知识，BusinessContext 必须为空（0 经营数据外发）；
// - businessQuery：本地聚合能回答的经营问答（FINAL 走 searchRecords + 隐私裁剪）；
// - businessAction：结构化 CREATE，进入 ActionCard 确认；
// 真正的语义解析在 FINAL 由 Provider 完成；此处只做分类与路由，不做最终字段抽取。

enum IntentKind: Equatable, Sendable {
    /// 本地可直接处理（Lite 预留，0 Token）
    case localZeroToken
    /// 经营写动作（CREATE，必须确认）
    case businessAction(ToolName)
    /// 经营读问答（READ，结果经隐私裁剪）
    case businessQuery(BusinessRecordKind)
    /// 普通聊天 / 世界知识（不带经营数据）
    case worldChat
    /// 实时外部信息查询（天气等）：本版本没有对应工具，本地直接明确告知（0 Token）
    case weatherQuery
    /// 店内商品 READ，不生成 ActionCard
    case goodsQuery(String)
}

struct IntentRouter {
    /// 金额正则：阿拉伯数字或中文数字 + 可选 元/块
    private static let amountRegex = try? NSRegularExpression(
        pattern: #"(?:\d+(?:\.\d+)?|[一二两三四五六七八九十百千万零]+)\s*(?:元|块|块钱|圆)?"#)

    /// 房号 / 客户号：2~5 位数字，或 “302室/房/号”
    private static let roomRegex = try? NSRegularExpression(
        pattern: #"\d{2,5}\s*(?:室|房|号|栋|单元)?"#)

    private static let revenueKeywords = [
        "营业额", "营收", "收入", "卖了", "收款", "入账", "营业额",
        "美团", "饿了么", "微信", "支付宝", "现金", "扫呗", "抖音", "快手", "团购", "到账"
    ]
    private static let deliveryKeywords = ["配送", "送货", "送到", "送水", "跑腿"]
    private static let memoKeywords = ["记一下", "记录一下", "备忘", "备注", "供应商", "记一笔"]
    private static let queryKeywords = [
        "多少", "几单", "几件", "几条", "几个", "有什么", "还有", "？", "?",
        // P0-1 / P0-4：先判「问」再判「记」——出现疑问词时不能仅因时间词就落 CREATE
        "什么", "怎么", "为什么", "哪", "吗", "呢", "查"
    ]
    /// 实时天气类外部信息（本版本没有天气工具，命中即明确告知，绝不出待办 / 备忘卡）
    private static let weatherKeywords = [
        "天气", "天气预报", "气温", "多少度", "几度",
        "下雨", "会下雨", "降雨", "降水", "台风", "冷不冷", "热不热"
    ]
    /// 命中天气词的同时若出现这些 CREATE 词，仍按经营记录处理（如「提醒我看天气」）
    private static let createCueWords = ["记一下", "记录", "备忘", "备注", "提醒", "待办", "记得"]

    func classify(_ raw: String, now: Date = Date()) -> IntentKind {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .worldChat }

        // 0) 实时外部信息查询（天气）优先于一切 CREATE：
        //    「明天恩平什么天气啊，帮我查下」是 READ，不是「明天 + 新建待办」。
        if isWeatherQuery(text) { return .weatherQuery }

        if isGoodsQuery(text) { return .goodsQuery(text) }

        // 1) 经营读问答优先（避免“今天还有几单配送”被当成新建配送）
        if let query = classifyQuery(text) { return query }

        // 2) 营业额：含来源 / 收款语义，且（有金额 或 有明确收款动作词）
        //    只有来源词没有金额（如“美团怎么开店”）不当成记账，交给后续分类 / worldChat
        let revenueActionCues = ["营业额", "营收", "收入", "卖了", "收款", "入账", "到账"]
        if Self.revenueKeywords.contains(where: { text.contains($0) }),
           hasAmount(text) || revenueActionCues.contains(where: { text.contains($0) }) {
            return .businessAction(.recordRevenue)
        }

        // 3) 配送：含“送”语义且能找到房号 / 客户号
        if isDelivery(text) {
            return .businessAction(.createDelivery)
        }

        // 4) 备忘（“记一下供应商周五来”）先于待办
        if Self.memoKeywords.contains(where: { text.contains($0) }) {
            return .businessAction(.createMemo)
        }

        // 5) 待办：未来时间 / 动作词
        if isTodo(text) {
            return .businessAction(.createTodo)
        }

        // 6) 兜底：普通聊天（不携带任何经营数据）
        return .worldChat
    }

    // MARK: 分类依据（纯函数，亦可被解析层复用）

    func hasAmount(_ text: String) -> Bool {
        guard let regex = Self.amountRegex else { return false }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range, in: text) else { return false }
        let token = String(text[r])
        // 纯中文日期词（如“周五”）不算金额
        let stripped = token.replacingOccurrences(
            of: "[元块圆\\s]", with: "", options: .regularExpression)
        if let value = Double(stripped) { return value > 0 }
        if let cn = ChineseNumber.parse(stripped) { return cn > 0 }
        return false
    }

    /// 街道式地址：「到幸福路9号」「送至解放大道128号3栋」等（必须有 到/送至/地址 引导，
    /// 与纯数字房号、时间、金额区分）
    private static let streetAddressRegex = try? NSRegularExpression(
        pattern: #"(?:到|去|送至|送到|送往|地址是|地址为|地址[:：]?)\s*([一-龥A-Za-z][一-龥A-Za-z0-9]{0,15}?(?:路|街|巷|大道|村|小区|花园|大厦|广场|苑|城)\s*\d{0,4}\s*(?:号|幢|栋)?(?:\s*\d{1,4}\s*(?:室|房|单元|楼))?)"#)

    func isDelivery(_ text: String) -> Bool {
        let hasVerb = text.contains("送") || Self.deliveryKeywords.contains(where: { text.contains($0) })
        guard hasVerb else { return false }
        // 「送…到幸福路9号」：出现街道式地址即配送
        if streetAddress(in: text) != nil { return true }
        // 「给阿东送…」：中文人名 + 送（无房号也是配送）
        if text.range(of: #"给\s*[一-龥]{2,4}\s*送"#, options: .regularExpression) != nil { return true }
        // “给302送…” / “送…到302” / 含 室|房|号
        if text.contains("给"), let _ = firstRoomNumber(in: text) { return true }
        if firstRoomNumber(in: text) != nil,
           text.range(of: #"\d{2,5}\s*(室|房|号|栋|单元)"#, options: .regularExpression) != nil {
            return true
        }
        if Self.deliveryKeywords.contains(where: { text.contains($0) }) { return true }
        return false
    }

    /// 提取街道式地址（无则 nil）。仅供配送判定 / 解析层复用。
    func streetAddress(in text: String) -> String? {
        guard let regex = Self.streetAddressRegex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func firstRoomNumber(in text: String) -> String? {
        guard let regex = Self.roomRegex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range, in: text) else { return nil }
        return String(text[r])
    }

    private func isTodo(_ text: String) -> Bool {
        let timeMarkers = ["今天", "明天", "后天", "下周", "周一", "周二", "周三", "周四",
                           "周五", "周六", "周日", "周末", "月底", "早上", "晚上", "下午", "上午"]
        let actionMarkers = ["记得", "提醒", "下货", "下单", "进货", "补货", "买", "带",
                             "联系", "打电话", "收拾", "整理", "安排", "要做", "跟进"]
        return timeMarkers.contains(where: { text.contains($0) })
            || actionMarkers.contains(where: { text.contains($0) })
    }

    /// 天气等实时外部查询：含天气类词，且不是「记/提醒/备忘」式 CREATE。
    /// 「明天恩平什么天气啊，帮我查下」→ true；「提醒我明天看天气」→ false。
    private func isWeatherQuery(_ text: String) -> Bool {
        guard Self.weatherKeywords.contains(where: { text.contains($0) }) else { return false }
        if Self.createCueWords.contains(where: { text.contains($0) }) { return false }
        return true
    }

    private func isGoodsQuery(_ text: String) -> Bool {
        // 解释 / 定义类问题讨论经营概念，不是在查询店内某个商品。
        // 先排除这些知识问法，避免“什么是毛利率”等问题被“毛利” marker 截走。
        let explanationPhrases = ["什么是", "是什么", "是什么意思", "怎么计算", "如何计算", "怎么提高", "如何提高"]
        guard !explanationPhrases.contains(where: { text.contains($0) }) else { return false }

        let markers = ["多少钱", "进价", "售价", "库存", "毛利", "有没有", "还有多少"]
        guard markers.contains(where: { text.contains($0) }) else { return false }
        let nonGoodsPhrases = ["天气", "配送", "送货", "待办", "备忘", "临期", "过期", "明显下降", "什么问题"]
        return !nonGoodsPhrases.contains(where: { text.contains($0) })
    }

    private func classifyQuery(_ text: String) -> IntentKind? {
        let asks = Self.queryKeywords.contains(where: { text.contains($0) })
        let looksQuestion = asks || text.hasSuffix("吗")
        guard looksQuestion else { return nil }
        if text.contains("营业额") || text.contains("卖了") || text.contains("收入") || text.contains("营收") {
            return .businessQuery(.revenueToday)
        }
        if text.contains("配送") || text.contains("送货") || text.contains("送水") || text.contains("几单") {
            return .businessQuery(.delivery)
        }
        if text.contains("临期") || text.contains("过期") || text.contains("到期")
            || text.contains("保质期") || text.contains("退货") {
            return .businessQuery(.expiringGoods)
        }
        if text.contains("待办") || text.contains("事项") || text.contains("要做") || text.contains("任务") {
            return .businessQuery(.todoToday)
        }
        if text.contains("备忘") || text.contains("记过") || text.contains("笔记") {
            return .businessQuery(.recentMemo)
        }
        // 是问句但不属于店内经营实体：交云端正常回答。
        // 关键：此时即便句中含「明天」等时间词，也绝不能继续落入 CREATE（P0-1 / P0-4）。
        return .worldChat
    }
}
