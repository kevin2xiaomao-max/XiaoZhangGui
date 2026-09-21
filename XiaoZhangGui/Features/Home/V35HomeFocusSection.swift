import SwiftUI

struct V35HomeFocusSection: View {
    let items: [HomeInboxItem]
    let onTodoToggle: (HomeInboxItem) -> Void
    let onTap: (HomeInboxItem) -> Void
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                V32SectionHeader("今日事项")
                V32Card(padding: 4) { VStack(spacing: 0) { ForEach(items.prefix(2)) { item in HomeActionRow(item: item) { onTodoToggle(item) }.contentShape(Rectangle()).onTapGesture { onTap(item) } } } }
            }
        }
    }
}
