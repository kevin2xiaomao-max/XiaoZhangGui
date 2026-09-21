import Foundation

/// Routes only external/general requests. IntentRouter remains the first
/// deterministic classifier for XiaoZhangGui business actions and queries.
struct AICapabilityRouter: Sendable {
    func request(for input: String) -> AICapabilityRequest? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = firstURL(in: text) {
            return AICapabilityRequest(capability: .urlReading, input: url.absoluteString)
        }
        if looksLikeWebSearch(text) {
            return AICapabilityRequest(capability: .webSearch, input: text)
        }
        return nil
    }

    func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        guard let match = detector?.firstMatch(in: text, options: [], range: range),
              let url = match.url,
              ["http", "https"].contains(url.scheme?.lowercased()) else { return nil }
        return url
    }

    private func looksLikeWebSearch(_ text: String) -> Bool {
        // Deterministic store queries stay on IntentRouter's local path.
        let businessMarkers = ["营业额", "营收", "收入", "库存", "进价", "售价", "待办", "备忘", "临期", "配送"]
        guard !businessMarkers.contains(where: { text.contains($0) }) else { return false }
        // Weather is an existing deterministic local capability. Keep it ahead
        // of the generic web-search markers (for example “帮我查下天气”).
        let weatherMarkers = ["天气", "气温", "多少度", "几度", "下雨", "降雨", "天气预报"]
        guard !weatherMarkers.contains(where: { text.contains($0) }) else { return false }

        let markers = [
            "搜索一下", "网上查", "联网搜索", "最新消息", "网页搜索", "搜一下",
            "查一下", "帮我查", "新闻", "最新", "现在什么情况", "实时", "当前价格",
            "现在多少钱", "今天有什么"
        ]
        return markers.contains { text.contains($0) }
    }
}
