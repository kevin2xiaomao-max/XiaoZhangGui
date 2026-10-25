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
            return adviceAnswer(pack: pack)
        case .extremes:
            return extremesAnswer(pack: pack)
        case .sourceShare:
            return sourceShareAnswer(pack: pack)
        case .period(let period):
            guard let summary = pack.periodSummaries.first(where: { $0.period == period }) else {
                return "该时间范围暂无营业额记录。"
            }
            let label: String = {
                switch period {
                case .today: return "今天"
                case .yesterday: return "昨天"
                case .lastSevenDays: return "最近 7 天"
                case .thisWeek: return "本周（自然周）"
                case .lastWeek: return "上周（自然周）"
                case .thisMonth: return "本月"
                case .lastMonth: return "上月"
                case .lastThreeMonths: return "最近 3 个月"
                case .lastSixMonths: return "最近 6 个月"
                case .thisMonthComparedWithLastMonth: return "本月与上月"
                case .lastThreeMonthsComparedWithThisMonth: return "本月至今与前 3 个完整自然月"
                }
            }()
            let current = "\(label)营业额 \(money(summary.amount))，\(summary.count > 0 ? "共 \(summary.count) 笔" : "暂无记录")。"
            // V3.9.3 · 支出与净额：只有该时段确有支出记录时才追加，不虚构零支出。
            if let expense = pack.expenseTotals[period] {
                let net = summary.amount - expense
                let netText = net >= 0 ? "净额 \(money(net))" : "净额 -\(money(-net))"
                if let comparison = summary.comparisonAmount {
                    if period == .thisMonthComparedWithLastMonth {
                        return current + "支出 \(money(expense))，\(netText)。上月营业额 \(money(comparison))。"
                    }
                    let months = summary.comparisonMonthCount ?? 0
                    let average = summary.comparisonAverageAmount ?? 0
                    var answer = current + "支出 \(money(expense))，\(netText)。前 3 个完整自然月中目前有数据的 \(months) 个月，合计 \(money(comparison))，月均 \(money(average))。"
                    if months < 3 { answer += "历史数据不足 3 个月，本次实际比较了 \(months) 个月。" }
                    return answer
                }
                return current + "支出 \(money(expense))，\(netText)。"
            }
            guard let comparison = summary.comparisonAmount else {
                return current
            }
            if period == .thisMonthComparedWithLastMonth {
                return current + " 上月营业额 \(money(comparison))。"
            }
            let months = summary.comparisonMonthCount ?? 0
            let average = summary.comparisonAverageAmount ?? 0
            var answer = current + " 前 3 个完整自然月中目前有数据的 \(months) 个月，合计 \(money(comparison))，月均 \(money(average))。"
            if months < 3 { answer += "历史数据不足 3 个月，本次实际比较了 \(months) 个月。" }
            return answer
        }
    }

    // MARK: - V3.9.3 · 建议 / 极值 / 来源占比（只用 GroundingPack 已知事实）

    /// 确定性建议：只陈述已知事实；凡是推测必须以「推测」开头标注，
    /// 绝不虚构原因、库存、利润、客流。
    private static func adviceAnswer(pack: GroundingPack) -> String {
        var facts: [String] = []
        if let today = pack.todayRevenue {
            facts.append("今天营业额 \(money(today))")
        }
        if let yesterday = pack.yesterdayRevenue, let today = pack.todayRevenue, yesterday > 0 {
            let change = (today - yesterday) / yesterday * 100
            facts.append("较昨天\(change >= 0 ? "增长" : "下降") \(String(format: "%.1f", abs(change)))%")
        }
        let low = pack.goods.filter { $0.stock <= $0.minStock }
        if !low.isEmpty {
            let names = low.prefix(3).map(\.name).joined(separator: "、")
            facts.append("有 \(low.count) 个低库存商品（\(names))")
        }
        if pack.deliveryPendingCount > 0 || pack.deliveryDeliveringCount > 0 {
            facts.append("还有 \(pack.deliveryPendingCount) 单待处理、\(pack.deliveryDeliveringCount) 单配送中")
        }
        if !pack.unfinishedTodoTitles.isEmpty {
            facts.append("还有 \(pack.unfinishedTodoTitles.count) 件未完成待办")
        }
        if !pack.expiryTitles.isEmpty {
            facts.append("有 \(pack.expiryTitles.count) 件临期商品")
        }
        guard !facts.isEmpty else { return "目前还没有足够的店铺数据可以分析。" }
        var text = "根据已有数据：" + facts.joined(separator: "；") + "。"
        // 推测段：只给可验证的下一步，不给原因与数字。
        if !low.isEmpty {
            text += "推测：先处理低库存商品的补货与临期商品，可能是接下来最稳妥的动作（仅为推测，请以实际库存为准）。"
        } else if pack.deliveryPendingCount > 0 {
            text += "推测：先把待处理配送清掉，可以减少积压（仅为推测）。"
        } else {
            text += "推测：保持目前的记录节奏，数据越多，后续分析越准（仅为推测）。"
        }
        return text
    }

    /// 近 7 天最高 / 最低营业日（只用 sevenDayRevenue；全为 0 时明说无记录）。
    private static func extremesAnswer(pack: GroundingPack) -> String {
        let days = pack.sevenDayRevenue.filter { $0.amount > 0 }
        guard let maxDay = days.max(by: { $0.amount < $1.amount }),
              let minDay = days.min(by: { $0.amount < $1.amount }) else {
            return "最近 7 天还没有营业额记录，无法比较最高 / 最低营业日。"
        }
        if days.count == 1 {
            return "最近 7 天只有 1 天有营业额记录：\(dayText(maxDay.date)) \(money(maxDay.amount))。"
        }
        return "最近 7 天最高营业日是 \(dayText(maxDay.date))（\(money(maxDay.amount))），最低营业日是 \(dayText(minDay.date))（\(money(minDay.amount))）。"
    }

    /// 本月收入来源占比（只用 sourceShares；无数据时明说）。
    private static func sourceShareAnswer(pack: GroundingPack) -> String {
        guard !pack.sourceShares.isEmpty else { return "本月暂无收入来源占比数据。" }
        let total = pack.sourceShares.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return "本月暂无收入来源占比数据。" }
        let parts = pack.sourceShares.map { share in
            "\(share.name) \(percentText(share.percent))（\(money(share.amount))）"
        }.joined(separator: "、")
        return "本月收入来源占比：\(parts)，合计 \(money(total))。"
    }

    private static func percentText(_ value: Double) -> String {
        if value == value.rounded() { return String(format: "%.0f%%", value) }
        return String(format: "%.1f%%", value)
    }

    private static func dayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
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
