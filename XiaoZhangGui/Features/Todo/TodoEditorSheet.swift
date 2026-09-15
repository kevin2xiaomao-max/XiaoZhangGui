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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                titleCard
                timeCard
                priorityCard
                imageCard
                V32PrimaryButton(title: "保存", systemName: "checkmark") { save() }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                    .padding(.top, 2)
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 14)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32Sheet([.large])
        .onAppear(perform: initializeIfNeeded)
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .center) {
            Button("取消") { dismiss() }
                .v32Text(.body)
                .foregroundStyle(V32.textSecondary)
            Spacer()
            Text(todo == nil ? "新增待办" : "编辑待办")
                .v32Text(.headline)
                .foregroundStyle(V32.textPrimary)
            Spacer()
            // 视觉占位，保持标题居中
            Button("取消") { }.opacity(0).allowsHitTesting(false)
        }
    }

    // MARK: 标题

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("标题")
            V32Card {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("要做什么？", text: $title)
                        .v32Text(.headline)
                        .foregroundStyle(V32.textPrimary)
                        .tint(V32.brand)
                    Rectangle().fill(V32.divider).frame(height: 1)
                    TextField("补充说明（可选）", text: $detail, axis: .vertical)
                        .v32Text(.body)
                        .foregroundStyle(V32.textSecondary)
                        .tint(V32.brand)
                        .lineLimit(3...6)
                }
            }
        }
    }

    // MARK: 时间

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("时间")
            V32Card {
                VStack(spacing: 12) {
                    HStack {
                        Text("设置截止时间")
                            .v32Text(.title)
                            .foregroundStyle(V32.textPrimary)
                        Spacer()
                        Toggle("", isOn: $hasDue)
                            .labelsHidden()
                            .tint(V32.brand)
                    }
                    if hasDue {
                        Rectangle().fill(V32.divider).frame(height: 1)
                        DatePicker("截止", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                            .v32Text(.title)
                            .tint(V32.brand)
                    }
                }
            }
        }
    }

    // MARK: 优先级

    private var priorityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("优先级")
            V32SegmentedPicker(
                tabs: TodoPriority.allCases.map(\.label),
                selectionIndex: Binding(
                    get: { TodoPriority.allCases.firstIndex(of: priority) ?? 0 },
                    set: { priority = TodoPriority.allCases[$0] }
                )
            )
        }
    }

    // MARK: 图片

    private var imageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("图片")
            V32Card {
                PhotoPickerField(imageData: imageData) { imageData = $0 }
            }
        }
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
