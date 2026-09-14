import SwiftUI

struct TodoEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let todo: Todo?

    @State private var title = ""
    @State private var detail = ""
    @State private var hasDue = false
    @State private var dueDate = Date()
    @State private var priority: TodoPriority = .low
    @State private var imageData: Data?
    @State private var isInitialized = false

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("要做什么？", text: $title)
                    TextField("补充说明（可选）", text: $detail, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("时间") {
                    Toggle("设置截止时间", isOn: $hasDue)
                    if hasDue {
                        DatePicker("截止", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                Section("优先级") {
                    Picker("优先级", selection: $priority) {
                        ForEach(TodoPriority.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("图片") {
                    PhotoPickerField(imageData: imageData) { imageData = $0 }
                }
            }
            .navigationTitle(todo == nil ? "新增待办" : "编辑待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(!canSave)
                }
            }
            .onAppear(perform: initializeIfNeeded)
        }
        .presentationDetents([.medium, .large])
    }

    private func initializeIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true
        guard let todo else {
            dueDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            return
        }
        title = todo.title
        detail = todo.detail
        hasDue = todo.dueDate != nil
        dueDate = todo.dueDate ?? (Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date())
        priority = todo.priorityLevel
        imageData = todo.imageData
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let repo = TodoRepository(context: context)
        do {
            if let todo {
                todo.title = trimmedTitle
                todo.detail = trimmedDetail
                todo.dueDate = hasDue ? dueDate : nil
                todo.priorityLevel = priority
                todo.imageData = imageData
                try repo.update(todo)
            } else {
                try repo.add(
                    title: trimmedTitle,
                    detail: trimmedDetail,
                    dueDate: hasDue ? dueDate : nil,
                    priority: priority.rawValue,
                    imageData: imageData
                )
            }
            Haptic.success()
            dismiss()
        } catch {
            Haptic.error()
        }
    }
}
