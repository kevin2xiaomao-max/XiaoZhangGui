import SwiftUI
import SwiftData

// MARK: - 备忘页（V32：搜索 + 过滤胶囊 + 双列卡片）

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

    private var filterBinding: Binding<String> {
        Binding(
            get: { filter.rawValue },
            set: { newValue in if let value = MemoFilter(rawValue: newValue) { filter = value } }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                V32SearchField(placeholder: "搜索记录…", text: $searchQuery)
                V32PillBar(items: MemoFilter.allCases.map(\.rawValue), selection: filterBinding)

                if isMockPreview {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach([("饮料供应商下周二调价", "记得提前问一次价格", "8月29日 15:20"), ("302别墅客人常买矿泉水", "下次配送可以顺便问是否要冰块", "8月29日 13:10"), ("冰柜右边声音有点大", "观察两天，不行就联系维修", "8月28日 22:40"), ("泳装供应商可以退两件", "周一联系", "8月28日 18:15")], id: \.0) { item in
                            mockCard(item)
                        }
                    }
                } else if filtered.isEmpty {
                    V32Card {
                        V32EmptyState(systemName: "square.and.pencil", title: MemoSearch.emptyText, message: nil)
                            .padding(.vertical, 8)
                    }
                } else {
                    memoGrid
                }
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32PageBottomInset()
        .navigationTitle("记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewEditor = true } label: { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel("新建记录")
            }
        }
        .sheet(isPresented: $showNewEditor) {
            MemoEditorSheet(memo: nil)
        }
        .sheet(item: $editingMemo) { memo in
            MemoEditorSheet(memo: memo)
        }
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
    }

    private func mockCard(_ item: (String, String, String)) -> some View {
        V32Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.0)
                    .v32Text(.title)
                    .foregroundStyle(V32.textPrimary)
                    .lineLimit(2)
                Text(item.1)
                    .v32Text(.caption)
                    .foregroundStyle(V32.textTertiary)
                    .lineLimit(3)
                Text(item.2)
                    .v32Text(.pill)
                    .foregroundStyle(V32.textQuaternary)
            }
        }
    }

    private func delete(_ memo: Memo) {
        Haptic.warning()
        try? MemoRepository(context: context).delete(memo)
    }
}

// MARK: - 备忘卡片（V32：白卡 + 左侧色条 + 图片/标题/内容/时间）

struct MemoCard: View {
    let memo: Memo
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var accentColor: Color {
        switch MemoSearch.accentIndex(for: memo) {
        case 0: return V32.brand
        case 1: return V32.amber
        default: return V32.info
        }
    }

    var body: some View {
        Button(action: onEdit) {
            V32Card {
                VStack(alignment: .leading, spacing: 0) {
                    if let data = memo.imageData {
                        ImageThumb(imageData: data, size: 120)
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: V32Radius.inset, style: .continuous))
                            .padding(.bottom, 10)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accentColor)
                            .frame(width: 3, height: 16)
                            .padding(.top, 2)
                        Text(memo.title.isEmpty ? "无标题" : memo.title)
                            .v32Text(.title)
                            .foregroundStyle(V32.textPrimary)
                            .lineLimit(2)
                    }

                    if !memo.content.isEmpty {
                        Text(memo.content)
                            .v32Text(.caption)
                            .foregroundStyle(V32.textTertiary)
                            .lineLimit(3)
                            .lineSpacing(2)
                            .padding(.top, 6)
                    }

                    HStack {
                        Text(Fmt.memoTime(memo.updatedAt))
                            .v32Text(.pill)
                            .foregroundStyle(V32.textQuaternary)
                        Spacer()
                        Button {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundStyle(V32.textQuaternary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 10)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
