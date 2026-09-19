import Foundation

// MARK: - V3.3 P0-5 · 多轮纠正识别（纯规则、0 Token）
//
// 真机场景：ActionCard 已挂出一个 pending proposal，用户说
// 「没有，是帮我记录备忘了，是没收到钱」/「不是，改成备忘，没收到钱」。
// 正确处理：旧 proposal 立即失效 → 剥掉纠正话术 → 按新业务类型重新出卡。
// 本文件只负责识别与清洗；取消旧 pending、出卡由 AgentCore 编排。

/// 一次纠正的解析结果。
struct Correction: Equatable, Sendable {
    /// 剥掉纠正话术后的真实业务内容（如「没收到钱」）；可能为空（用户只表达了否定）
    let cleanedText: String
    /// 用户明确点出的新业务类型（如「改成备忘」→ createMemo）；nil 表示交给意图分类器
    let targetTool: ToolName?
}

enum CorrectionParser {
    /// 强纠正信号：仅在句首出现才认可（避免「没有货了再进点」这类正常表达误伤）。
    /// 调用方还应额外确认当前存在 pending proposal。
    private static let strongCues = [
        "不是", "不对", "搞错", "弄错", "错了", "应该是",
        "改成", "改为", "记成", "记为", "换成", "重新记", "没有"
    ]

    /// 纠正框架词（按长度降序替换；只表语气 / 改类型，不含业务内容）
    private static let frameWords = [
        "应该是", "重新记", "搞错了", "搞错", "弄错", "错了",
        "改成", "改为", "记成", "记为", "换成", "不是", "不对",
        "帮我", "记录", "记一下", "记一笔", "记个", "没有",
        "应该", "重新", "这个", "那个", "一条", "一个", "一下"
    ]

    /// 框架剥离后，句首可能残留的虚字（只裁句首，避免误伤正文中的「的 / 了」）
    private static let leadingFiller = CharacterSet(charactersIn: "是了的啊呀吧呢嘛喂，,。.:： ")

    private static let separators = CharacterSet(charactersIn: "，,。；;、 \n\t")

    static func detect(_ raw: String) -> Correction? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let prefix = String(text.prefix(8))
        guard strongCues.contains(where: { prefix.contains($0) }) else { return nil }

        let segments = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var tool: ToolName?
        var contents: [String] = []

        for segment in segments {
            let stripped = stripFrames(segment)
            guard !stripped.isEmpty else { continue }

            if let announced = announcedType(stripped) {
                tool = announced.tool
                let remainder = stripped
                    .replacingOccurrences(of: announced.keyword, with: "")
                    .trimmingCharacters(in: leadingFiller)
                if !remainder.isEmpty { contents.append(remainder) }
            } else {
                contents.append(stripped)
            }
        }

        let cleaned = contents.joined(separator: "，")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Correction(cleanedText: cleaned, targetTool: tool)
    }

    // MARK: 私有

    private static func stripFrames(_ segment: String) -> String {
        var result = segment
        for word in frameWords {
            result = result.replacingOccurrences(of: word, with: "")
        }
        // 反复剥句首虚字与单字「记 / 成」，直到稳定
        var previous: String
        repeat {
            previous = result
            result = result.trimmingCharacters(in: leadingFiller)
            if result.hasPrefix("记") { result = String(result.dropFirst()) }
            if result.hasPrefix("成") { result = String(result.dropFirst()) }
            result = result.trimmingCharacters(in: leadingFiller)
        } while result != previous
        return result
    }

    private static func announcedType(_ stripped: String) -> (tool: ToolName, keyword: String)? {
        // 顺序敏感：备忘先于待办；「收款」要排除「没收到钱」（收款二字不连续，天然安全）
        if stripped.contains("备忘") || stripped.contains("备注") {
            return (.createMemo, stripped.contains("备忘") ? "备忘" : "备注")
        }
        if stripped.contains("待办") { return (.createTodo, "待办") }
        if stripped.contains("提醒") { return (.createTodo, "提醒") }
        if stripped.contains("事项") || stripped.contains("任务") {
            return (.createTodo, stripped.contains("事项") ? "事项" : "任务")
        }
        if stripped.contains("配送") || stripped.contains("送货") || stripped.contains("快递") {
            let keyword = stripped.contains("配送") ? "配送" : (stripped.contains("送货") ? "送货" : "快递")
            return (.createDelivery, keyword)
        }
        if stripped.contains("营业额") || stripped.contains("营收") {
            return (.recordRevenue, stripped.contains("营业额") ? "营业额" : "营收")
        }
        if stripped.contains("收入") || stripped.contains("到账") || stripped.contains("收款") {
            let keyword: String
            if stripped.contains("收入") { keyword = "收入" }
            else if stripped.contains("到账") { keyword = "到账" }
            else { keyword = "收款" }
            return (.recordRevenue, keyword)
        }
        return nil
    }
}

enum PendingFieldCorrection: Equatable, Sendable {
    case update(ToolArguments, String)
    case cancel
    case followUp(String)
}

/// 对单个待确认 ActionCard 做字段级修正；不重新解析整条业务记录，也不触碰数据库。
enum PendingFieldCorrectionParser {
    private static let sources = ["美团", "饿了么", "微信", "支付宝", "现金", "扫呗", "抖音", "快手"]
    private static let numberRegex = try? NSRegularExpression(pattern: #"\d+(?:\.\d+)?"#)

    static func parse(_ raw: String, current: ToolArguments, now: Date = .now) -> PendingFieldCorrection? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if ["取消刚才那个", "取消刚才的", "刚才那个取消", "不要了", "取消这条"].contains(where: text.contains) {
            return .cancel
        }

        switch current {
        case .recordRevenue(var value):
            if text.contains("金额"), lastNumber(in: text) == nil {
                return .followUp("金额要改成多少？")
            }
            if text.contains("不是") || text.contains("金额") || text.contains("改成") || text.contains("改为") {
                if let amount = lastNumber(in: text), amount > 0 {
                    value.amount = amount
                    return .update(.recordRevenue(value), "金额已改为 ¥\(money(amount))，请确认。")
                }
            }
            if text.contains("来源"), let source = sources.first(where: text.contains) {
                value.source = source
                return .update(.recordRevenue(value), "来源已改为\(source)，请确认。")
            }
        case .createTodo(var value):
            if text.contains("改") || text.contains("刚才") {
                switch DatePhraseParser.resolve(text, now: now) {
                case .some(.date(let date)):
                    value.dueDate = date
                    return .update(.createTodo(value), "待办时间已更新，请确认。")
                case .some(.ambiguousClock(let token)):
                    return .followUp("你说的「\(token)」是凌晨还是下午？请补充时段。")
                case .none:
                    if text.contains("时间") || text.contains("日期") {
                        return .followUp("要改成什么时间？")
                    }
                }
            }
        case .createMemo, .createDelivery, .searchRecords:
            break
        }
        return nil
    }

    private static func lastNumber(in text: String) -> Double? {
        guard let regex = numberRegex else { return nil }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard let match = matches.last, let range = Range(match.range, in: text) else { return nil }
        return Double(text[range])
    }

    private static func money(_ value: Double) -> String {
        String(format: value.rounded() == value ? "%.0f" : "%.2f", value)
    }
}

// MARK: - V3.3 P0-6 · 客户订单「未收款」语义检测
//
// 当前 CustomerRequest 模型没有收款状态字段（详见最终报告的 schema 方案）。
// 红线：识别到该语义时只能明确告知 + 等升级，禁止降级成 Todo / Memo，禁止写库。

enum CustomerPaymentIntent {
    /// 未收款的各种口语表达
    static let unpaidPhrases = [
        "没收到钱", "还没收到钱", "没收钱", "还没收钱",
        "没给钱", "还没给钱", "钱还没给", "钱没给",
        "还没付款", "未付款", "未收款", "还没收款",
        "欠款", "欠钱", "欠着", "还欠", "赊账", "赊着", "挂账"
    ]

    /// 表明这笔钱属于「某个客户订单」的语境词
    private static let customerCues = [
        "客人", "客户", "顾客", "这单", "那一单", "这笔", "那笔", "他的单"
    ]

    static func isUnpaidCustomerOrder(_ text: String) -> Bool {
        let unpaid = unpaidPhrases.contains(where: { text.contains($0) })
        let customer = customerCues.contains(where: { text.contains($0) })
        return unpaid && customer
    }

    static let unsupportedMessage =
        "我明白，这是客户这一单「还没收款」。当前版本的客户单还没有收款状态字段，"
        + "我不会把它误记成待办或备忘（本次没有写入任何数据）。下次小升级给客户单加上"
        + "「未收款 / 已收款」后，这里就能直接显示「阿东 · 未收款」。"
}
