import SwiftUI

// MARK: - 待办编辑 Sheet：原生 Form（V371 换肤）
//
// 业务语义保持 V3.6 原样：标题必填校验、截止时间开关、优先级、图片、
// try/catch 保存 + 失败可见可重试。只做 presentation 迁移。

struct TodoEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let todo: Todo?
    /// V3.8 P1-B1：新建时的预填日期（日历页「+」带入当前选中日）。
    /// 默认 nil = 既有行为（默认今天 09:00）；编辑已有待办时忽略。
    var initialDate: Date? = nil

    @State private var title = ""
    @State private var detail = ""
    @State private var hasDue = false
    @State private var dueDate = Date()
    @State private var priority: TodoPriority = .low
    @State private var imageData: Data?
    @State private var isInitialized = false
    @State private var saveError: String?
    @State private var showDiscardAlert = false

    /// V3.9.1 P1-8:与原记录(编辑)或空态(新增)比对,任意字段变化即为脏。
    private var isDirty: Bool {
        if let todo {
            return title != todo.title || detail != todo.detail
                || hasDue != (todo.dueDate != nil)
                || (hasDue && todo.dueDate != nil && dueDate != todo.dueDate!)
                || priority != todo.priorityLevel || imageData != todo.imageData
        }
        return !title.isEmpty || !detail.isEmpty || hasDue || imageData != nil
    }

    private func cancelTapped() {
        if isDirty { showDiscardAlert = true } else { dismiss() }
    }

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
                        ForEach(TodoPriority.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section("图片") {
                    PhotoPickerField(imageData: imageData) { imageData = $0 }
                }
            }
            .scrollContentBackground(.hidden)
            .background(V371.Colors.canvas)
            .tint(V371.Colors.blue)
            .navigationTitle(todo == nil ? "新增待办" : "编辑待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: cancelTapped)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isDirty)
        .onAppear(perform: initializeIfNeeded)        .alert("放弃未保存的修改？", isPresented: $showDiscardAlert) {
            Button("放弃修改", role: .destructive) { dismiss() }
            Button("继续编辑", role: .cancel) {}
        } message: { Text("已输入的内容将丢失。") }
        .alert("保存失败", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("重试") { save() }
            Button("取消", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "请稍后重试") }
    }

    private func initializeIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true
        guard let todo else {
            // 新建：默认 09:00；日历页入口带入选中日（V3.8 P1-B1）。
            let base = initialDate ?? Date()
            dueDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base
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
            saveError = "内容未保存，请重试。"
        }
    }
}
