import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 待办（V32）：仅负责 Todo 生命周期管理

struct TodoView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var todos: [Todo]
    @Query private var memos: [Memo]

    @State private var tab: TodoTab = .today
    @State private var showNewEditor = false
    @State private var showNewRecord = false
    @State private var editingTodo: Todo?
    @State private var togglingIDs: Set<PersistentIdentifier> = []
    /// 完成瞬间本地暂留的行：数据已写库，但视觉上留约 0.3s 做 fade/收缩后再移出（T21）
    @State private var finishingIDs: Set<PersistentIdentifier> = []

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
            VStack(alignment: .leading, spacing: 18) {
                header
                if tab != .records { statsCard }
                content
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32PageBottomInset()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showNewEditor) { TodoEditorSheet(todo: nil) }
        .sheet(isPresented: $showNewRecord) { RecordEditorSheet() }
        .sheet(item: $editingTodo) { TodoEditorSheet(todo: $0) }
    }

    // MARK: 顶部

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("待办")
                    .v32Text(.pageTitle)
                    .foregroundStyle(V32.textPrimary)
                Text("一件件来，不慌")
                    .v32Text(.subhead)
                    .foregroundStyle(V32.textTertiary)
            }
            Spacer()
            Button {
                if tab == .records { showNewRecord = true } else { showNewEditor = true }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: V32Layout.toolCircle, height: V32Layout.toolCircle)
                    .background(Circle().fill(V32.hero))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tab == .records ? "新增记录" : "新增待办")
        }
    }

    // MARK: 分段胶囊

    private var statsCard: some View {
        VStack(spacing: 14) {
            V32SegmentedPicker(tabs: TodoTab.allCases.map(\.rawValue), selectionIndex: Binding(
                get: { TodoTab.allCases.firstIndex(of: tab) ?? 0 },
                set: { tab = TodoTab.allCases[$0] }
            ))

            HStack(spacing: 8) {
                statCell(value: todayCount, label: "待办", icon: "sun.max", tint: V32.brand)
                statDivider
                statCell(value: doneCount, label: "已完成", icon: "checkmark.circle", tint: V32.textSecondary)
                statDivider
                statCell(value: overdueCount, label: "逾期", icon: "exclamationmark.circle",
                         tint: overdueCount > 0 ? V32.amber : V32.textTertiary)
            }
        }
    }

    private var statDivider: some View {
        Rectangle().fill(V32.divider).frame(width: 1, height: 30)
    }

    private func statCell(value: Int, label: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .v32Text(.metricSmall)
                    .foregroundStyle(V32.textPrimary)
                    .monospacedDigit()
                Text(label)
                    .v32Text(.caption)
                    .foregroundStyle(V32.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(tint)
    }

    // MARK: 内容

    @ViewBuilder
    private var content: some View {
        if tab == .records {
            recordsContent
        } else if list.isEmpty {
            V32Card {
                V32EmptyState(
                    systemName: "checkmark.circle",
                    title: TodoFilter.emptyText(for: tab),
                    message: nil
                )
                .padding(.vertical, 8)
            }
        } else {
            ForEach(groups, id: \.label) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.label)
                        .v32Text(.caption)
                        .foregroundStyle(V32.textTertiary)
                        .padding(.leading, 4)
                    V32Card(padding: 4) {
                        VStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.element.persistentModelID) { index, todo in
                                if index > 0 {
                                    Rectangle().fill(V32.divider).frame(height: 1).padding(.leading, 48)
                                }
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
    }

    private var recordsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if memos.isEmpty {
                V32Card {
                    V32EmptyState(systemName: "note.text", title: "暂无记录", message: nil)
                        .padding(.vertical, 8)
                }
            } else {
                V32Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(memos.sorted { $0.updatedAt > $1.updatedAt }.enumerated()), id: \.element.persistentModelID) { index, memo in
                            if index > 0 { Rectangle().fill(V32.divider).frame(height: 1).padding(.leading, 48) }
                            HStack(spacing: 12) {
                                V32IconBubble(systemName: "note.text", tone: .neutral, size: 34, icon: 15)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(memo.title)
                                        .v32Text(.title)
                                        .foregroundStyle(V32.textPrimary)
                                        .lineLimit(2)
                                    Text(Fmt.shortDateTime(memo.updatedAt))
                                        .v32Text(.caption)
                                        .foregroundStyle(V32.textTertiary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 54)
                        }
                    }
                }
            }
        }
    }

    /// 立即写库；动画只做视觉，不延迟业务保存。防重复点击：动画窗口内忽略同一项。
    private func toggle(_ todo: Todo) {
        let pid = todo.persistentModelID
        guard !togglingIDs.contains(pid) else { return }
        togglingIDs.insert(pid)
        finishingIDs.insert(pid)
        Haptic.light()
        withAnimation(V32Motion.animation(V32Motion.resolve(.spring, reduceMotion: reduceMotion))) {
            try? TodoRepository(context: context).toggleComplete(todo)
        }
        // 数据已立即写库；仅视觉层暂留行 ~0.3s 后让其淡出移出
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            finishingIDs.remove(pid)
            togglingIDs.remove(pid)
        }
    }

    private func delete(_ todo: Todo) {
        Haptic.warning()
        try? TodoRepository(context: context).delete(todo)
    }
}

// MARK: - 分段选择器（V32 胶囊）

struct V32SegmentedPicker: View {
    let tabs: [String]
    @Binding var selectionIndex: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs.indices, id: \.self) { index in
                Button {
                    withAnimation(V32Motion.quick) { selectionIndex = index }
                    Haptic.light()
                } label: {
                    Text(tabs[index])
                        .v32Text(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(index == selectionIndex ? V32.textPrimary : V32.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(index == selectionIndex ? V32.card : Color.clear)
                        )
                        .overlay(
                            Capsule().strokeBorder(index == selectionIndex ? V32.cardOutline : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(V32.pageBGSecondary))
    }
}

// MARK: - 待办行

private struct TodoListRow: View {
    let todo: Todo
    let isOverdueTab: Bool
    var isFinishing = false
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            V32Checkbox(checked: todo.isCompleted, action: onToggle)
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(DisplayText.visible(todo.title, fallback: "待办事项"))
                        .v32Text(.title)
                        .foregroundStyle(todo.isCompleted ? V32.textTertiary : V32.textPrimary)
                        .strikethrough(todo.isCompleted, color: V32.textQuaternary)
                        .lineLimit(2)
                    Text(subtitle)
                        .v32Text(.caption)
                        .foregroundStyle(todo.priority >= TodoPriority.high.rawValue && !todo.isCompleted ? V32.amber : V32.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(timeText)
                .v32Text(.caption)
                .foregroundStyle(isOverdueTab ? V32.amber : V32.textTertiary)
                .lineLimit(1)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(V32.textQuaternary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除待办")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .opacity(isFinishing ? 0 : 1)
        .scaleEffect(isFinishing && !reduceMotion ? 0.97 : 1)
        .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.98)))
    }

    private var subtitle: String {
        let detail = DisplayText.visible(todo.detail)
        if !detail.isEmpty { return detail }
        return todo.priorityLevel.label
    }

    private var timeText: String {
        guard let due = todo.dueDate else { return "待安排" }
        if due.isToday { return Fmt.time(due) }
        return Fmt.monthDayTime(due)
    }
}

// MARK: - 新增记录 Sheet（功能保留，T11 统一 V32 外观）

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
            VStack(alignment: .leading, spacing: 16) {
                header
                VStack(alignment: .leading, spacing: 10) {
                    V32SectionHeader("记录内容")
                    V32Card {
                        TextField("记下这件事", text: $content, axis: .vertical)
                            .v32Text(.body)
                            .foregroundStyle(V32.textPrimary)
                            .tint(V32.brand)
                            .lineLimit(4...8)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    V32SectionHeader("图片")
                    V32Card { PhotoPickerField(imageData: imageData) { imageData = $0 } }
                }
                V32PrimaryButton(title: "保存", systemName: "checkmark") { save() }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 14)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32Sheet([.medium, .large])
        .onChange(of: selectedItem) { _, item in
            Task { imageData = try? await item?.loadTransferable(type: Data.self) }
        }
    }

    private var header: some View {
        ZStack {
            Text("新增记录").v32Text(.headline).foregroundStyle(V32.textPrimary)
            HStack {
                Button("取消") { dismiss() }
                    .v32Text(.body)
                    .foregroundStyle(V32.textTertiary)
                Spacer()
            }
        }
    }

    private func save() {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        try? MemoRepository(context: context).add(title: text, content: text, imageData: imageData)
        Haptic.success()
        dismiss()
    }
}
