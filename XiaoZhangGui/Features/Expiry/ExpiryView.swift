import SwiftUI
import SwiftData

struct ExpiryView: View {
    @Environment(\.modelContext) private var context
    @Query private var items: [ExpiryItem]
    @State private var showNewEditor = false
    @State private var editingItem: ExpiryItem?

    private var stats: ExpiryStats { ExpiryStats(items: items) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                statCard
                if items.isEmpty {
                    V32Card {
                        V32EmptyState(systemName: "shippingbox", title: "暂无临期商品", message: nil)
                            .padding(.vertical, 8)
                    }
                } else {
                    ForEach(stats.groups, id: \.group.label) { bucket in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(bucket.group.label)
                                .v32Text(.caption)
                                .foregroundStyle(V32.textTertiary)
                                .padding(.leading, 4)
                            V32Card(padding: 4) {
                                VStack(spacing: 0) {
                                    ForEach(Array(bucket.items.enumerated()), id: \.element.persistentModelID) { index, item in
                                        if index > 0 { Rectangle().fill(V32.divider).frame(height: 1).padding(.leading, 48) }
                                        ExpiryRow(
                                            item: item,
                                            group: bucket.group,
                                            onEdit: { editingItem = item },
                                            onToggleReturn: { toggleReturn(item) },
                                            onDelete: { delete(item) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32PageBottomInset()
        .navigationTitle("临期提醒")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("新增临期商品")
            }
        }
        .sheet(isPresented: $showNewEditor) { ExpiryEditorSheet(item: nil) }
        .sheet(item: $editingItem) { ExpiryEditorSheet(item: $0) }
    }

    // MARK: 三格统计

    private var statCard: some View {
        V32Card {
            HStack(spacing: 8) {
                statCell(count: stats.urgentCount, label: "3天内到期", color: V32.danger)
                statDivider
                statCell(count: stats.warningCount, label: "7天内到期", color: V32.amber)
                statDivider
                statCell(count: stats.safeCount, label: "30天内到期", color: V32.brand)
            }
        }
    }

    private var statDivider: some View {
        Rectangle().fill(V32.divider).frame(width: 1, height: 36)
    }

    private func statCell(count: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(count)")
                .v32Text(.metric)
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .v32Text(.caption)
                .foregroundStyle(V32.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func delete(_ item: ExpiryItem) {
        Haptic.warning()
        try? ExpiryRepository(context: context).delete(item)
    }

    private func toggleReturn(_ item: ExpiryItem) {
        Haptic.light()
        try? ExpiryRepository(context: context).toggleReturn(item)
    }
}

// MARK: - 临期行

private struct ExpiryRow: View {
    let item: ExpiryItem
    let group: ExpiryGroup
    let onEdit: () -> Void
    let onToggleReturn: () -> Void
    let onDelete: () -> Void

    private var tone: V32BubbleTone {
        switch group {
        case .expired, .urgent3: return .danger
        case .urgent7: return .amber
        case .safe30: return .brand
        case .later, .returned: return .neutral
        }
    }

    private var badgeStatus: V32Status {
        switch group {
        case .expired, .urgent3: return .expiry
        case .urgent7: return .expiry
        case .safe30: return .done
        case .later: return .pending
        case .returned: return .done
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                V32IconBubble(systemName: "clock.badge.exclamationmark", tone: tone, size: 34, icon: 15)
                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(item.name) ×\(item.quantity)")
                            .v32Text(.title)
                            .foregroundStyle(V32.textPrimary)
                            .lineLimit(2)
                        Text("到期 \(Fmt.formatDate(item.expiryDate))")
                            .v32Text(.caption)
                            .foregroundStyle(V32.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                V32StatusPill(text: ExpiryBadge.text(for: item), status: badgeStatus)
            }
            HStack(spacing: 6) {
                Spacer().frame(width: 46)
                Button(action: onToggleReturn) {
                    Label(item.status == .returned ? "恢复" : "退货",
                          systemImage: item.status == .returned ? "arrow.counterclockwise" : "arrow.uturn.left")
                        .v32Text(.pill)
                        .foregroundStyle(V32.amber)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(V32.amberSoft))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(V32.textQuaternary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(V32.pageBGSecondary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("删除")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
