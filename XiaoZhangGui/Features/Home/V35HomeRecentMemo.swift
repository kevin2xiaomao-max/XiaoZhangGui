import SwiftUI

/// 首页低权重备忘预览：内容优先，复用 Memo 数据，不创建新的写入路径。
struct V35HomeRecentMemo: View {
    let memos: [Memo]
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            V32SectionHeader("最近备忘")

            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(memos.enumerated()), id: \.element.persistentModelID) { index, memo in
                        memoRow(memo)
                        if index < memos.count - 1 {
                            Divider().padding(.leading, 28)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("最近备忘，打开备忘")
            .accessibilityHint("查看全部备忘")
        }
    }

    private func memoRow(_ memo: Memo) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: memo.imageData == nil ? "note.text" : "photo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(V32.info)
                .frame(width: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(memo.title.isEmpty ? (memo.content.isEmpty ? "无标题" : memo.content) : memo.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(V32.textPrimary)
                    .lineLimit(1)
                if !memo.content.isEmpty && !memo.title.isEmpty {
                    Text(memo.content)
                        .font(.caption)
                        .foregroundStyle(V32.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)
            Text(Fmt.memoTime(memo.updatedAt))
                .font(.caption2)
                .foregroundStyle(V32.textQuaternary)
                .lineLimit(1)
        }
        .padding(.vertical, 11)
        .frame(minHeight: 44)
    }
}
