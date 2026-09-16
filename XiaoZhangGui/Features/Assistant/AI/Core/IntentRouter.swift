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
    private static let queryKeywords = ["多少", "几单", "几件", "几条", "几个", "有什么", "还有", "？", "?"]

    func classify(_ raw: String, now: Date = Date()) -> IntentKind {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .worldChat }

        // 1) 经营读问答优先（避免“今天还有几单配送”被当成新建配送）
        if let query = classifyQuery(text) { return query }

        // 2) 营业额：含来源 / 收款语义，且（有金额 或 有明确收款动作词）
        //    只有来源词没有金额（如“美团怎么开店”）不当成记账，交给后续分类 / worldChat
        let revenueActionCues = ["营业额", "营收", "收入", "卖了", "收款", "入账", "到账"]
        if revenueKeywords.contains(where: { text.contains($0) }),
           hasAmount(text) || revenueActionCues.contains(where: { text.contains($0) }) {
            return .businessAction(.recordRevenue)
        }

        // 3) 配送：含“送”语义且能找到房号 / 客户号
        if isDelivery(text) {
            return .businessAction(.createDelivery)
        }

        // 4) 备忘（“记一下供应商周五来”）先于待办
        if memoKeywords.contains(where: { text.contains($0) }) {
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

    func isDelivery(_ text: String) -> Bool {
        let hasVerb = text.contains("送") || deliveryKeywords.contains(where: { text.contains($0) })
        guard hasVerb else { return false }
        // “给302送…” / “送…到302” / 含 室|房|号
        if text.contains("给"), let _ = firstRoomNumber(in: text) { return true }
        if firstRoomNumber(in: text) != nil,
           text.range(of: #"\d{2,5}\s*(室|房|号|栋|单元)"#, options: .regularExpression) != nil {
            return true
        }
        if deliveryKeywords.contains(where: { text.contains($0) }) { return true }
        return false
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

    private func classifyQuery(_ text: String) -> IntentKind? {
        let asks = queryKeywords.contains(where: { text.contains($0) })
        let looksQuestion = asks || text.hasSuffix("吗")
        guard looksQuestion else { return nil }
        if text.contains("营业额") || text.contains("卖了") || text.contains("收入") || text.contains("营收") {
            return .businessQuery(.revenueToday)
        }
        if text.contains("配送") || text.contains("送货") || text.contains("送水") || text.contains("几单") {
            return .businessQuery(.delivery)
        }
        if text.contains("待办") || text.contains("事项") || text.contains("要做") || text.contains("任务") {
            return .businessQuery(.todoToday)
        }
        if text.contains("备忘") || text.contains("记过") || text.contains("笔记") {
            return .businessQuery(.recentMemo)
        }
        return nil
    }
}
