import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 待办：V3.8 重建（Editorial 平面列表 + 勾选状态回执）
//
// 视觉：平面列表 + 细分割线、Editorial 进度头（大数字/留白/低密度），与 R1 Home 同语言。
// 勾选：两段式回执（规格 `Docs/V38-Page-Motion-Spec.md` §2，G5 铁律）——
// 点按先进「保存中」态，Repository 回写成功后才渲染完成态；失败抖动 + 行内重试。
// 过滤 / 优先级 / 排序 / 图片 / 提醒 / persistence 语义全部保持 V3.6 原样，只做 presentation 迁移。

struct TodoView: View {
    /// V3.9.1 P1-4:首页 chips 写入的筛选请求(RootView 注入,缺省为独立实例)。
    var todoNavigation: TodoNavigationState = TodoNavigationState()
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
    /// 保存成功后本地暂留的行：数据已写库，行以完成态视觉停留约 0.7s 后再按过滤规则移出。
    @State private var lingeringIDs: Set<PersistentIdentifier> = []
    /// 每行勾选状态机（C 线纯逻辑 `V38PageMotionState`）：saving/failed 期间驱动回执 UI。
    @State private var toggleMachines: [PersistentIdentifier: V38PageMotionState] = [:]
    /// 每行失败抖动触发计数（+1 播放一次）。
    @State private var shakeTriggers: [PersistentIdentifier: Int] = [:]
    @State private var deletingTodo: Todo?
    @State private var deleteError: String?
    @State private var stateActionError: String?
    @State private var failedToggleTodo: Todo?

    private var list: [Todo] {
        if tab == .records { return [] }
        let base = TodoFilter.todos(for: tab, in: todos)
        let lingering = todos.filter { lingeringIDs.contains($0.persistentModelID) }
        var seen = Set(base.map(\.persistentModelID))
        return base + lingering.filter { seen.insert($0.persistentModelID).inserted }
    }

    private var groups: [(label: String, items: [Todo])] {
        if tab == .done { return list.isEmpty ? [] : [(label: "已完成", items: list)] }
        return TodoFilter.grouped(list)
    }

    // V3.9.1 P1-7:四项计数一次遍历产出(旧代码每项各 filter 全量一次)。
    private var counts: TodoCounts { TodoCounts.build(todos: todos) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V371.Space.section) {
                // 切换控件始终可见；「备忘」展示独立 Memo 内容。
                // 只隐藏进度区域，不隐藏 tab 导航。
                tabPicker
                if tab != .records { progressHeader(counts: counts) }
                content
                V371ScrollEndMarker(identifier: V371AccessibilityID.scrollEndTodo)
            }
            .padding(.horizontal, V371.Space.page)
            .padding(.top, 8)
            .padding(.bottom, V371.Space.section)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if let requested = todoNavigation.consume() { tab = requested }
        }
        .onChange(of: todoNavigation.requestedTab) { _, newValue in
            if let newValue {
                tab = newValue
                todoNavigation.requestedTab = nil
            }
        }
        .accessibilityIdentifier(V371AccessibilityID.screenTodo)
        .v371Canvas()
        // V3.8.1 P0-2：共享浮动 Tab 栏底部避让（safeAreaInset，非内容内 Spacer）。
        .v32PageBottomInset()
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
                    let pid = todo.persistentModelID
                    do {
                        try TodoRepository(context: context).delete(todo)
                        toggleMachines[pid] = nil
                        lingeringIDs.remove(pid)
                        togglingIDs.remove(pid)
                        Haptic.warning()
                    }
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
            Button("重试") {
                stateActionError = nil
                if let todo = failedToggleTodo {
                    // 失败态保留在 toggleMachines 中；toggle() 从 failed 态走同一重试入口。
                    toggle(todo)
                }
            }
            .accessibilityIdentifier(V371AccessibilityID.reliabilityRetry)
            Button("取消", role: .cancel) {
                stateActionError = nil
                failedToggleTodo = nil
                // 行内失败条保留，用户仍可从行内重试或放弃。
            }
        } message: { Text(stateActionError ?? "待办状态未改变，请重试") }
    }

    // MARK: 分段导航 + Editorial 进度头

    /// P0-2：tab 导航独立于进度区，任何 tab 下都可见
    private var tabPicker: some View {
        TodoSegmentedPicker(tabs: TodoTab.allCases.map(\.rawValue), selectionIndex: Binding(
            get: { TodoTab.allCases.firstIndex(of: tab) ?? 0 },
            set: { tab = TodoTab.allCases[$0] }
        ))
    }

    /// V3.8 Editorial 进度头：大数字 + 细进度条，低密度呈现（仅非「备忘」tab 显示）。
    private func progressHeader(counts: TodoCounts) -> some View {
        let progress = V38TodoProgress(
            pendingToday: counts.today,
            completed: counts.done,
            overdue: counts.overdue,
            pendingTotal: counts.pendingTotal
        )
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                progressCell(value: progress.pendingToday, label: "今日待办", tint: V371.Colors.textPrimary)
                progressCell(value: progress.completed, label: "已完成", tint: V38TodoStyle.businessGreen)
                progressCell(
                    value: progress.overdue,
                    label: "逾期",
                    tint: progress.overdue > 0 ? V371.Colors.red : V371.Colors.textTertiary
                )
            }
            // 整体完成进度（已完成 / 全部待办），细条呈现，不抢视觉。
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(V371.Colors.divider.opacity(0.6))
                    Capsule()
                        .fill(V38TodoStyle.businessGreen)
                        .frame(width: max(0, geo.size.width * progress.fraction))
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今日待办 \(progress.pendingToday)，已完成 \(progress.completed)，逾期 \(progress.overdue)，整体进度百分之\(progress.percent)")
        .accessibilityIdentifier(V38TodoAccessibilityID.progress)
    }

    private func progressCell(value: Int, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(V38TodoStyle.statNumber)
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(label)
                .font(V38TodoStyle.statLabel)
                .foregroundStyle(V371.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .animation(V38MotionTokens.animation(for: .contentChange, reduceMotion: reduceMotion), value: value)
    }

    // MARK: 内容

    @ViewBuilder
    private var content: some View {
        if tab == .records {
            recordsContent
        } else if list.isEmpty {
            EmptyState(
                icon: "checkmark.circle",
                title: TodoFilter.emptyText(for: tab),
                message: TodoFilter.emptyMessage(for: tab)
            )
            .padding(.top, 24)
        } else {
            ForEach(groups, id: \.label) { group in
                VStack(alignment: .leading, spacing: 8) {
                    V38TodoSectionHeader(title: group.label)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(group.items.enumerated()), id: \.element.persistentModelID) { index, todo in
                            if index > 0 { V371Divider(leading: V38TodoStyle.dividerLeading) }
                            TodoListRow(
                                todo: todo,
                                isOverdueTab: tab == .overdue,
                                suppressFailureBar: stateActionError != nil,
                                phase: phase(for: todo),
                                shakeTrigger: shakeTriggers[todo.persistentModelID, default: 0],
                                onToggle: { toggle(todo) },
                                onRetry: { toggle(todo) },
                                onDismissFailure: { dismissFailure(todo) },
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

    /// 行的当前勾选相位：有在途/失败状态机时以状态机为准，否则以已落库的模型态为准。
    private func phase(for todo: Todo) -> V38PageTogglePhase {
        toggleMachines[todo.persistentModelID]?.phase ?? .idle(isDone: todo.isCompleted)
    }

    /// 两段式勾选（规格 §2 / G5）：先渲染「保存中」，回写成功后才渲染完成态。
    /// 防重复点击：保存窗口内忽略同一项（失败态点按 = 重试，走同一入口）。
    private func toggle(_ todo: Todo) {
        let pid = todo.persistentModelID
        guard !togglingIDs.contains(pid) else { return }
        let current = toggleMachines[pid] ?? V38PageMotionState(isDone: todo.isCompleted)
        guard let saving = V38TodoToggleFlow.begin(from: current) else { return }
        toggleMachines[pid] = saving
        togglingIDs.insert(pid)
        announce("正在保存")
        Task { @MainActor in
            let resolved = V38TodoToggleFlow.resolve(saving) {
                try UITestFailureInjection.throwIfRequested(.todoToggle)
                try TodoRepository(context: context).toggleComplete(todo)
            }
            if case .failed = resolved.phase {
                // 失败：回到未勾选态（模型未变），抖动 + 行内重试 + 既有失败 alert。
                toggleMachines[pid] = resolved
                togglingIDs.remove(pid)
                failedToggleTodo = todo
                Haptic.error()
                shakeTriggers[pid, default: 0] += 1
                announce("保存失败，可重试")
                stateActionError = "待办状态未改变，请重试。"
            } else {
                // 成功回执到达后才允许完成态渲染（模型已由 Repository 更新）。
                toggleMachines[pid] = resolved
                failedToggleTodo = nil
                if todo.isCompleted { Haptic.success() } else { Haptic.light() }
                announce("已保存")
                // 视觉层以完成态停留约 0.7s 后，再按过滤规则移出当前列表。
                lingeringIDs.insert(pid)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    withAnimation(V38MotionTokens.animation(for: .contentChange, reduceMotion: reduceMotion)) {
                        lingeringIDs.remove(pid)
                    }
                    togglingIDs.remove(pid)
                    toggleMachines[pid] = nil
                }
            }
        }
    }

    /// 放弃失败重试：状态机回到点按前的已确认态，行内失败条消失。
    private func dismissFailure(_ todo: Todo) {
        let pid = todo.persistentModelID
        toggleMachines[pid]?.dismissFailure()
        toggleMachines[pid] = nil
        if failedToggleTodo?.persistentModelID == pid { failedToggleTodo = nil }
    }

    private func delete(_ todo: Todo) {
        deletingTodo = todo
    }

    /// VoiceOver 状态播报（保存中 / 已保存 / 保存失败可重试）。
    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}

// MARK: - 分段选择器（名称 / 初始化签名保持不变，供多处复用；V3.8 仅调整选中态配色）

struct TodoSegmentedPicker: View {
    let tabs: [String]
    @Binding var selectionIndex: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs.indices, id: \.self) { index in
                Button {
                    withAnimation(V371.Motion.animation(V371.Motion.resolve(.fade, reduceMotion: reduceMotion))) {
                        selectionIndex = index
                    }
                    Haptic.light()
                } label: {
                    Text(tabs[index])
                        .font(V371.Typography.rowSubtitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(index == selectionIndex ? V371.Colors.textPrimary : V371.Colors.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Capsule().fill(index == selectionIndex ? V38TodoStyle.businessGreen.opacity(0.15) : Color.clear)
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

// MARK: - 待办行（V3.8 Editorial 平面行 + 勾选回执）
//
// 图标圆 = 优先级色（已完成 = 绿色对勾）；行点击 = 编辑；
// 复选框按相位渲染：保存中 = 转圈（不宣告成功）、完成 = 填充 + 行 0.55 透明 + 删除线、
// 失败 = 红点 + 抖动 + 行内重试。trailing = 时间 badge + 菜单（删除走确认框流程）。

private struct TodoListRow: View {
    let todo: Todo
    let isOverdueTab: Bool
    /// V3.9.1 P1-11:模态失败 Alert 在位时行内失败条隐藏,避免同一失败双通道重复提示;
    /// Alert 取消后状态机仍为 failed,行内条恢复(重试入口不丢)。
    var suppressFailureBar: Bool = false
    let phase: V38PageTogglePhase
    var shakeTrigger: Int = 0
    let onToggle: () -> Void
    let onRetry: () -> Void
    let onDismissFailure: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isSaving: Bool {
        if case .saving = phase { return true }
        return false
    }

    /// 只有已落库确认的完成态才为 true —— 保存中/失败一律 false（G5）。
    private var showsChecked: Bool {
        if case .idle(let isDone) = phase { return isDone }
        return false
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                toggleButton
                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(DisplayText.visible(todo.title, fallback: "待办事项"))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(showsChecked ? V371.Colors.textTertiary : V371.Colors.textPrimary)
                            .strikethrough(showsChecked, color: V371.Colors.textTertiary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ViewThatFits(in: .horizontal) {
                            metadataLine
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Label(todo.priorityLevel.label, systemImage: rowIcon)
                                        .foregroundStyle(rowColor)
                                    Text(timeText)
                                        .foregroundStyle(timeColor)
                                }
                                if !subtitle.isEmpty {
                                    Text(subtitle)
                                        .foregroundStyle(V371.Colors.textTertiary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .font(.footnote)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("编辑 \(DisplayText.visible(todo.title, fallback: "待办事项"))")
                deleteMenu
            }
            .opacity(showsChecked ? 0.55 : 1)
            if isFailed && !suppressFailureBar { failureBar }
        }
        .padding(.vertical, 10)
        .frame(minHeight: V38TodoStyle.rowMinHeight)
        .modifier(V38ShakeEffect(
            travel: reduceMotion ? 0 : 6,
            animatableData: CGFloat(shakeTrigger)
        ))
        .animation(V38MotionTokens.animation(for: .contentChange, reduceMotion: reduceMotion), value: shakeTrigger)
        .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.98)))
    }

    /// 失败行内条：文案 + 重试 + 放弃（规格 §2；Reduce Motion 下以此静态条 + 红点传达）。
    private var failureBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(V371.Colors.red)
            Text("保存失败，可重试")
                .foregroundStyle(V371.Colors.red)
            Spacer()
            Button("重试", action: onRetry)
                .fontWeight(.bold)
                .foregroundStyle(V38TodoStyle.businessGreen)
                .accessibilityIdentifier(V38TodoAccessibilityID.inlineRetry)
            Button("放弃", action: onDismissFailure)
                .foregroundStyle(V371.Colors.textTertiary)
                .accessibilityIdentifier(V38TodoAccessibilityID.inlineDismiss)
        }
        .font(.footnote)
        .padding(.leading, V38TodoStyle.dividerLeading)
        .padding(.top, 8)
        .transition(.opacity)
    }

    /// 完成态用绿色对勾图标圆（§2.1 彩色微状态：绿 = 成功/已完成）
    private var rowIcon: String {
        if showsChecked { return "checkmark" }
        switch todo.priorityLevel {
        case .high: return "flag.fill"
        case .medium: return "flag.fill"
        case .low: return "flag"
        }
    }

    private var rowColor: Color {
        if showsChecked { return V371.Colors.green }
        switch todo.priorityLevel {
        case .high: return V371.Colors.red
        case .medium: return V371.Colors.orange
        case .low: return V371.Colors.gray
        }
    }

    private var toggleButton: some View {
        Button(action: onToggle) {
            ZStack {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                } else if showsChecked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(V371.Colors.green)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(rowColor)
                }
                if isFailed {
                    Circle()
                        .fill(V371.Colors.red)
                        .frame(width: 10, height: 10)
                        .offset(x: 13, y: -13)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: V38TodoStyle.toggleHitSize, height: V38TodoStyle.toggleHitSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(V38TodoToggleButtonStyle(reduceMotion: reduceMotion))
        .disabled(isSaving)
        .accessibilityLabel(todo.isCompleted ? "标为未完成" : "标为已完成")
        .accessibilityValue(accessibilityPhaseValue)
        .accessibilityIdentifier(V371AccessibilityID.todoToggle)
    }

    /// VoiceOver 状态值：与播报口径一致（正在保存 / 已保存结果 / 保存失败可重试）。
    private var accessibilityPhaseValue: String {
        if isSaving { return "正在保存" }
        if isFailed { return "保存失败，可重试" }
        return showsChecked ? "已完成" : "未完成"
    }

    /// 编辑与删除收进原生菜单，减少行尾竞争；删除仍走原确认流程。
    private var deleteMenu: some View {
        Menu {
            Button("编辑待办", systemImage: "pencil", action: onEdit)
            Button("删除待办", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(V371.Colors.textTertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        // P1-11:菜单本身的无障碍标签必须是「更多操作」,不得误标为「删除待办」。
        .accessibilityLabel("更多操作")
        .accessibilityHint("打开编辑或删除操作菜单")
    }

    private var subtitle: String {
        let detail = DisplayText.visible(todo.detail)
        return detail
    }

    private var metadataLine: some View {
        HStack(spacing: 6) {
            Label(todo.priorityLevel.label, systemImage: rowIcon)
                .foregroundStyle(rowColor)
            Text("·")
                .foregroundStyle(V371.Colors.textTertiary)
            Text(timeText)
                .foregroundStyle(timeColor)
            if !subtitle.isEmpty {
                Text("·")
                    .foregroundStyle(V371.Colors.textTertiary)
                Text(subtitle)
                    .foregroundStyle(V371.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
        .lineLimit(1)
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

/// 复选框按压反馈（规格 §2：按下 scale 0.92 → 弹回；Reduce Motion 时不缩放）。
private struct V38TodoToggleButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .animation(V38MotionTokens.animation(for: .press, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

// MARK: - 新增记录 Sheet（功能保留，V371 外观）

private struct RecordEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var imageData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var saveError: String?

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
                            .font(V371.Typography.rowTitle)
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
        .alert("保存失败", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("重试") { save() }
            Button("取消", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "请稍后重试") }
    }

    private var header: some View {
        ZStack {
            Text("新增记录")
                .font(V371.Typography.sectionTitle)
                .foregroundStyle(V371.Colors.textPrimary)
            HStack {
                Button("取消") { dismiss() }
                    .font(V371.Typography.rowTitle)
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
        do {
            try MemoRepository(context: context).add(title: text, content: text, imageData: imageData)
            Haptic.success()
            dismiss()
        } catch {
            Haptic.error()
            saveError = "记录未保存，请重试。"
        }
    }
}
