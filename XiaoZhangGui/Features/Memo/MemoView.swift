import SwiftUI
import SwiftData

// MARK: - 备忘页（V371：grouped list / clean rows；GroupSurface + WorkRow + hairline）
//
// 不使用双列 Card Wall。删除保持确认流程（confirmationDialog + 删除失败 alert）。

struct MemoView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var memos: [Memo]

    @State private var searchQuery = ""
    @State private var filter: MemoFilter = .all
    @State private var showNewEditor = false
    @State private var editingMemo: Memo?
    @State private var deletingMemo: Memo?
    @State private var deleteError: String?
    private var isMockPreview: Bool { RuntimeMode.allowsMockData }

    private var filtered: [Memo] {
        MemoSearch.filtered(memos: memos, search: searchQuery, filter: filter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V371.Space.section) {
                searchField
                filterPicker

                if isMockPreview {
                    mockSection
                } else if filtered.isEmpty {
                    EmptyState(icon: "square.and.pencil", title: MemoSearch.emptyText)
                        .padding(.top, 12)
                } else {
                    memoSection
                }
            }
            .padding(.horizontal, V371.Space.page)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .v371Canvas()
        .v371DockInset()
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
        .confirmationDialog("删除这条备忘？", isPresented: Binding(get: { deletingMemo != nil }, set: { if !$0 { deletingMemo = nil } }), titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let memo = deletingMemo {
                    do { try MemoRepository(context: context).delete(memo); Haptic.warning() }
                    catch { deleteError = "备忘未删除，请重试。" }
                }
                deletingMemo = nil
            }
            Button("取消", role: .cancel) { deletingMemo = nil }
        }
        .alert("删除失败", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("知道了", role: .cancel) { deleteError = nil }
        } message: { Text(deleteError ?? "请稍后重试") }
    }

    // MARK: 搜索与筛选

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(V371.Colors.textTertiary)
                .accessibilityHidden(true)
            TextField("搜索记录…", text: $searchQuery)
                .font(V371.Typography.rowTitle)
                .foregroundStyle(V371.Colors.textPrimary)
                .tint(V371.Colors.blue)
                .submitLabel(.search)
            if !searchQuery.isEmpty {
                Button {
                    Haptic.light()
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(V371.Colors.textTertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.leading, V371.Space.rowPadding)
        .padding(.trailing, searchQuery.isEmpty ? V371.Space.rowPadding : 4)
        .padding(.vertical, 4)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: V371.Radius.group, style: .continuous)
                .fill(V371.Colors.group)
        )
    }

    private var filterPicker: some View {
        Picker("筛选", selection: Binding(
            get: { filter },
            set: { setFilter($0) }
        )) {
            ForEach(MemoFilter.allCases) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .tint(V371.Colors.blue)
        .accessibilityLabel("记录筛选")
    }

    private func setFilter(_ newValue: MemoFilter) {
        withAnimation(V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion))) {
            filter = newValue
        }
    }

    // MARK: 列表

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("记录") {
                Text("\(filtered.count)")
                    .font(V371.Typography.badge)
                    .foregroundStyle(V371.Colors.textTertiary)
            }
            GroupSurface {
                ForEach(Array(filtered.enumerated()), id: \.element.persistentModelID) { index, memo in
                    if index > 0 { V371Divider(leading: 62) }
                    memoRow(memo)
                }
            }
        }
    }

    private func memoRow(_ memo: Memo) -> some View {
        WorkRow(
            icon: memo.imageData == nil ? "note.text" : "photo",
            iconColor: memoAccent(memo),
            title: memo.title.isEmpty ? "无标题" : memo.title,
            subtitle: memo.content.isEmpty ? nil : memo.content,
            action: { editingMemo = memo }
        ) {
            HStack(spacing: 2) {
                Text(Fmt.memoTime(memo.updatedAt))
                    .font(V371.Typography.time)
                    .foregroundStyle(V371.Colors.textTertiary)
                Button { delete(memo) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundStyle(V371.Colors.textTertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("删除备忘")
            }
        }
    }

    /// 左侧色条语义（MemoSearch.accentIndex）：蓝 / 橙 / 黄。
    private func memoAccent(_ memo: Memo) -> Color {
        switch MemoSearch.accentIndex(for: memo) {
        case 0: return V371.Colors.blue
        case 1: return V371.Colors.orange
        default: return V371.Colors.yellow
        }
    }

    // MARK: Mock 预览（仅 Preview / UI 验收进程）

    private var mockSection: some View {
        let items = [
            ("饮料供应商下周二调价", "记得提前问一次价格", "8月29日 15:20"),
            ("302别墅客人常买矿泉水", "下次配送可以顺便问是否要冰块", "8月29日 13:10"),
            ("冰柜右边声音有点大", "观察两天，不行就联系维修", "8月28日 22:40"),
            ("泳装供应商可以退两件", "周一联系", "8月28日 18:15"),
        ]
        let tones: [Color] = [V371.Colors.blue, V371.Colors.orange, V371.Colors.yellow]
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("记录")
            GroupSurface {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if index > 0 { V371Divider(leading: 62) }
                    WorkRow(
                        icon: "note.text",
                        iconColor: tones[index % tones.count],
                        title: item.0,
                        subtitle: item.1
                    ) {
                        Text(item.2)
                            .font(V371.Typography.time)
                            .foregroundStyle(V371.Colors.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: 删除（确认流程）

    private func delete(_ memo: Memo) {
        deletingMemo = memo
    }
}

// MARK: - 备忘行（Todo 页复用；V371 视觉语言）

struct MemoCard: View {
    let memo: Memo
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var accentColor: Color {
        switch MemoSearch.accentIndex(for: memo) {
        case 0: return V371.Colors.blue
        case 1: return V371.Colors.orange
        default: return V371.Colors.yellow
        }
    }

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 8) {
                if memo.imageData != nil {
                    ImageThumb(imageData: memo.imageData, size: 120)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                }
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(accentColor)
                        .frame(width: 3, height: 16)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                    Text(memo.title.isEmpty ? "无标题" : memo.title)
                        .font(V371.Typography.rowTitle)
                        .foregroundStyle(V371.Colors.textPrimary)
                        .lineLimit(2)
                }
                if !memo.content.isEmpty {
                    Text(memo.content)
                        .font(V371.Typography.rowSubtitle)
                        .foregroundStyle(V371.Colors.textSecondary)
                        .lineLimit(3)
                }
                HStack {
                    Text(Fmt.memoTime(memo.updatedAt))
                        .font(V371.Typography.time)
                        .foregroundStyle(V371.Colors.textTertiary)
                    Spacer(minLength: 8)
                    Button { onDelete() } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundStyle(V371.Colors.textTertiary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("删除备忘")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: V371.Radius.group, style: .continuous)
                    .fill(V371.Colors.group)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(memo.title.isEmpty ? "无标题备忘" : memo.title)
    }
}
