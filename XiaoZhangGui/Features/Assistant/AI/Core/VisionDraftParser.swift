import Foundation

// MARK: - V3.9.2 · 识别文字 → 记账草稿（V3.9.3 支出语义改道）
//
// 图片/文件识别出来的文字，先过一遍本地规则：能读成业务写动作就生成**待确认**草稿
// （0 Token、不猜参数、不写库），读不成动作就照旧只回文字。
//
// 安全边界（比"能识别"更重要）：
// - 只产出待确认草稿，真正落库仍要用户在 ActionCard 上点确认；
// - 12 词阻断表一字不改（进货/采购/支出/付款/付了/退款/退货/报销/工资/房租/水电/买入）。
//   V3.9.3 决策：支出语义不再「不出卡」，而是改出**支出类型**草稿卡（recordExpense，
//   写 Expense 表）；收入草稿对这 12 词仍被阻断——支出绝不能记成收入。
// - 多金额单据：无「一共/合计」类总计标记时不猜、不相加，改由调用方请用户选择。
enum VisionDraftParser {

    /// 明显支出语义：方向绝不能记反。12 词阻断表，V3.9.3 一字不改。
    private static let expenseCues = [
        "进货", "采购", "支出", "付款", "付了", "退款", "退货", "报销", "工资", "房租", "水电", "买入"
    ]

    private static let totalMarkers = ["一共", "共计", "合计", "总计", "总金额"]

    private static let amountRegex = try? NSRegularExpression(
        pattern: #"(?:¥|￥)?\s*(\d+(?:\.\d+)?)\s*(?:元|块|块钱)"#)
    private static let totalAmountRegex = try? NSRegularExpression(
        pattern: #"(?:一共|共计|合计|总计|总金额)\s*(?:¥|￥)?\s*(\d+(?:\.\d+)?)\s*(?:元|块|块钱)?"#)

    /// 从识别文字里推出一个待确认的工具调用；拿不准就返回 nil（调用方照常回文字）。
    static func draftToolCall(from text: String, now: Date = Date()) -> ToolCall? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // 支出语义 → 支出草稿卡（绝不生成收入卡）；无金额时返回 nil，调用方追问。
        if expenseCues.contains(where: { trimmed.contains($0) }) {
            return expenseDraft(from: trimmed, now: now)
        }

        let intent = IntentRouter().classify(trimmed, now: now)
        guard case .businessAction(let tool) = intent else { return nil }
        guard let parsed = LocalBusinessParser().parse(trimmed, intent: intent, now: now),
              case .tool(let arguments) = parsed else { return nil }
        return ToolCall(id: ToolCall.makeID(), name: tool, arguments: arguments)
    }

    /// 支出草稿：类别取文本中最先出现的阻断词；金额优先取总计标记后的数字，
    /// 否则取第一个带「元/块」的阿拉伯数字；无金额返回 nil。
    static func expenseDraft(from text: String, now: Date = Date()) -> ToolCall? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let cue = expenseCues
            .compactMap({ cue -> (String, String.Index)? in
                guard let range = trimmed.range(of: cue) else { return nil }
                return (cue, range.lowerBound)
            })
            .min(by: { $0.1 < $1.1 })?.0 else { return nil }
        let amounts = arabicAmounts(in: trimmed)
        guard !amounts.isEmpty else { return nil }
        let amount: Double
        if totalMarkers.contains(where: { trimmed.contains($0) }),
           let total = firstMatch(Self.totalAmountRegex, in: trimmed),
           let value = Double(total) {
            amount = value
        } else {
            amount = amounts[0]
        }
        guard amount > 0 else { return nil }
        let category: String = {
            switch cue {
            case "付款", "付了": return "付款"
            default: return cue
            }
        }()
        return ToolCall(
            id: ToolCall.makeID(),
            name: .recordExpense,
            arguments: .recordExpense(ExpenseArguments(
                amount: amount,
                category: category,
                date: now,
                note: String(trimmed.prefix(80))
            )))
    }

    // MARK: - 置信度评估（B 功能：多金额请用户选择，严禁相加）

    enum Confidence: Equatable, Sendable {
        case high
        case low
    }

    struct Assessment: Equatable, Sendable {
        var draft: ToolCall?
        var confidence: Confidence
        /// 文本中出现的不重复金额（仅阿拉伯数字 + 元/块；中文数字金额不在此列）。
        var ambiguousAmounts: [Double]
        /// ok / multiAmount / unparsed / empty
        var reason: String
    }

    /// 评估一次识别文字：多金额且无总计标记时不出卡、返回全部候选金额，
    /// 调用方必须请用户选择其一；其余情况与 draftToolCall 一致。
    static func assess(from text: String, now: Date = Date()) -> Assessment {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Assessment(draft: nil, confidence: .low, ambiguousAmounts: [], reason: "empty")
        }
        let amounts = arabicAmounts(in: trimmed)
        let distinct = Array(Set(amounts)).sorted()
        if distinct.count >= 2,
           !totalMarkers.contains(where: { trimmed.contains($0) }) {
            return Assessment(draft: nil, confidence: .low, ambiguousAmounts: distinct, reason: "multiAmount")
        }
        guard let draft = draftToolCall(from: trimmed, now: now) else {
            return Assessment(draft: nil, confidence: .low, ambiguousAmounts: distinct, reason: "unparsed")
        }
        return Assessment(draft: draft, confidence: .high, ambiguousAmounts: distinct, reason: "ok")
    }

    // MARK: - 私有

    /// 文本中全部带「元/块」的阿拉伯数字金额（按出现顺序；房号/时间/数量不带此单位，不会混入）。
    static func arabicAmounts(in text: String) -> [Double] {
        guard let regex = amountRegex else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: text) else { return nil }
            return Double(text[r])
        }
    }

    private static func firstMatch(_ regex: NSRegularExpression?, in text: String) -> String? {
        guard let regex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}
