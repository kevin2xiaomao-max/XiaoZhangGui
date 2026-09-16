import Foundation

// MARK: - V3.3 Lite · Deep Link 纯路由（可单测）
//
// 保留旧入口：xzg://voice、xzg://quickrecord（quick 为别名）
// 新增：xzg://ai、xzg://ai?mode=voice
// 不改动 Bundle ID / URL Scheme（仍为 xzg）。

enum AppDeepLink: Equatable {
    /// 旧：语音快速记录 Sheet
    case voice
    /// 旧：文字快速记录 Sheet
    case quickRecord
    /// 新：小掌柜 AI 页；voiceMode=true 时同时拉起短语音面板
    case ai(voiceMode: Bool)

    /// 从 URL 解析；无法识别返回 nil（调用方忽略，不崩溃）。
    static func route(url: URL) -> AppDeepLink? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems ?? []
        return route(host: url.host, queryItems: items)
    }

    /// 纯函数入口，便于测试直接传入 host / query。
    static func route(host: String?, queryItems: [URLQueryItem]) -> AppDeepLink? {
        switch host?.lowercased() {
        case "voice":
            return .voice
        case "quickrecord", "quick":
            return .quickRecord
        case "ai":
            let mode = queryItems.first(where: { $0.name == "mode" })?.value?.lowercased()
            return .ai(voiceMode: mode == "voice")
        default:
            return nil
        }
    }
}
