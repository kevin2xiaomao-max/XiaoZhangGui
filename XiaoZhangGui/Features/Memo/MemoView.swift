import SwiftUI
import SwiftData

// MARK: - 备忘页（V2.1：大标题 + 玻璃搜索 + 分类 Tab + 双列卡片 + FAB）
// 语义对齐 Android MemoScreen

struct MemoView: View {
    @Environment(\.modelContext) private var context
    @Query private var memos: [Memo]

    @State private var searchQuery = ""
    @State private var filter: MemoFilter = .all
    @State private var showNewEditor = false
    @State private var editingMemo: Memo?
    private var isMockPreview: Bool { RuntimeMode.allowsMockData }

    private var filtered: [Memo] {
        MemoSearch.filtered(memos: memos, search: searchQuery, filter: filter)
    }

    var body: some View {
        PageBackground {
            ZStack(alignment: .bottomTrailing) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        titleSection
                        searchBar
                        filterTabs
                            .padding(.top, 12)
                            .padding(.bottom, 14)

                        if isMockPreview {
                            ForEach([("饮料供应商下周二调价", "记得提前问一次价格", "8月29日 15:20"), ("302别墅客人常买矿泉水", "下次配送可以顺便问是否要冰块", "8月29日 13:10"), ("冰柜右边声音有点大", "观察两天，不行就联系维修", "8月28日 22:40"), ("泳装供应商可以退两件", "周一联系", "8月28日 18:15")], id: \.0) { item in
                                VStack(alignment: .leading, spacing: 6) { Text(item.0).font(AppTypography.cardTitle).foregroundColor(V21.textPrimary); Text(item.1).font(AppTypography.body).foregroundColor(V21.textSecondary); Text(item.2).font(AppTypography.micro).foregroundColor(V21.textTertiary) }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(V21.surfaceGlass, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal, V21Layout.pageMargin).padding(.bottom, 10)
                            }
                        } else if filtered.isEmpty {
                            EmptyStateView(text: MemoSearch.emptyText, icon: "square.and.pencil")
                        } else {
                            memoGrid
                        }

                    }
                }

                V21FAB(systemImage: "plus") {
                    showNewEditor = true
                }
                .padding(.trailing, V21Layout.spaceXL)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("记录")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNewEditor) {
            MemoEditorSheet(memo: nil)
        }
        .sheet(item: $editingMemo) { memo in
            MemoEditorSheet(memo: memo)
        }
    }

    private var titleSection: some View {
        Text("记录")
            .v21Style(.titlePage)
            .foregroundColor(V21.textPrimary)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .padding(.horizontal, V21Layout.pageMargin)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索记录...", text: $searchQuery)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .padding(.horizontal, Tokens.Space.page)
    }

    private var filterTabs: some View {
        PillTabRow(items: MemoFilter.allCases, label: { $0.rawValue }, selection: $filter)
    }

    private var memoGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(filtered) { memo in
                MemoCard(memo: memo) {
                    editingMemo = memo
                } onDelete: {
                    delete(memo)
                }
            }
        }
        .padding(.horizontal, V21Layout.pageMargin)
    }

    private func delete(_ memo: Memo) {
        Haptic.warning()
        try? MemoRepository(context: context).delete(memo)
    }
}

// MARK: - 备忘卡片（玻璃 + 左侧色条 + 图片/标题/内容/时间）

struct MemoCard: View {
    let memo: Memo
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var accentColor: Color {
        switch MemoSearch.accentIndex(for: memo) {
        case 0: return V21.brandGreen
        case 1: return V21.warning
        default: return V21.info
        }
    }

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 0) {
                    if let data = memo.imageData {
                        ImageThumb(imageData: data, size: 80)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .padding(.bottom, 10)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accentColor)
                            .frame(width: 3, height: 16)
                            .padding(.top, 2)
                        Text(memo.title.isEmpty ? "无标题" : memo.title)
                            .v21Style(.titleSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(V21.textPrimary)
                            .lineLimit(2)
                    }

                    if !memo.content.isEmpty {
                        Text(memo.content)
                            .v21Style(.bodySmall)
                            .foregroundColor(V21.textTertiary)
                            .lineLimit(3)
                            .lineSpacing(2)
                            .padding(.top, 6)
                    }

                    HStack {
                        Text(Fmt.memoTime(memo.updatedAt))
                            .v21Style(.labelSmall)
                            .foregroundColor(V21.textQuaternary)
                        Spacer()
                        Button {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundColor(V21.textQuaternary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 10)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
