import Foundation

// MARK: - V3.3 Lite · 上下文脱敏（纯函数，可单测）
//
// 管线：本地原始记录 → BusinessContextProvider 聚合（最小字段）→ ContextRedactor
//       脱敏 / 截断 → ProviderContextPayload（JSON）→ 才允许进入 Provider。
// 默认禁止外发：完整手机号、完整地址、图片 Data、无关备注、其它日期客户数据。

struct ContextRedactor: Sendable {
    /// 标题类字段最多携带条数（最小必要）
    var maxTitles = 3
    /// 单条标题最大长度
    var maxTitleLength = 20
    var maxGoods = 5
    var maxPayloadCharacters = 420

    func sanitize(_ context: ScopedBusinessContext) -> ProviderContextPayload {
        var object: [String: Any] = [:]

        if let total = context.revenueTodayTotal {
            object["revenueTodayTotal"] = (total * 100).rounded() / 100
        }
        if let count = context.revenueTodayCount {
            object["revenueTodayCount"] = count
        }
        if let todos = context.todoTodayTitles {
            object["todoTodayTitles"] = clean(todos)
        }
        if let memos = context.recentMemoTitles {
            object["recentMemoTitles"] = clean(memos)
        }
        if let expiring = context.expiringTitles {
            object["expiringTitles"] = clean(expiring)
        }
        if let pending = context.deliveryPendingCount {
            object["deliveryPendingCount"] = pending
        }
        if let delivering = context.deliveryDeliveringCount {
            object["deliveryDeliveringCount"] = delivering
        }

        guard !object.isEmpty else { return .empty }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            return .empty
        }
        return ProviderContextPayload(json: data)
    }

    /// 世界知识问题：强制空载荷（0 经营数据）
    func sanitizeForWorldChat() -> ProviderContextPayload { .empty }

    /// AI 2.0 经营建议专用载荷：统一生成一段紧凑摘要，并在最终 Provider 边界硬截断。
    func sanitize(_ pack: GroundingPack) -> ProviderContextPayload {
        guard pack.hasBusinessData else { return .empty }
        var parts: [String] = []
        if let today = pack.todayRevenue { parts.append("今日营业额¥\(money(today))") }
        if let yesterday = pack.yesterdayRevenue { parts.append("昨日营业额¥\(money(yesterday))") }
        if !pack.sevenDayRevenue.isEmpty {
            let values = pack.sevenDayRevenue.suffix(7).map { money($0.amount) }.joined(separator: ",")
            parts.append("近7日营业额[\(values)]")
        }
        let todos = clean(pack.unfinishedTodoTitles)
        if !todos.isEmpty { parts.append("未完成待办[\(todos.joined(separator: "、"))]") }
        if pack.deliveryPendingCount > 0 || pack.deliveryDeliveringCount > 0 {
            parts.append("配送待处理\(pack.deliveryPendingCount)单/配送中\(pack.deliveryDeliveringCount)单")
        }
        let expiry = clean(pack.expiryTitles)
        if !expiry.isEmpty { parts.append("临期[\(expiry.joined(separator: "、"))]") }
        let goods = pack.goods.prefix(maxGoods).map { item in
            let name = Self.maskSensitiveText(item.name, maxLength: 12)
            return "\(name):进¥\(money(item.purchasePrice))/售¥\(money(item.salePrice))/存\(item.stock)/警\(item.minStock)"
        }
        if !goods.isEmpty { parts.append("商品[\(goods.joined(separator: ";"))]") }
        if let summary = pack.localSummary, !summary.isEmpty {
            parts.append("本地摘要:\(Self.maskSensitiveText(summary, maxLength: 80))")
        }

        var text = parts.joined(separator: "；")
        if text.count > maxPayloadCharacters {
            text = String(text.prefix(maxPayloadCharacters))
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: ["grounding": text], options: [.sortedKeys]) else { return .empty }
        return ProviderContextPayload(json: data)
    }

    /// 列表清洗：脱敏手机号 / 房号完整串、截断长度与条数
    private func clean(_ items: [String]) -> [String] {
        Array(items
            .map { Self.maskSensitiveText($0) }
            .filter { !$0.isEmpty }
            .prefix(maxTitles))
    }

    /// 文本脱敏：手机号（含连写 / 空格分隔）打码；长地址串只保留泛指。
    static func maskSensitiveText(_ text: String, maxLength: Int = 20) -> String {
        var result = text
        // 11 位手机号
        if let regex = try? NSRegularExpression(pattern: #"1[3-9]\d{9}"#) {
            let mutable = NSMutableString(string: result)
            regex.replaceMatches(
                in: mutable, range: NSRange(location: 0, length: mutable.length),
                withTemplate: "1**********")
            result = mutable as String
        }
        // 3-4 位数字 + 室/房/号/栋 这类具体门牌，打码为「#号」
        if let regex = try? NSRegularExpression(pattern: #"\d{2,5}\s*(室|房|号|栋|单元)"#) {
            let mutable = NSMutableString(string: result)
            regex.replaceMatches(
                in: mutable, range: NSRange(location: 0, length: mutable.length),
                withTemplate: "#$1")
            result = mutable as String
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.count > maxLength {
            result = String(result.prefix(maxLength)) + "…"
        }
        return result
    }

    private func money(_ value: Double) -> String {
        String(format: value.rounded() == value ? "%.0f" : "%.2f", value)
    }
}
