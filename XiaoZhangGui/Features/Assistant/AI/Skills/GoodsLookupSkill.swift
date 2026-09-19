import Foundation

enum GoodsLookupResult: Equatable, Sendable {
    case reply(String)
    case clarify([String])
    case notFound(String)
}

enum GoodsLookupSkill {
    static func lookup(_ query: String, in goods: [GoodsSummary]) -> GoodsLookupResult {
        let matches = goods.filter { query.localizedCaseInsensitiveContains($0.name) || $0.name.localizedCaseInsensitiveContains(query) }
        guard !matches.isEmpty else {
            return .notFound("暂时没找到相关商品，你可以先在货品里建档。")
        }
        guard matches.count == 1, let item = matches.first else {
            return .clarify(matches.map(\.name))
        }

        let asksPurchase = query.contains("进价")
        let asksSale = query.contains("售价") || query.contains("卖多少")
        let asksStock = query.contains("库存") || query.contains("还有多少") || query.contains("有没有")
        let asksMargin = query.contains("毛利") || query.contains("毛利率")

        if asksPurchase {
            guard item.purchasePrice > 0 else { return .reply("(item.name)：暂未填写进价。") }
            return .reply("(item.name)：进价 ¥\(money(item.purchasePrice))。")
        }
        if asksStock {
            let lowStock = item.stock <= item.minStock ? "，库存偏低" : ""
            return .reply("(item.name)：库存 \(item.stock)\(lowStock)。")
        }
        if asksSale {
            return .reply("(item.name)：售价 ¥\(money(item.salePrice))。")
        }
        if asksMargin {
            guard item.purchasePrice > 0, item.salePrice > 0 else { return .reply("(item.name)：暂时无法计算毛利，请先补齐进价和售价。") }
            return .reply("(item.name)：毛利 ¥\(money(item.salePrice - item.purchasePrice))，毛利率 \(percent((item.salePrice - item.purchasePrice) / item.salePrice))。")
        }

        var parts = ["售价 ¥\(money(item.salePrice))"]
        if item.purchasePrice > 0 { parts.append("进价 ¥\(money(item.purchasePrice))") }
        if item.purchasePrice > 0, item.salePrice > 0 {
            parts.append("毛利 ¥\(money(item.salePrice - item.purchasePrice))")
            parts.append("毛利率 \(percent((item.salePrice - item.purchasePrice) / item.salePrice))")
        }
        return .reply("(item.name)：" + parts.joined(separator: "，") + "。")
    }

    private static func money(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.2f", value)
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}
