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

    private var todayCount: Int { TodoFilter.todos(for: .today, in: todos).count }
    private var doneCount: Int { todos.filter(\.isCompleted).count }
    private var overdueCount: Int { TodoFilter.todos(for: .overdue, in: todos).count }

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
                    Section {
                        AppEmptyState(title: "暂无记录", systemImage: "square.and.pencil", actionTitle: "新增") {
                            showNewRecord = true
                        }
                    }
                } else {
                    ForEach(memos.sorted { $0.updatedAt > $1.updatedAt }) { memo in
                        BusinessRow(title: memo.title, subtitle: Fmt.shortDateTime(memo.updatedAt))
                    }
                }
            } else if list.isEmpty {
                Section {
                    AppEmptyState(title: TodoFilter.emptyText(for: tab), systemImage: "checkmark.circle", actionTitle: "新增") {
                        showNewEditor = true
                    }
                }
            } else {
                ForEach(groups, id: \.label) { group in
                    Section(group.label) {
                        ForEach(group.items) { todo in
                            Button { editingTodo = todo } label: {
                                TodoCheckRow(todo: todo, showsDate: tab == .overdue) {
                                    try? TodoRepository(context: context).toggleComplete(todo)
                                }
                            }
                            .buttonStyle(.plain)
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
        .bottomDockPadding()
        .navigationTitle("待办")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if tab == .records { showNewRecord = true } else { showNewEditor = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Text("今天 \(todayCount)")
                    Spacer()
                    Text("已完成 \(doneCount)")
                    Spacer()
                    Text("逾期 \(overdueCount)")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
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
