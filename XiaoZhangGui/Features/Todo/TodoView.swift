import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 待办页（V2.1：大标题 + 玻璃 Tab + 时间轴 + 分组 + swipeActions + FAB）
// 语义对齐 Android TodoScreen / TodoViewModel.todosForTab

struct TodoView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query private var todos: [Todo]
    @Query private var memos: [Memo]

    @State private var tab: TodoTab = .today
    @State private var showNewEditor = false
    @State private var showNewRecord = false
    @State private var editingTodo: Todo?

    private var list: [Todo] {
        if tab == .records { return [] }
        return TodoFilter.todos(for: tab, in: todos)
    }

    private var isMockPreview: Bool { RuntimeMode.allowsMockData }

    private var mockItems: [MockTodoItem] {
        switch tab {
        case .today: return [
            .init("09:30", "供应商送货", "确认饮料、矿泉水数量", "高优先级", 2),
            .init("11:00", "清点饮料库存", "可乐 / 矿泉水 / 功能饮料", "中优先级", 1),
            .init("15:00", "联系饮料供应商", "确认下周进货价格", "中优先级", 1),
            .init("18:30", "盘点冰柜", "检查缺货和临期", "低优先级", 0),
            .init("21:00", "核对今日营业额", "核对微信 / 支付宝 / 现金", "低优先级", 0)
        ]
        case .tomorrow: return [.init("09:00", "联系面包供应商", "", "中优先级", 1), .init("14:00", "退临期牛奶", "", "高优先级", 2), .init("19:30", "整理客户配送记录", "", "低优先级", 0)]
        case .overdue: return [.init("昨天 16:00", "联系泳装供应商", "", "高优先级", 2), .init("昨天 20:00", "登记冰柜维修", "", "中优先级", 1)]
        case .done: return [.init("08:30", "开店检查", "已完成", "已完成", 0, true), .init("09:00", "补充收银台零钱", "已完成", "已完成", 0, true), .init("10:00", "确认302别墅配送", "已完成", "已完成", 0, true)]
        case .records: return []
        }
    }

    private var groups: [(label: String, items: [Todo])] {
        if tab == .done {
            return list.isEmpty ? [] : [(label: "已完成", items: list)]
        }
        return TodoFilter.grouped(list)
    }

    private var subtitle: String {
        if isMockPreview {
            switch tab { case .today: return "今天还有 5 件事"; case .tomorrow: return "明天还有 3 件事"; case .overdue: return "逾期 2 件"; case .done: return "已完成 3 件"; case .records: return "记录" }
        }
        if tab == .done {
            return "已完成 \(list.count) 件"
        }
        let remaining = list.count { !$0.isCompleted }
        return "还剩 \(remaining) 件待完成"
    }

    var body: some View {
        PageBackground {
            ZStack(alignment: .bottomTrailing) {
                List {
                    titleSection
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: V21Layout.spaceXL, leading: V21Layout.pageMargin, bottom: 6, trailing: V21Layout.pageMargin))

                    PillTabRow(items: TodoTab.allCases, label: { tab in
                        guard isMockPreview else { return tab.rawValue }
                        let count: Int
                        switch tab {
                        case .today: count = 5
                        case .tomorrow: count = 3
                        case .overdue: count = 2
                        case .done: count = 3
                        case .records: count = 0
                        }
                        return "\(tab.rawValue) \(count)"
                    }, selection: $tab)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 6, trailing: 0))

                    if tab == .today {
                        todayFocus
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: V21Layout.pageMargin, bottom: 14, trailing: V21Layout.pageMargin))
                    }

                    if isMockPreview && tab != .records {
                        ForEach(Array(mockItems.enumerated()), id: \.element.id) { index, item in
                            MockTimelineTodoRow(item: item, palette: AppTheme.palette(named: settings.appThemeName), isNext: tab == .today && index == 0)
                                .listRowSeparator(.hidden).listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 0, leading: V21Layout.pageMargin, bottom: 0, trailing: V21Layout.pageMargin))
                        }
                    } else if tab == .records {
                        ForEach(memos.sorted { $0.updatedAt > $1.updatedAt }) { memo in
                            MemoRecordRow(memo: memo).listRowSeparator(.hidden).listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: V21Layout.pageMargin, bottom: 10, trailing: V21Layout.pageMargin))
                        }
                    } else if list.isEmpty {
                        EmptyStateView(text: TodoFilter.emptyText(for: tab))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    } else {
                        ForEach(groups, id: \.label) { group in
                            Section {
                                ForEach(group.items) { todo in
                                    TimelineTodoRow(todo: todo, showDate: tab == .overdue, isNext: todo.id == list.first?.id) {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            try? TodoRepository(context: context).toggleComplete(todo)
                                        }
                                    } onEdit: {
                                        editingTodo = todo
                                    }
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 0, leading: V21Layout.pageMargin, bottom: 0, trailing: V21Layout.pageMargin))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            delete(todo)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                Text(group.label)
                                    .v21Style(.labelMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(V21.groupTitle)
                            }
                        }
                    }

                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: V21Layout.bottomDockContentGap) }

            }
        }
        .sheet(isPresented: $showNewEditor) {
            TodoEditorSheet(todo: nil)
        }
        .sheet(isPresented: $showNewRecord) { RecordEditorSheet() }
        .sheet(item: $editingTodo) { todo in
            TodoEditorSheet(todo: todo)
        }
    }

    private var titleSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("待办").font(AppTypography.pageTitle).foregroundColor(V21.textPrimary)
                Text(subtitle).font(AppTypography.bodyMedium).foregroundColor(V21.textTertiary)
            }
            Spacer()
            Button { if tab == .records { showNewRecord = true } else { showNewEditor = true }; Haptic.light() } label: {
                Label(tab == .records ? "记录" : "新建", systemImage: "plus").font(AppTypography.bodyMedium).foregroundColor(AppTheme.palette(named: settings.appThemeName).accent)
            }.buttonStyle(.plain)
        }
    }

    private var todayFocus: some View {
        let highCount = isMockPreview ? 1 : list.filter { $0.priority >= 2 }.count
        let nextText: String? = {
            if isMockPreview, let next = mockItems.first { return "下一件 \(next.time)  \(next.title)" }
            if let next = list.first, let due = next.dueDate { return "下一件 \(Fmt.time(due))  \(next.title)" }
            return nil
        }()
        return VStack(alignment: .leading, spacing: 5) {
            Text("TODAY").font(AppTypography.micro).tracking(1.4).foregroundColor(V21.textTertiary)
            Text("\(isMockPreview ? 5 : list.count) 件待办 · \(highCount) 件高优先级").font(AppTypography.bodyMedium).foregroundColor(V21.textSecondary)
            if let nextText { Text(nextText).font(AppTypography.caption).foregroundColor(V21.textTertiary) }
        }
        .padding(.leading, 2)
        .padding(.bottom, 2)
    }

    private func delete(_ todo: Todo) {
        Haptic.warning()
        try? TodoRepository(context: context).delete(todo)
    }
}

private struct MemoRecordRow: View {
    let memo: Memo
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(memo.title).font(AppTypography.cardTitle).foregroundColor(V21.textPrimary); Spacer(); Text(Fmt.shortDateTime(memo.updatedAt)).font(AppTypography.micro).foregroundColor(V21.textTertiary) }
            Text(memo.content).font(AppTypography.body).foregroundColor(V21.textSecondary).lineLimit(3)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(V21.surfaceGlass, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(V21.divider.opacity(0.5)))
    }
}

private struct RecordEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var content = ""
    @State private var imageData: Data?
    @State private var selectedItem: PhotosPickerItem?
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("记录内容").font(AppTypography.cardTitle).foregroundColor(V21.textPrimary)
                TextEditor(text: $content).font(AppTypography.body).frame(minHeight: 150).padding(8).background(V21.surfaceGlass, in: RoundedRectangle(cornerRadius: 14))
                PhotosPicker(selection: $selectedItem, matching: .images) { Label("添加图片（可选）", systemImage: "photo").font(AppTypography.bodyMedium).foregroundColor(AppTheme.palette(named: settings.appThemeName).accent) }
                Spacer()
            }.padding(20).navigationTitle("新增记录").navigationBarTitleDisplayMode(.inline).toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }.onChange(of: selectedItem) { _, item in Task { imageData = try? await item?.loadTransferable(type: Data.self) } }
        }
    }
    private func save() {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        context.insert(Memo(title: text, content: text, imageData: imageData))
        try? context.save(); Haptic.success(); dismiss()
    }
}

private struct MockTodoItem: Identifiable {
    let id = UUID()
    let time: String
    let title: String
    let detail: String
    let priority: String
    let level: Int
    let completed: Bool
    init(_ time: String, _ title: String, _ detail: String, _ priority: String, _ level: Int, _ completed: Bool = false) {
        self.time = time; self.title = title; self.detail = detail; self.priority = priority; self.level = level; self.completed = completed
    }
}

private struct MockTimelineTodoRow: View {
    let item: MockTodoItem
    let palette: AppThemePalette
    let isNext: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Button {} label: {
                    ZStack {
                        Circle().fill(item.completed ? palette.accent : (isNext ? palette.accent.opacity(0.12) : V21.background))
                        if item.completed { Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundColor(.white) }
                    }.frame(width: 22, height: 22).overlay(Circle().stroke(item.completed ? palette.accent : priorityColor, lineWidth: 1.5))
                }.buttonStyle(.plain).accessibilityLabel(item.completed ? "恢复为未完成" : "标记为已完成")
                Rectangle().fill(V21.timeline.opacity(0.65)).frame(width: 1, height: 62)
            }.frame(width: 22)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(item.time).font(AppTypography.bodyMedium).foregroundColor(V21.textTertiary).frame(width: 68, alignment: .leading)
                    Text(item.title).font(AppTypography.cardTitle).fontWeight(isNext ? .semibold : .medium).foregroundColor(item.completed ? V21.textTertiary : V21.textPrimary).strikethrough(item.completed)
                    if isNext { Text("下一件").font(AppTypography.micro).foregroundColor(palette.accent).padding(.horizontal, 6).padding(.vertical, 3).background(palette.accent.opacity(0.10), in: Capsule()) }
                }
                HStack(spacing: 8) {
                    if !item.detail.isEmpty { Text(item.detail).font(AppTypography.caption).foregroundColor(V21.textTertiary).lineLimit(1) }
                    Spacer(minLength: 2)
                    Circle().fill(priorityColor).frame(width: 6, height: 6)
                    Text(item.completed ? "已完成" : (item.level == 2 ? "高" : item.level == 1 ? "中" : "低")).font(AppTypography.micro).foregroundColor(item.completed ? V21.textTertiary : priorityColor)
                }
            }.padding(.bottom, 17)
        }
    }

    private var priorityColor: Color {
        if item.completed { return V21.textTertiary }
        switch item.level { case 2: return V21.danger; case 1: return palette.accent; default: return V21.textTertiary }
    }
}

// MARK: - 时间轴待办行（左侧细线 + 节点圆点，对齐 Android TimelineTodoRow）

struct TimelineTodoRow: View {
    let todo: Todo
    var showDate: Bool = false
    var isNext: Bool = false
    var onToggle: () -> Void
    var onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // 时间轴 + 节点
            timelineColumn
                .frame(maxHeight: .infinity, alignment: .top)

            // 内容
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(todo.title)
                        .v21Style(.bodyLarge)
                        .fontWeight(.medium)
                        .foregroundColor(todo.isCompleted ? V21.textTertiary : V21.textPrimary)
                        .fontWeight(isNext ? .semibold : .medium)
                        .strikethrough(todo.isCompleted, color: V21.textTertiary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        if todo.isCompleted, let completedAt = todo.completedAt {
                            Text("完成于 \(Fmt.shortDateTime(completedAt))")
                                .v21Style(.labelMedium)
                                .foregroundColor(V21.textTertiary)
                        } else if let due = todo.dueDate {
                            Text(showDate ? Fmt.monthDayTime(due) : Fmt.time(due))
                                .v21Style(.labelMedium)
                                .foregroundColor(V21.textTertiary)
                        }
                        PriorityDot(level: todo.isCompleted ? 0 : todo.priority)
                        Text(shortPriority(todo.priorityLevel))
                            .v21Style(.labelMedium)
                            .foregroundColor(priorityColor)
                        if todo.imageData != nil {
                            Image(systemName: "photo")
                                .font(.system(size: 11))
                                .foregroundColor(V21.textQuaternary)
                        }
                    }

                    if let data = todo.imageData {
                        ImageThumb(imageData: data, size: 44)
                    }
                }
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var timelineColumn: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(V21.timeline.opacity(0.65))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .offset(x: 0, y: 14)

            Button {
                Haptic.light()
                withAnimation(.easeOut(duration: 0.2)) { onToggle() }
            } label: {
                ZStack {
                    Circle()
                        .fill(todo.isCompleted ? AnyShapeStyle(V21.brandGreen) : AnyShapeStyle(V21.background))
                    if todo.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 22, height: 22)
                .overlay {
                    Circle()
                        .strokeBorder(todo.isCompleted ? V21.brandGreen : V21.timelineDotBorder, lineWidth: 1.5)
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isCompleted ? "恢复为未完成" : "标记为已完成")
        }
        .frame(width: 22)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var priorityColor: Color {
        guard !todo.isCompleted else { return V21.textTertiary }
        switch todo.priority {
        case 2: return V21.danger
        case 1: return V21.info
        default: return V21.textTertiary
        }
    }

    private func shortPriority(_ level: TodoPriority) -> String {
        switch level { case .high: return "高"; case .medium: return "中"; case .low: return "低" }
    }
}
