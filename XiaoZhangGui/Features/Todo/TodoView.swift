import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 待办：V371 干净分组列表
//
// Section = GroupSurface + SectionHeader，行 = WorkRow（图标圆 = 优先级色，
// 标题/副标题，trailing = 时间 badge + 完成开关）。
// 过滤 / 优先级 / 完成 / 图片 / 提醒 / persistence 语义全部保持 V3.6 原样，
// 只做 presentation 迁移。

struct TodoView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var todos: [Todo]
    @Query private var memos: [Memo]

    @State private var tab: TodoTab = .today
    @State private var showNewEditor = false
    @State private var showNewRecord = false
    @State private var showNewMemo = false
    @State private var editingTodo: Todo?
    @State private var editingMemo: Memo?
    @State private var togglingIDs: Set<PersistentIdentifier> = []
    /// 完成瞬间本地暂留的行：数据已写库，但视觉上留约 0.3s 做 fade/收缩后再移出（T21）
    @State private var finishingIDs: Set<PersistentIdentifier> = []
    @State private var deletingTodo: Todo?
    @State private var deleteError: String?
    @State private var stateActionError: String?

    private var list: [Todo] {
        if tab == .records { return [] }
        let base = TodoFilter.todos(for: tab, in: todos)
        let finishing = todos.filter { finishingIDs.contains($0.persistentModelID) }
        var seen = Set(base.map(\.persistentModelID))
        return base + finishing.filter { seen.insert($0.persistentModelID).inserted }
    }

    private var groups: [(label: String, items: [Todo])] {
        if tab == .done { return list.isEmpty ? [] : [(label: "已完成", items: list)] }
        return TodoFilter.grouped(list)
    }

    private var todayCount: Int { TodoFilter.todos(for: .today, in: todos).count }
    private var doneCount: Int { todos.filter(\.isCompleted).count }
    private var overdueCount: Int { TodoFilter.todos(for: .overdue, in: todos).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V371.Space.section) {
                // 切换控件始终可见；「备忘」展示独立 Memo 内容。
                // 只隐藏统计数字区域，不隐藏 tab 导航。
                tabPicker
                if tab != .records { statsRow }
                content
            }
            .padding(.horizontal, V371.Space.page)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .v371Canvas()
        .v371DockInset()
        .navigationTitle("待办")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if tab == .records { showNewMemo = true } else { showNewEditor = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(V371.Colors.blue)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab == .records ? "新增备忘" : "新增待办")
            }
        }
        .sheet(isPresented: $showNewEditor) { TodoEditorSheet(todo: nil) }
        .sheet(isPresented: $showNewRecord) { RecordEditorSheet() }
        .sheet(isPresented: $showNewMemo) { MemoEditorSheet(memo: nil) }
        .sheet(item: $editingTodo) { TodoEditorSheet(todo: $0) }
        .sheet(item: $editingMemo) { MemoEditorSheet(memo: $0) }
        .confirmationDialog("删除这条待办？", isPresented: Binding(get: { deletingTodo != nil }, set: { if !$0 { deletingTodo = nil } }), titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let todo = deletingTodo {
                    do { try TodoRepository(context: context).delete(todo); Haptic.warning() }
                    catch { deleteError = "待办未删除，请重试。" }
                }
                deletingTodo = nil
            }
            Button("取消", role: .cancel) { deletingTodo = nil }
        }
        .alert("删除失败", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("知道了", role: .cancel) { deleteError = nil }
        } message: { Text(deleteError ?? "请稍后重试") }
        .alert("操作失败", isPresented: Binding(get: { stateActionError != nil }, set: { if !$0 { stateActionError = nil } })) {
            Button("知道了", role: .cancel) { stateActionError = nil }
        } message: { Text(stateActionError ?? "待办状态未改变，请重试") }
    }

    // MARK: 分段胶囊 + 统计

    /// P0-2：tab 导航独立于统计卡，任何 tab 下都可见
    private var tabPicker: some View {
        V32SegmentedPicker(tabs: TodoTab.allCases.map(\.rawValue), selectionIndex: Binding(
            get: { TodoTab.allCases.firstIndex(of: tab) ?? 0 },
            set: { tab = TodoTab.allCases[$0] }
        ))
    }

    /// 统计数字区域（仅非「备忘」tab 显示）
    private var statsRow: some View {
        GroupSurface {
            HStack(spacing: 0) {
                statCell(value: todayCount, label: "待办", icon: "sun.max", tint: V371.Colors.blue)
                statDivider
                statCell(value: doneCount, label: "已完成", icon: "checkmark.circle", tint: V371.Colors.green)
                statDivider
                statCell(value: overdueCount, label: "逾期", icon: "exclamationmark.circle",
                         tint: overdueCount > 0 ? V371.Colors.orange : V371.Colors.textTertiary)
            }
            .padding(.horizontal, V371.Space.rowPadding)
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("待办 \(todayCount)，已完成 \(doneCount)，逾期 \(overdueCount)")
    }

    private var statDivider: some View {
        Rectangle()
            .fill(V371.Colors.divider)
            .frame(width: 0.5)
            .padding(.vertical, 14)
            .accessibilityHidden(true)
    }

    private func statCell(value: Int, label: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(V371.Colors.tinted(tint), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(V371.Type.rowTitle)
                    .foregroundStyle(V371.Colors.textPrimary)
                    .monospacedDigit()
                Text(label)
                    .font(V371.Type.rowSubtitle)
                    .foregroundStyle(V371.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    // MARK: 内容

    @ViewBuilder
    private var content: some View {
        if tab == .records {
            recordsContent
        } else if list.isEmpty {
            GroupSurface {
                EmptyState(
                    icon: "checkmark.circle",
                    title: TodoFilter.emptyText(for: tab),
                    message: nil
                )
            }
        } else {
            ForEach(groups, id: \.label) { group in
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(group.label)
                    GroupSurface {
                        ForEach(Array(group.items.enumerated()), id: \.element.persistentModelID) { index, todo in
                            if index > 0 { V371Divider() }
                            TodoListRow(
                                todo: todo,
                                isOverdueTab: tab == .overdue,
                                isFinishing: finishingIDs.contains(todo.persistentModelID),
                                onToggle: { toggle(todo) },
                                onEdit: { editingTodo = todo },
                                onDelete: { delete(todo) }
                            )
                        }
                    }
                }
            }
        }
    }

    /// 「备忘」tab：沿用 Memo 的既有卡片组件（非本分片范围，保持不动）
    private var recordsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if memos.isEmpty {
                GroupSurface {
                    EmptyState(icon: "note.text", title: "暂无备忘", message: nil)
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(memos.sorted { $0.updatedAt > $1.updatedAt }) { memo in
                        MemoCard(memo: memo, onEdit: { editingMemo = memo }, onDelete: { deleteMemo(memo) })
                    }
                }
            }
        }
    }

    private func deleteMemo(_ memo: Memo) {
        do { try MemoRepository(context: context).delete(memo); Haptic.warning() }
        catch { stateActionError = "备忘未删除，请重试。" }
    }

    /// 立即写库；动画只做视觉，不延迟业务保存。防重复点击：动画窗口内忽略同一项。
    private func toggle(_ todo: Todo) {
        let pid = todo.persistentModelID
        guard !togglingIDs.contains(pid) else { return }
        togglingIDs.insert(pid)
        finishingIDs.insert(pid)
        withAnimation(V32Motion.animation(V32Motion.resolve(.spring, reduceMotion: reduceMotion))) {
            do {
                try TodoRepository(context: context).toggleComplete(todo)
                todo.isCompleted ? Haptic.success() : Haptic.light()
            } catch {
                Haptic.error()
                stateActionError = "待办状态未改变，请重试。"
            }
        }
        // 数据已立即写库；仅视觉层暂留行 ~0.3s 后让其淡出移出
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            finishingIDs.remove(pid)
            togglingIDs.remove(pid)
        }
    }

    private func delete(_ todo: Todo) {
        deletingTodo = todo
    }
}

// MARK: - 分段选择器（V371 换肤：名称 / 初始化签名保持不变，供多处复用）

struct V32SegmentedPicker: View {
    let tabs: [String]
    @Binding var selectionIndex: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs.indices, id: \.self) { index in
                Button {
                    withAnimation(V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion))) {
                        selectionIndex = index
                    }
                    Haptic.light()
                } label: {
                    Text(tabs[index])
                        .font(V371.Type.rowSubtitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(index == selectionIndex ? V371.Colors.textPrimary : V371.Colors.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Capsule().fill(index == selectionIndex ? V371.Colors.group : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tabs[index])
                .accessibilityAddTraits(index == selectionIndex ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(V371.Colors.groupSecondary))
    }
}

// MARK: - 待办行（V371 WorkRow）
//
// 图标圆 = 优先级色（已完成 = 绿色对勾）；行点击 = 编辑；
// trailing = 时间 badge + 完成开关 + 删除按钮（删除仍走确认框流程）。

private struct TodoListRow: View {
    let todo: Todo
    let isOverdueTab: Bool
    var isFinishing = false
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        WorkRow(
            icon: rowIcon,
            iconColor: rowColor,
            title: DisplayText.visible(todo.title, fallback: "待办事项"),
            subtitle: subtitle,
            action: onEdit
        ) {
            HStack(spacing: 2) {
                StatusBadge(timeText, color: timeColor)
                toggleButton
                deleteButton
            }
        }
        .opacity(isFinishing ? 0 : 1)
        .scaleEffect(isFinishing && !reduceMotion ? 0.97 : 1)
        .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.98)))
    }

    /// 完成态用绿色对勾图标圆（§2.1 彩色微状态：绿 = 成功/已完成）
    private var rowIcon: String {
        if todo.isCompleted { return "checkmark" }
        switch todo.priorityLevel {
        case .high: return "flag.fill"
        case .medium: return "flag.fill"
        case .low: return "flag"
        }
    }

    private var rowColor: Color {
        if todo.isCompleted { return V371.Colors.green }
        switch todo.priorityLevel {
        case .high: return V371.Colors.red
        case .medium: return V371.Colors.orange
        case .low: return V371.Colors.gray
        }
    }

    private var toggleButton: some View {
        Button(action: onToggle) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(todo.isCompleted ? V371.Colors.green : V371.Colors.textTertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(todo.isCompleted ? "标为未完成" : "标为已完成")
    }

    /// 删除走确认框流程（与 V3.6 一致）；44pt 命中区
    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(V371.Colors.textTertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("删除待办")
    }

    private var subtitle: String {
        let detail = DisplayText.visible(todo.detail)
        if !detail.isEmpty { return detail }
        return todo.priorityLevel.label
    }

    private var timeText: String {
        // P1-3：与 HomeInbox / ScheduleAgenda 同一规则，00:00 显示为全天
        DayTimeLabel.label(todo.dueDate, unscheduledText: "待安排")
    }

    private var timeColor: Color {
        if isOverdueTab { return V371.Colors.orange }
        return V371.Colors.gray
    }
}

// MARK: - 新增记录 Sheet（功能保留，V371 外观）

private struct RecordEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var imageData: Data?
    @State private var selectedItem: PhotosPickerItem?

    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V371.Space.section) {
                header
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("记录内容")
                    GroupSurface {
                        TextField("记下这件事", text: $content, axis: .vertical)
                            .font(V371.Type.rowTitle)
                            .foregroundStyle(V371.Colors.textPrimary)
                            .tint(V371.Colors.blue)
                            .lineLimit(4...8)
                            .padding(.horizontal, V371.Space.rowPadding)
                            .padding(.vertical, 12)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("图片")
                    GroupSurface {
                        PhotoPickerField(imageData: imageData) { imageData = $0 }
                            .padding(.horizontal, V371.Space.rowPadding)
                            .padding(.vertical, 12)
                    }
                }
                saveButton
            }
            .padding(.horizontal, V371.Space.page)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .v371Canvas()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: selectedItem) { _, item in
            Task { imageData = try? await item?.loadTransferable(type: Data.self) }
        }
    }

    private var header: some View {
        ZStack {
            Text("新增记录")
                .font(V371.Type.sectionTitle)
                .foregroundStyle(V371.Colors.textPrimary)
            HStack {
                Button("取消") { dismiss() }
                    .font(V371.Type.rowTitle)
                    .foregroundStyle(V371.Colors.textSecondary)
                Spacer()
            }
        }
    }

    private var saveButton: some View {
        Button {
            Haptic.light()
            save()
        } label: {
            Text("保存")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    canSave ? V371.Colors.blue : V371.Colors.gray.opacity(0.35),
                    in: RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .accessibilityLabel("保存")
    }

    private func save() {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        try? MemoRepository(context: context).add(title: text, content: text, imageData: imageData)
        Haptic.success()
        dismiss()
    }
}
