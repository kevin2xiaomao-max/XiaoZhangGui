import SwiftUI

struct V35HomeFocusSection: View {
    let items: [HomeInboxItem]
    let onTodoToggle: (HomeInboxItem) -> Void
    let onTap: (HomeInboxItem) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            V32SectionHeader("今日事项")
            if items.isEmpty {
                Label("今天暂无待处理事项", systemImage: "checkmark")
                    .font(.subheadline)
                    .foregroundStyle(V32.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { index, item in
                        HomeActionRow(item: item) { onTodoToggle(item) }
                            .contentShape(Rectangle())
                            .onTapGesture { onTap(item) }
                        if index == 0 && items.count > 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
            }
        }
    }
}
