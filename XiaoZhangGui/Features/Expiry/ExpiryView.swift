import SwiftUI
import SwiftData

struct ExpiryView: View {
    @Environment(\.modelContext) private var context
    @Query private var items: [ExpiryItem]
    @State private var showNewEditor = false
    @State private var editingItem: ExpiryItem?

    private var stats: ExpiryStats { ExpiryStats(items: items) }

    var body: some View {
        List {
            Section {
                HStack(spacing: Tokens.Space.sm) {
                    ExpiryStatCard(count: stats.urgentCount, label: "3天内到期", color: .red)
                    ExpiryStatCard(count: stats.warningCount, label: "7天内到期", color: .orange)
                    ExpiryStatCard(count: stats.safeCount, label: "30天内到期", color: .green)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: Tokens.Space.page, bottom: 8, trailing: Tokens.Space.page))
                .listRowBackground(Color.clear)
            }
            if items.isEmpty {
                AppEmptyState(title: "暂无临期商品", systemImage: "shippingbox")
            } else {
                ForEach(stats.groups, id: \.group.label) { bucket in
                    Section(bucket.group.label) {
                        ForEach(bucket.items) { item in
                            Button { editingItem = item } label: {
                                BusinessRow(
                                    title: "\(item.name) ×\(item.quantity)",
                                    subtitle: "到期 \(Fmt.formatDate(item.expiryDate))",
                                    badge: item.status.rawValue,
                                    badgeTone: item.daysLeft() <= 1 ? .danger : .warning
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { delete(item) } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                Button { toggleReturn(item) } label: {
                                    if item.status == .returned {
                                        Label("恢复", systemImage: "arrow.counterclockwise")
                                    } else {
                                        Label("退货", systemImage: "arrow.uturn.left")
                                    }
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(V21.background)
        .navigationTitle("临期提醒")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewEditor = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showNewEditor) { ExpiryEditorSheet(item: nil) }
        .sheet(item: $editingItem) { ExpiryEditorSheet(item: $0) }
    }

    private func delete(_ item: ExpiryItem) {
        Haptic.warning()
        try? ExpiryRepository(context: context).delete(item)
    }

    private func toggleReturn(_ item: ExpiryItem) {
        try? ExpiryRepository(context: context).toggleReturn(item)
    }
}

struct ExpiryStatCard: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(count)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
    }
}
