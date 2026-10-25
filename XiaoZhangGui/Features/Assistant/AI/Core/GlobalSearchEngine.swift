import Foundation

// MARK: - V3.9.3 F · 全局自然语言搜索（只读、本地优先）
//
// - 只在本地 SwiftData 上匹配，不把整库原文发给第三方；需模型理解时也不走本引擎
//   （本引擎是纯本地规则；对话内的模型调用仍受 ConversationBudget 与脱敏约束）。
// - 结果只含类别 / 标题 / 60 字内摘要 / 日期；电话、地址全文、图片原文一律不进结果。
// - 查询解析：时间词（今天/昨天/本周/上周/本月/上月/最近 7 天）+ 状态词
//   （待处理/配送中/已完成/逾期/临期）+ 剩余关键词（AND 匹配标题或摘要）。
// - 无业务日期的记录（如商品）在有时段筛选时不出现（无法证明落在区间内，不猜）。

enum GlobalSearchCategory: String, CaseIterable, Sendable {
    case memo
    case delivery
    case goods
    case transaction
    case todo
    case expiry

    var label: String {
        switch self {
        case .memo: return "备忘"
        case .delivery: return "配送"
        case .goods: return "商品"
        case .transaction: return "交易"
        case .todo: return "待办"
        case .expiry: return "临期"
        }
    }
}

enum GlobalSearchStatus: String, Sendable {
    case pending
    case delivering
    case done
    case overdue
    case expiring
}

/// 搜索记录（最小字段投影；调用方负责脱敏与截断，引擎本身不再放宽）。
struct GlobalSearchRecord: Equatable, Sendable {
    let id: String
    let category: GlobalSearchCategory
    let title: String
    let snippet: String
    let date: Date?
    let status: GlobalSearchStatus?
}

struct GlobalSearchResult: Equatable, Sendable {
    let record: GlobalSearchRecord
}

struct GlobalSearchQuery: Equatable, Sendable {
    var terms: [String]
    var period: BusinessPeriod?
    var status: GlobalSearchStatus?
}

enum GlobalSearchEngine {

    static let maxResults = 50

    private static let searchVerbs = ["搜索", "查找", "搜一下", "找一下"]
    private static let fillerWords = ["的", "一下", "帮我", "查一下", "店内", "记录", "一下"]
    private static let categoryWords = ["配送", "备忘", "商品", "交易", "待办", "临期", "过期", "到期"]
    private static let statusWords: [(String, GlobalSearchStatus)] = [
        ("待处理", .pending), ("配送中", .delivering), ("已完成", .done),
        ("逾期", .overdue), ("临期", .expiring), ("快过期", .expiring),
    ]

    /// 是否为全局搜索触发句（「搜索…」「查找…」开头；其余问法走原有经营问答链路）。
    static func isGlobalSearch(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("搜索") || trimmed.hasPrefix("查找")
    }

    /// 解析查询：时间词与状态词剥离后，剩余部分按空白与标点切词。
    static func parse(_ text: String, now: Date = Date(), calendar: Calendar = .current) -> GlobalSearchQuery {
        var working = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for verb in searchVerbs where working.hasPrefix(verb) {
            working = String(working.dropFirst(verb.count))
            break
        }
        var status: GlobalSearchStatus?
        for (word, value) in statusWords where working.contains(word) {
            status = value
            working = working.replacingOccurrences(of: word, with: " ")
        }
        let period = BusinessPeriodParser().parse(working)
        if period != nil {
            // 剥掉时间词，避免它们成为匹配关键词（时间由区间过滤，不由文本匹配）。
            for word in ["今天", "昨天", "本周", "上周", "上一周", "本月", "这个月", "上月", "上个月",
                         "最近7天", "最近七天", "过去7天", "过去七天", "最近一周", "近一周",
                         "过去一周", "这一周", "这周", "近三个月", "最近3个月", "三个月",
                         "近6个月", "最近6个月", "近半年"] {
                working = working.replacingOccurrences(of: word, with: " ")
            }
        }
        for word in fillerWords + categoryWords {
            working = working.replacingOccurrences(of: word, with: " ")
        }
        let terms = working
            .components(separatedBy: CharacterSet(charactersIn: " ，,。；;、\t\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return GlobalSearchQuery(terms: terms, period: period, status: status)
    }

    /// 本地匹配：全部关键词命中（标题或摘要，忽略大小写）+ 时段 + 状态；精确标题优先，日期倒序。
    static func search(_ query: GlobalSearchQuery, in records: [GlobalSearchRecord],
                       now: Date = Date(), calendar: Calendar = .current) -> [GlobalSearchResult] {
        let bounds = query.period.flatMap { BusinessPeriodParser().bounds(for: $0, now: now, calendar: calendar) }
        let matched = records.filter { record in
            if let bounds {
                guard let date = record.date, bounds.contains(date) else { return false }
            }
            if let status = query.status, record.status != status { return false }
            let haystack = (record.title + " " + record.snippet).lowercased()
            return query.terms.allSatisfy { term in
                haystack.contains(term.lowercased())
            }
        }
        let sorted = matched.sorted { lhs, rhs in
            let lhsExact = query.terms.allSatisfy { lhs.title.localizedCaseInsensitiveContains($0) }
            let rhsExact = query.terms.allSatisfy { rhs.title.localizedCaseInsensitiveContains($0) }
            if lhsExact != rhsExact { return lhsExact && !rhsExact }
            switch (lhs.date, rhs.date) {
            case let (l?, r?): return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return lhs.title < rhs.title
            }
        }
        return Array(sorted.prefix(maxResults)).map { GlobalSearchResult(record: $0) }
    }
}
