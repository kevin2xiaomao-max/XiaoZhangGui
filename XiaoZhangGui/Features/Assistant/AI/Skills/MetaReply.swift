import Foundation

enum MetaReply {
    static func reply(for raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let markers = ["你能做什么", "有什么用", "有啥用", "还要AI干嘛", "还要 ai 干嘛", "小掌柜能做什么"]
        guard markers.contains(where: { text.localizedCaseInsensitiveContains($0) }) else { return nil }
        return "我能帮你把店里的事记清楚、查明白，也能陪你聊经营。现在可以直接问天气、商品价格库存、今日营业额，或说‘今天美团680’让我先整理给你确认。"
    }
}
