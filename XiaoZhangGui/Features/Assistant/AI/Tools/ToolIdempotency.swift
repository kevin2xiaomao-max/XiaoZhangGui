import Foundation

// MARK: - V3.3 Lite · 幂等（toolCallID + 业务指纹）
//
// 红线：AI 绝不允许因重复响应 / 重试 / 崩溃恢复把营业额、待办、配送写两次。
// - toolCallID：每次 ToolCall 生成即固定，重试同一调用复用同一 ID；
// - 业务指纹：同一业务内容（金额+日期+来源 / 客户+时间+商品）稳定哈希，
//   对齐现有 Performance.fingerprint 的去重范式；
// Foundation 阶段只计算与判重（预览不写库），FINAL 在 ToolRouter 落库前强制校验。

enum ToolIdempotency {
    static func newCallID() -> String { ToolCall.makeID() }

    /// 业务指纹；查询类不产生业务写入，指纹加 query 前缀仅用于日志去重。
    static func fingerprint(for call: ToolCall) -> String {
        switch call.arguments {
        case .recordRevenue(let a):
            let amount = (a.amount ?? 0).rounded(to: 2)
            return "rev|\(fmt(amount))|\(day(a.date))|\(norm(a.source))|\(norm(a.note))"
        case .createTodo(let a):
            return "todo|\(norm(a.title))|\(minute(a.dueDate))|\(a.priority ?? 0)"
        case .createMemo(let a):
            return "memo|\(norm(a.title))"
        case .createDelivery(let a):
            return "del|\(norm(a.customer))|\(norm(a.roomOrAddress))|\(minute(a.deliveryTime))|\(norm(a.goodsName))|\(norm(a.quantity))"
        case .searchRecords(let a):
            let kinds = a.kinds.map(\.rawValue).sorted().joined(separator: ",")
            return "search|\(kinds)|\(norm(a.query))"
        }
    }

    // MARK: - 私有格式化

    private static func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
    private static func norm(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd"
        return f
    }()
    private static let minuteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMddHHmm"
        return f
    }()
    private static func day(_ date: Date?) -> String {
        guard let date else { return "na" }
        return dayFormatter.string(from: date)
    }
    private static func minute(_ date: Date?) -> String {
        guard let date else { return "na" }
        return minuteFormatter.string(from: date)
    }
}

private extension Double {
    func rounded(to places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
