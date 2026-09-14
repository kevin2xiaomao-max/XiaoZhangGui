import SwiftUI
import SwiftData
import PhotosUI

struct TodoView: View {
    @Environment(\.modelContext) private var context
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

    private var groups: [(label: String, items: [Todo])] {
        if tab == .done { return list.isEmpty ? [] : [(label: "已完成", items: list)] }
        return TodoFilter.grouped(list)
    }

    var body: some View {
        List {
            Section {
                Picker("范围", selection: $tab) {
                    ForEach(TodoTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if tab == .records {
                if memos.isEmpty {
                    AppEmptyState(title: "暂无记录", systemImage: "square.and.pencil")
                } else {
                    ForEach(memos.sorted { $0.updatedAt > $1.updatedAt }) { memo in
                        BusinessRow(title: memo.title, subtitle: Fmt.shortDateTime(memo.updatedAt))
                    }
                }
            } else if list.isEmpty {
                AppEmptyState(title: TodoFilter.emptyText(for: tab), systemImage: "checkmark.circle")
            } else {
                ForEach(groups, id: \.label) { group in
                    Section(group.label) {
                        ForEach(group.items) { todo in
                            Button { editingTodo = todo } label: {
                                BusinessRow(
                                    title: todo.title,
                                    subtitle: todo.dueDate.map { tab == .overdue ? Fmt.monthDayTime($0) : Fmt.time($0) },
                                    badge: todo.isCompleted ? "完成" : todo.priorityLevel.shortLabel,
                                    badgeTone: todo.isCompleted ? .success : (todo.priority >= 2 ? .danger : .neutral)
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading) {
                                Button { try? TodoRepository(context: context).toggleComplete(todo) } label: {
                                    Label(todo.isCompleted ? "恢复" : "完成", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { delete(todo) } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(V21.background)
        .navigationTitle("待办")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if tab == .records { showNewRecord = true } else { showNewEditor = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewEditor) { TodoEditorSheet(todo: nil) }
        .sheet(isPresented: $showNewRecord) { RecordEditorSheet() }
        .sheet(item: $editingTodo) { TodoEditorSheet(todo: $0) }
    }

    private func delete(_ todo: Todo) {
        Haptic.warning()
        try? TodoRepository(context: context).delete(todo)
    }
}

private struct RecordEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var imageData: Data?
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("记录内容") {
                    TextField("记下这件事", text: $content, axis: .vertical)
                        .lineLimit(4...8)
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("添加图片（可选）", systemImage: "photo")
                    }
                }
            }
            .navigationTitle("新增记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: selectedItem) { _, item in
                Task { imageData = try? await item?.loadTransferable(type: Data.self) }
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
