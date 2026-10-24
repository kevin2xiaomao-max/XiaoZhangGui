import Foundation

// MARK: - V3.9.2 · 识别文字 → 记账草稿
//
// 图片/文件识别出来的文字，先过一遍本地规则：能读成业务写动作就生成**待确认**草稿
// （0 Token、不猜参数、不写库），读不成动作就照旧只回文字。
//
// 安全边界（比"能识别"更重要）：
// - 只产出待确认草稿，真正落库仍要用户在 ActionCard 上点确认；
// - 带支出语义（进货/采购/付款/退款/退货/报销/房租/水电/买）一律不生成卡：
//   当前工具集只有 recordRevenue，把一笔进货记成「收入」比不识别更坏。
enum VisionDraftParser {

    /// 明显支出语义：宁可不识别，也不要把方向记反。
    private static let expenseCues = [
        "进货", "采购", "支出", "付款", "付了", "退款", "退货", "报销", "工资", "房租", "水电", "买入"
    ]

    /// 从识别文字里推出一个待确认的工具调用；拿不准就返回 nil（调用方照常回文字）。
    static func draftToolCall(from text: String, now: Date = Date()) -> ToolCall? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !expenseCues.contains(where: { trimmed.contains($0) }) else { return nil }

        let intent = IntentRouter().classify(trimmed, now: now)
        guard case .businessAction(let tool) = intent else { return nil }
        guard let parsed = LocalBusinessParser().parse(trimmed, intent: intent, now: now),
              case .tool(let arguments) = parsed else { return nil }
        return ToolCall(id: ToolCall.makeID(), name: tool, arguments: arguments)
    }
}
