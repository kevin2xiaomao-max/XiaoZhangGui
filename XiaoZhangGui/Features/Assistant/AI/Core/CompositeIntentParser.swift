import Foundation

// MARK: - V3.9.3 C · 复合意图拆分（纯函数、0 Token、可单测）
//
// 一句话拆成多张待确认卡：
// - 按 ；，。/ 另外 / 还有 / 顺便 / 并且 / 然后 / 接着 切分；每段独立走
//   IntentRouter + LocalBusinessParser（复用单意图规则，不重写解析）；
// - 「完成 / 送到 / 配送完成」类推进语义直接构造 completeTodo / advanceDelivery 调用；
// - 金额独立成段（「一共 45 元」）时合并进上一张卡，绝不另起一卡、绝不相加；
// - 缺失时间 / 房号 / 数量时不出猜测卡，改出补齐提示（clarifications）；
// - 不扩充配送状态枚举，不发消息；「明天」按本地时间由 DatePhraseParser 解释（含跨午夜）。
// - 本解析器只产出调用与提示；是否落库永远由 ActionCard 确认 + 既有执行链决定。
struct CompositeIntentParser {

    struct Result: Equatable, Sendable {
        var calls: [ToolCall]
        var clarifications: [String]
    }

    private static let separators = ["；", "，", "。", "另外", "还有", "顺便", "并且", "然后", "接着"]
    private static let leadingConnectors = ["再", "然后", "接着", "还有", "另外", "顺便", "并且", "并"]

    private static let amountOnlyRegex = try? NSRegularExpression(
        pattern: #"^\s*(?:一共|合计|共计|总计)?\s*(\d+(?:\.\d+)?)\s*(?:元|块|块钱)\s*$"#)

    /// 拆分并解析；单段、零调用时调用方应回落原有单意图链路（本函数不改变单句行为）。
    static func parse(_ text: String, now: Date = Date()) -> Result {
        let segments = split(text)
        guard segments.count >= 2 || segments.count == 1 else { return Result(calls: [], clarifications: []) }
        var calls: [ToolCall] = []
        var clarifications: [String] = []
        let router = IntentRouter()
        let parser = LocalBusinessParser()

        for rawSegment in segments {
            let segment = rawSegment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !segment.isEmpty else { continue }

            // 金额独立成段：合并进上一张卡（配送金额 / 营业额金额），不另起卡。
            if let amount = amountOnlyValue(segment) {
                if let last = calls.last {
                    switch last.arguments {
                    case .createDelivery(var arguments):
                        if arguments.amount == nil {
                            arguments.amount = amount
                            calls[calls.count - 1] = ToolCall(id: last.id, name: last.name, arguments: .createDelivery(arguments))
                        }
                    case .recordRevenue(var arguments):
                        if arguments.amount == nil {
                            arguments.amount = amount
                            calls[calls.count - 1] = ToolCall(id: last.id, name: last.name, arguments: .recordRevenue(arguments))
                        }
                    default:
                        break
                    }
                    continue
                }
            }

            // 推进语义（先于单意图分类：含查询词的复合句也不应被当成纯查询）。
            if let advance = advanceCall(for: segment, router: router) {
                calls.append(advance)
                continue
            }
            if let complete = completeCall(for: segment) {
                calls.append(complete)
                continue
            }

            let intent = router.classify(segment, now: now)
            guard case .businessAction = intent else {
                // 送货但缺房号/客户：明确提示补齐，不猜单。
                if segment.contains("送"), router.firstRoomNumber(in: segment) == nil,
                   router.streetAddress(in: segment) == nil {
                    clarifications.append("配送缺少客户 / 房号，请补充，例如「给 302 送两箱怡宝」。")
                }
                continue
            }
            guard let parsed = parser.parse(segment, intent: intent, now: now) else { continue }
            switch parsed {
            case .tool(let arguments):
                let call = ToolCall(id: ToolCall.makeID(), name: arguments.toolName, arguments: arguments)
                calls.append(call)
                // 配送缺时间：卡照出，但附带补齐提示（执行前用户可在卡上改）。
                if case .createDelivery(let delivery) = arguments,
                   delivery.deliveryTime == nil,
                   (delivery.deliveryTimeText ?? "").isEmpty {
                    clarifications.append("配送缺少时间，请补充，例如「今晚 8 点」；也可直接在卡上修改时间。")
                }
            case .clarify(let message):
                clarifications.append(message)
            }
        }
        return Result(calls: calls, clarifications: clarifications)
    }

    // MARK: - 切分

    private static func split(_ text: String) -> [String] {
        var normalized = text
        for separator in separators {
            normalized = normalized.replacingOccurrences(of: separator, with: "\n")
        }
        return normalized
            .components(separatedBy: "\n")
            .map { segment in
                var value = segment.trimmingCharacters(in: .whitespacesAndNewlines)
                for connector in leadingConnectors where value.hasPrefix(connector) {
                    value = String(value.dropFirst(connector.count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
                return value
            }
            .filter { !$0.isEmpty }
    }

    private static func amountOnlyValue(_ segment: String) -> Double? {
        guard let regex = amountOnlyRegex else { return nil }
        let range = NSRange(segment.startIndex..., in: segment)
        guard let match = regex.firstMatch(in: segment, range: range),
              let r = Range(match.range(at: 1), in: segment),
              let value = Double(segment[r]), value > 0 else { return nil }
        return value
    }

    // MARK: - 推进语义

    private static func advanceCall(for segment: String, router: IntentRouter) -> ToolCall? {
        let room = router.firstRoomNumber(in: segment)
        let street = router.streetAddress(in: segment)
        let hasDeliveryCompletion = segment.contains("送到") || segment.contains("已送达")
            || segment.contains("配送完成") || segment.contains("送达")
            || (segment.contains("完成") && segment.contains("单"))
        if hasDeliveryCompletion, room != nil || street != nil {
            return ToolCall(
                id: ToolCall.makeID(), name: .advanceDelivery,
                arguments: .advanceDelivery(AdvanceDeliveryArguments(
                    customer: nil, roomOrAddress: room ?? street, goodsKeyword: nil)))
        }
        return nil
    }

    private static func completeCall(for segment: String) -> ToolCall? {
        guard segment.contains("完成") || segment.contains("做完") || segment.contains("搞定") else { return nil }
        // 配送域的「完成」由 advanceCall 处理；含送/配送/单的一律不按待办完成处理，
        // 避免「送到了就改已完成」被误读成标题关键词。
        if segment.contains("送") || segment.contains("配送") || segment.contains("单") { return nil }
        var keyword = segment
        for token in ["把", "完成", "做完", "搞定", "待办", "事项", "了", "这个", "那件", "一下"] {
            keyword = keyword.replacingOccurrences(of: token, with: "")
        }
        keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ，,。"))
        guard !keyword.isEmpty else { return nil }
        return ToolCall(
            id: ToolCall.makeID(), name: .completeTodo,
            arguments: .completeTodo(CompleteTodoArguments(titleKeyword: keyword)))
    }
}
