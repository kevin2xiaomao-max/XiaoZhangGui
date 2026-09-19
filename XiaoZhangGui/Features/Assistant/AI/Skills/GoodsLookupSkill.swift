import Foundation

enum GoodsLookupResult: Equatable, Sendable {
    case reply(String)
    case clarify([String])
    case notFound(String)
}

enum GoodsLookupSkill {
    static func lookup(_ query: String, in goods: [GoodsSummary]) -> GoodsLookupResult {
        let matchedGoods = goods.filter { matchesGoods(query: query, goodsName: $0.name) }
        guard !matchedGoods.isEmpty else {
            return .notFound("暂时没找到相关商品，你可以先在货品里建档。")
        }
        guard matchedGoods.count == 1, let item = matchedGoods.first else {
            return .clarify(matchedGoods.map(\.name))
        }

        let asksPurchase = query.contains("进价")
        let asksSale = query.contains("售价") || query.contains("卖多少")
        let asksStock = query.contains("库存") || query.contains("还有多少") || query.contains("有没有")
        let asksMargin = query.contains("毛利") || query.contains("毛利率")

        if asksPurchase {
            guard item.purchasePrice > 0 else { return .reply("\(item.name)：暂未填写进价。") }
            return .reply("\(item.name)：进价 ¥\(money(item.purchasePrice))。")
        }
        if asksStock {
            let lowStock = item.stock <= item.minStock ? "，库存偏低" : ""
            return .reply("\(item.name)：库存 \(item.stock)\(lowStock)。")
        }
        if asksSale {
            return .reply("\(item.name)：售价 ¥\(money(item.salePrice))。")
        }
        if asksMargin {
            guard item.purchasePrice > 0, item.salePrice > 0 else { return .reply("\(item.name)：暂时无法计算毛利，请先补齐进价和售价。") }
            return .reply("\(item.name)：毛利 ¥\(money(item.salePrice - item.purchasePrice))，毛利率 \(percent((item.salePrice - item.purchasePrice) / item.salePrice))。")
        }

        var parts = ["售价 ¥\(money(item.salePrice))"]
        if item.purchasePrice > 0 { parts.append("进价 ¥\(money(item.purchasePrice))") }
        if item.purchasePrice > 0, item.salePrice > 0 {
            parts.append("毛利 ¥\(money(item.salePrice - item.purchasePrice))")
            parts.append("毛利率 \(percent((item.salePrice - item.purchasePrice) / item.salePrice))")
        }
        return .reply("\(item.name)：" + parts.joined(separator: "，") + "。")
    }

    /// 轻量本地匹配：先移除查询意图词，再用剩余商品词匹配完整名或前缀/简称。
    /// 不调用模型，也不把完整 Goods 对象带出本地上下文。
    static func matchesGoods(query: String, goodsName: String) -> Bool {
        let name = normalize(goodsName)
        guard !name.isEmpty else { return false }
        return queryTerms(query).contains { term in
            term == name || (term.count >= 2 && (name.contains(term) || term.contains(name)))
        }
    }

    private static func queryTerms(_ query: String) -> [String] {
        var value = normalize(query)
        let intentWords = [
            "明天", "后天", "今天", "请问", "帮我查", "查询", "告诉我",
            "有没有", "还有多少", "多少钱", "进价", "售价", "卖多少",
            "库存", "毛利率", "毛利", "价格", "多少", "一箱", "一瓶", "一罐",
            "箱", "瓶", "罐"
        ]
        for word in intentWords {
            value = value.replacingOccurrences(of: word, with: " ")
        }
        return value
            .split(whereSeparator: { $0.isWhitespace || $0 == "，" || $0 == "。" || $0 == "？" || $0 == "?" })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func money(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.2f", value)
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}
