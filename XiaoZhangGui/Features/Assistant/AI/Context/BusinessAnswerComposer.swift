import Foundation

// MARK: - V3.3 Lite · 本地经营问答合成（0 Token）
//
// 四类 READ 在 Lite 全部本地聚合 + 模板回答，不调用远端模型：
// 数据只在本机读取并直接展示，不经过 Provider，天然满足最小字段 / 隐私要求。
// 纯函数、可单测；输入必须是 BusinessContextProvider 已聚合的最小投影。

enum BusinessAnswerComposer {

    static func answer(for insight: BusinessInsightKind, pack: GroundingPack) -> String {
        guard pack.hasBusinessData else { return "目前还没有足够的店铺数据可以分析。" }
        switch insight {
        case .overview:
            return pack.localSummary?.isEmpty == false
                ? pack.localSummary!
                : "今天营业额\(pack.todayRevenue.map(money) ?? "暂无记录")。"
        case .comparison:
            guard let today = pack.todayRevenue else { return "今天还没有营业额记录，暂时无法和昨天比较。" }
            guard let yesterday = pack.yesterdayRevenue else { return "今天营业额 \(money(today))，昨天没有营业额记录。" }
            guard yesterday != 0 else { return "今天营业额 \(money(today))，昨天营业额为 0，暂不计算百分比。" }
            let change = (today - yesterday) / yesterday * 100
            if abs(change) < 0.05 { return "今天营业额 \(money(today))，与昨天基本持平。" }
            return "今天营业额 \(money(today))，较昨天\(change > 0 ? "增长" : "下降") \(String(format: "%.1f", abs(change)))%。"
        case .sevenDayTrend:
            guard !pack.sevenDayRevenue.isEmpty else { return "最近 7 天还没有营业额记录。" }
            let values = pack.sevenDayRevenue.map(\.amount)
            let total = values.reduce(0, +)
            guard total > 0 else { return "最近 7 天还没有营业额记录。" }
            let first = values.prefix(3).reduce(0, +) / Double(max(values.prefix(3).count, 1))
            let last = values.suffix(3).reduce(0, +) / Double(max(values.suffix(3).count, 1))
            let direction = last > first * 1.05 ? "走高" : (last < first * 0.95 ? "走低" : "基本平稳")
            return "最近 7 天营业额合计 \(money(total))，日均 \(money(total / Double(values.count)))，整体\(direction)。"
        case .inventory:
            let low = pack.goods.filter { $0.stock <= $0.minStock }
            guard !pack.goods.isEmpty else { return "目前还没有商品库存数据。" }
            guard !low.isEmpty else { return "已检查 \(pack.goods.count) 个商品，目前没有低库存商品。" }
            let names = low.prefix(5).map { "\($0.name)（库存 \($0.stock)）" }.joined(separator: "、")
            return "有 \(low.count) 个商品需要注意库存：\(names)。"
        case .advice:
            return ""
        }
    }

    /// 单类问答。
    static func answer(for kind: BusinessRecordKind, context: ScopedBusinessContext) -> String {
        switch kind {
        case .revenueToday: return revenue(context)
        case .todoToday: return todos(context)
        case .recentMemo: return memos(context)
        case .expiringGoods: return expiring(context)
        case .delivery: return delivery(context)
        }
    }

    /// 多类合并回答（去空段，段间换行）。
    static func answer(for kinds: [BusinessRecordKind], context: ScopedBusinessContext) -> String {
        var seen = Set<BusinessRecordKind>()
        let unique = kinds.filter { seen.insert($0).inserted }
        let paragraphs = unique.map { answer(for: $0, context: context) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if paragraphs.isEmpty { return "暂时没有相关经营数据。" }
        return paragraphs.joined(separator: "\n")
    }

    // MARK: 各品类

    private static func revenue(_ c: ScopedBusinessContext) -> String {
        guard let total = c.revenueTodayTotal else {
            return "今天还没有记录营业额。"
        }
        if let count = c.revenueTodayCount, count > 0 {
            return "今天营业额 \(money(total))，共 \(count) 笔。"
        }
        return "今天营业额 \(money(total))。"
    }

    private static func todos(_ c: ScopedBusinessContext) -> String {
        guard let titles = c.todoTodayTitles?.filter({ !$0.isEmpty }), !titles.isEmpty else {
            return "今天没有未完成的待办。"
        }
        let shown = Array(titles.prefix(5)).enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        let more = titles.count > 5 ? "\n另有 \(titles.count - 5) 件，可在待办页查看。" : ""
        return "今天还有 \(titles.count) 件待办：\n\(shown)\(more)"
    }

    private static func memos(_ c: ScopedBusinessContext) -> String {
        guard let titles = c.recentMemoTitles?.filter({ !$0.isEmpty }), !titles.isEmpty else {
            return "最近没有备忘。"
        }
        let shown = Array(titles.prefix(5)).enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        return "最近备忘：\n\(shown)"
    }

    private static func expiring(_ c: ScopedBusinessContext) -> String {
        guard let titles = c.expiringTitles?.filter({ !$0.isEmpty }), !titles.isEmpty else {
            return "没有查到临期 / 到期商品。"
        }
        let shown = Array(titles.prefix(8)).enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        return "有 \(titles.count) 件临期 / 到期商品：\n\(shown)"
    }

    private static func delivery(_ c: ScopedBusinessContext) -> String {
        let pending = c.deliveryPendingCount ?? 0
        let delivering = c.deliveryDeliveringCount ?? 0
        if pending == 0 && delivering == 0 {
            return "今天没有待处理的配送。"
        }
        var parts: [String] = []
        if pending > 0 { parts.append("\(pending) 单待处理") }
        if delivering > 0 { parts.append("\(delivering) 单配送中") }
        return "今天还有" + parts.joined(separator: "、") + "。"
    }

    // MARK: - 工具

    private static func money(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let text = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "¥\(text)"
    }
}
