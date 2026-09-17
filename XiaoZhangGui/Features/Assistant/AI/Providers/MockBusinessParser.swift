import Foundation

// MARK: - V3.3 Lite · Mock 解析（仅 Foundation 预览 / DEBUG / 预览装配 / 测试使用）
//
// AI REAL 起，四范例解析规则已产品化为 LocalBusinessParser（Free First · 0 Token）。
// 本类型仅作为 MockAIProvider 的适配包装层保留：
// - businessAction：委托 LocalBusinessParser（与正式本地链路同一套规则）；
// - businessQuery：预览环境未接经营数据，返回固定澄清文案；
// - 其它：nil（普通聊天由 MockAIProvider 回 canned reply）。
// 名称与返回类型保持不变，Foundation 测试无需改动。

typealias MockParseResult = LocalParseResult

struct MockBusinessParser {
    private let local = LocalBusinessParser()

    func parse(_ raw: String, intent: IntentKind, now: Date = Date()) -> MockParseResult? {
        if case .businessQuery = intent {
            return .clarify("预览版还没有接入你的经营数据；正式版可以在这里查询今日营业额、待办、临期商品和配送。")
        }
        return local.parse(raw, intent: intent, now: now)
    }
}
