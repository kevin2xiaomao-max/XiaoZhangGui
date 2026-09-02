import Foundation

// MARK: - 备忘派生数据（语义对齐 Android MemoScreen 过滤逻辑）

enum MemoFilter: String, CaseIterable, Identifiable, Hashable {
    case all = "全部"
    case text = "文字"
    case image = "图片"
    case voice = "语音"

    var id: String { rawValue }
}

enum MemoSearch {
    /// 搜索 + 过滤 + 按 updatedAt 倒序（语音暂无内容，恒为空）
    static func filtered(memos: [Memo], search: String, filter: MemoFilter) -> [Memo] {
        let keyword = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return memos
            .filter { memo in
                let matchesSearch = keyword.isEmpty ||
                    memo.title.localizedCaseInsensitiveContains(keyword) ||
                    memo.content.localizedCaseInsensitiveContains(keyword)
                let matchesFilter: Bool
                switch filter {
                case .all: matchesFilter = true
                case .text: matchesFilter = memo.imageData == nil
                case .image: matchesFilter = memo.imageData != nil
                case .voice: matchesFilter = false
                }
                return matchesSearch && matchesFilter
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    static let emptyText = "暂无记录，点击右下角添加"

    /// 卡片左侧色条（稳定分配：绿 / 橙 / 蓝，基于创建时间）
    static func accentIndex(for memo: Memo) -> Int {
        Int(memo.createdAt.timeIntervalSince1970.magnitude) % 3
    }
}
