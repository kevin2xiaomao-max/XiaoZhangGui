import SwiftUI

struct V35HomeFocusSection: View {
    let items: [HomeInboxItem]
    let onTap: (HomeInboxItem) -> Void
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                V32SectionHeader("现在最重要")
                V32Card(padding: 4) { VStack(spacing: 0) { ForEach(items.prefix(2)) { item in Button { onTap(item) } label: { HomeActionRow(item: item) {} }.buttonStyle(.plain) } } }
            }
        }
    }
}
