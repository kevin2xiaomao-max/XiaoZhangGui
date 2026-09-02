import SwiftUI
import SwiftData

// MARK: - 临期提醒页（V2.1：大标题 + 副标题 + 三格统计 + 分组列表 + swipeActions + FAB）
// 语义对齐 Android ExpiryScreen；按 02 文档补齐 已过期/已退货 分组与恢复

struct ExpiryView: View {
    @Environment(\.modelContext) private var context
    @Query private var items: [ExpiryItem]

    @State private var showNewEditor = false
    @State private var editingItem: ExpiryItem?

    private var stats: ExpiryStats {
        ExpiryStats(items: items)
    }

    var body: some View {
        PageBackground {
            ZStack(alignment: .bottomTrailing) {
                List {
                    titleSection
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 12, leading: V21Layout.pageMargin, bottom: 16, trailing: V21Layout.pageMargin))

                    statSection
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))

                    if items.isEmpty {
                        EmptyStateView(text: "暂无临期商品", icon: "shippingbox")
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    } else {
                        ForEach(stats.groups, id: \.group.label) { bucket in
                            Section {
                                ForEach(bucket.items) { item in
                                    ExpiryRow(item: item) {
                                        editingItem = item
                                    }
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 0, leading: V21Layout.pageMargin, bottom: 0, trailing: V21Layout.pageMargin))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            delete(item)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                        Button {
                                            toggleReturn(item)
                                        } label: {
                                            if item.status == .returned {
                                                Label("恢复", systemImage: "arrow.counterclockwise")
                                            } else {
                                                Label("退货", systemImage: "arrow.uturn.left")
                                            }
                                        }
                                        .tint(V21.warning)
                                    }
                                }
                            } header: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(bucket.group.color)
                                        .frame(width: 6, height: 6)
                                    Text(bucket.group.label)
                                        .v21Style(.labelMedium)
                                        .fontWeight(.semibold)
                                        .foregroundColor(V21.groupTitle)
                                }
                            }
                        }
                    }

                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                V21FAB(systemImage: "plus") {
                    showNewEditor = true
                }
                .padding(.trailing, V21Layout.spaceXL)
                .padding(.bottom, V21Layout.bottomDockContentGap - 30)
            }
        }
        .navigationTitle("临期提醒")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNewEditor) {
            ExpiryEditorSheet(item: nil)
        }
        .sheet(item: $editingItem) { item in
            ExpiryEditorSheet(item: item)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("临期提醒")
                .v21Style(.titlePage)
                .foregroundColor(V21.textPrimary)
            HStack(spacing: 0) {
                Text("有 ")
                Text("\(stats.expiringSoonCount) 件")
                    .fontWeight(.semibold)
                    .foregroundColor(stats.expiringSoonCount > 0 ? V21.danger : V21.brandGreen)
                Text(" 商品 7 天内到期")
            }
            .v21Style(.bodyMedium)
            .foregroundColor(V21.textTertiary)
        }
    }

    private var statSection: some View {
        HStack(spacing: 10) {
            ExpiryStatCard(count: stats.urgentCount, label: "3天内到期", color: V21.danger)
            ExpiryStatCard(count: stats.warningCount, label: "7天内到期", color: V21.warning)
            ExpiryStatCard(count: stats.safeCount, label: "30天内到期", color: V21.brandGreen)
        }
    }

    private func delete(_ item: ExpiryItem) {
        Haptic.warning()
        try? ExpiryRepository(context: context).delete(item)
    }

    private func toggleReturn(_ item: ExpiryItem) {
        try? ExpiryRepository(context: context).toggleReturn(item)
    }
}

// MARK: - 三格统计卡片

struct ExpiryStatCard: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        GlassSurface(radius: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(count)")
                    .v21Style(.titleSection)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(label)
                    .v21Style(.labelSmall)
                    .foregroundColor(V21.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 72)
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - 临期商品行（图标 + 名称×数量 + 剩余天数徽标 + 备注）

struct ExpiryRow: View {
    let item: ExpiryItem
    var onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {
                Group {
                    if let data = item.imageData {
                        ImageThumb(imageData: data, size: 40)
                    } else {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 16))
                            .foregroundColor(V21.textTertiary)
                    }
                }
                .frame(width: 40, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(V21.surfaceGlass)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("\(item.name) × \(item.quantity)")
                        .v21Style(.bodyLarge)
                        .fontWeight(.medium)
                        .foregroundColor(V21.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(ExpiryBadge.text(for: item))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ExpiryBadge.color(for: item))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(ExpiryBadge.color(for: item).opacity(0.12))
                            }
                        Text("到期 \(Fmt.formatDate(item.expiryDate))")
                            .v21Style(.labelSmall)
                            .foregroundColor(V21.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
