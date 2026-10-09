import SwiftUI
import SwiftData

// MARK: - 临期提醒（V371：GroupSurface 按到期分组 + WorkRow，warning 色只用在需要处）

struct ExpiryView: View {
    @Environment(\.modelContext) private var context
    @Query private var items: [ExpiryItem]
    @State private var showNewEditor = false
    @State private var editingItem: ExpiryItem?
    @State private var deletingItem: ExpiryItem?
    @State private var deleteError: String?
    @State private var failedToggleItem: ExpiryItem?
    @State private var stateActionError: String?

    private var stats: ExpiryStats { ExpiryStats(items: items) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V371.Space.section) {
                statCard
                if items.isEmpty {
                    GroupSurface {
                        VStack(spacing: 12) {
                            EmptyState(icon: "shippingbox", title: "暂无临期商品", message: "可以新增一条临期记录")
                            Button { showNewEditor = true } label: {
                                Label("新增临期商品", systemImage: "plus")
                                    .font(V371.Typography.rowTitle)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Capsule().fill(V371.Colors.heroTop))
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    ForEach(stats.groups, id: \.group.label) { bucket in
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(bucket.group.label) {
                                Text("\(bucket.items.count)")
                                    .font(V371.Typography.badge)
                                    .foregroundStyle(V371.Colors.textTertiary)
                            }
                            GroupSurface {
                                ForEach(Array(bucket.items.enumerated()), id: \.element.persistentModelID) { index, item in
                                    if index > 0 { V371Divider(leading: 62) }
                                    ExpiryWorkRow(
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
            .padding(.horizontal, V371.Space.page)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(V371AccessibilityID.screenExpiry)
        .v371Canvas()
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
        .confirmationDialog("删除这条临期记录？", isPresented: Binding(get: { deletingItem != nil }, set: { if !$0 { deletingItem = nil } }), titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let item = deletingItem {
                    do { try ExpiryRepository(context: context).delete(item); Haptic.warning() }
                    catch { deleteError = "临期记录未删除，请重试。" }
                }
                deletingItem = nil
            }
            Button("取消", role: .cancel) { deletingItem = nil }
        }
        .alert("删除失败", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("知道了", role: .cancel) { deleteError = nil }
        } message: { Text(deleteError ?? "请稍后重试") }
        .alert("操作失败", isPresented: Binding(get: { stateActionError != nil }, set: { if !$0 { stateActionError = nil } })) {
            Button("重试") {
                stateActionError = nil
                if let item = failedToggleItem { toggleReturn(item) }
            }
            .accessibilityIdentifier(V371AccessibilityID.reliabilityRetry)
            Button("取消", role: .cancel) {
                stateActionError = nil
                failedToggleItem = nil
            }
        } message: { Text(stateActionError ?? "退货状态未改变，请重试。") }
    }

    // MARK: 三格统计

    private var statCard: some View {
        GroupSurface {
            HStack(spacing: 8) {
                statCell(count: stats.urgentCount, label: "3天内到期", color: V371.Colors.red)
                statDivider
                statCell(count: stats.warningCount, label: "7天内到期", color: V371.Colors.orange)
                statDivider
                statCell(count: stats.safeCount, label: "30天内到期", color: V371.Colors.blue)
            }
            .padding(.horizontal, V371.Space.rowPadding)
            .padding(.vertical, 14)
        }
    }

    private var statDivider: some View {
        Rectangle().fill(V371.Colors.divider).frame(width: 1, height: 36)
    }

    private func statCell(count: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(count)")
                .v32Text(.metric)
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .v32Text(.caption)
                .foregroundStyle(V371.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func delete(_ item: ExpiryItem) {
        deletingItem = item
    }

    private func toggleReturn(_ item: ExpiryItem) {
        let wasReturned = item.status == .returned
        do {
            try UITestFailureInjection.throwIfRequested(.expiryToggleReturn)
            try ExpiryRepository(context: context).toggleReturn(item)
            failedToggleItem = nil
            wasReturned ? Haptic.light() : Haptic.success()
        } catch {
            Haptic.error()
            failedToggleItem = item
            stateActionError = "退货状态未改变，请重试。"
        }
    }
}

// MARK: - 临期行（V371 WorkRow：商品 + 到期时间 + StatusBadge + 退货/删除动作）

private struct ExpiryWorkRow: View {
    let item: ExpiryItem
    let group: ExpiryGroup
    let onEdit: () -> Void
    let onToggleReturn: () -> Void
    let onDelete: () -> Void

    /// 分组 accent：warning 色只用在需要处（§9：expired/urgent 才用红/橙）。
    private var iconColor: Color {
        switch group {
        case .expired, .urgent3: return V371.Colors.red
        case .urgent7: return V371.Colors.orange
        case .safe30: return V371.Colors.blue
        case .later, .returned: return V371.Colors.gray
        }
    }

    /// 剩余天数徽标色：已退货/安全态不用 warning 色。
    private var badgeColor: Color {
        if item.status == .returned { return V371.Colors.gray }
        let days = item.daysLeft()
        if days <= 3 { return V371.Colors.red }
        if days <= 7 { return V371.Colors.orange }
        return V371.Colors.blue
    }

    var body: some View {
        WorkRow(
            icon: "clock.badge.exclamationmark",
            iconColor: iconColor,
            title: "\(item.name) ×\(item.quantity)",
            subtitle: "到期 \(Fmt.formatDate(item.expiryDate))",
            action: onEdit
        ) {
            VStack(alignment: .trailing, spacing: 6) {
                StatusBadge(ExpiryBadge.text(for: item), color: badgeColor)
                HStack(spacing: 4) {
                    Button(action: onToggleReturn) {
                        Label(item.status == .returned ? "恢复" : "退货",
                              systemImage: item.status == .returned ? "arrow.counterclockwise" : "arrow.uturn.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(V371.Colors.orange)
                            .padding(.horizontal, 8)
                            .frame(minWidth: 44, minHeight: 44)
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.status == .returned ? "恢复为待处理" : "标记为已退货")
                    .accessibilityIdentifier(V371AccessibilityID.expiryToggleReturn)
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(V371.Colors.textTertiary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("删除")
                }
            }
        }
    }
}
