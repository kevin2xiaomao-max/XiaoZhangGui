import SwiftUI

// MARK: - 待办新增/编辑 Sheet（标题 / 详情 / 日期时间 / 优先级 / 图片）

struct TodoEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    /// nil = 新增
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
            ScrollView {
                VStack(alignment: .leading, spacing: V21Layout.spaceXL) {
                    titleField
                    detailField
                    dueSection
                    prioritySection
                    imageSection
                }
                .padding(.horizontal, V21Layout.pageMargin)
                .padding(.top, V21Layout.spaceLG)
                .padding(.bottom, 48)
            }
            .scrollContentBackground(.hidden)
            .background(V21.background)
            .navigationTitle(todo == nil ? "新增待办" : "编辑待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(V21.textTertiary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .foregroundColor(canSave ? AppTheme.palette(named: settings.appThemeName).accent : V21.textQuaternary)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: initializeIfNeeded)
        }
    }

    // MARK: - 各区块

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标题")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            TextField("要做什么？", text: $title)
                .v21Style(.bodyLarge)
                .foregroundColor(V21.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: V21Layout.radiusMD, style: .continuous)
                        .fill(V21.surfaceGlass)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: V21Layout.radiusMD, style: .continuous)
                        .strokeBorder(V21.dividerStrong, lineWidth: 1)
                }
        }
    }

    private var detailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("详情（可选）")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            TextField("补充说明…", text: $detail, axis: .vertical)
                .v21Style(.bodyMedium)
                .foregroundColor(V21.textPrimary)
                .lineLimit(3...6)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: V21Layout.radiusMD, style: .continuous)
                        .fill(V21.surfaceGlass)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: V21Layout.radiusMD, style: .continuous)
                        .strokeBorder(V21.dividerStrong, lineWidth: 1)
                }
        }
    }

    private var dueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("时间")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            GlassSurface {
                VStack(spacing: 0) {
                    Toggle("设置截止时间", isOn: $hasDue.animation(.easeOut(duration: 0.15)))
                        .tint(AppTheme.palette(named: settings.appThemeName).accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    if hasDue {
                        Divider().overlay(V21.divider)
                        DatePicker(
                            "截止",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .font(.system(size: 15, weight: .medium))
                    }
                }
            }
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("优先级")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            HStack(spacing: 6) {
                ForEach(TodoPriority.allCases) { level in
                    let selected = priority == level
                    Button {
                        priority = level
                        Haptic.light()
                    } label: {
                        HStack(spacing: 6) {
                            PriorityDot(level: level.rawValue, size: 6)
                            Text(level.label)
                                .font(.system(size: 13, weight: selected ? .semibold : .medium))
                                .foregroundColor(selected ? V21.textPrimary : V21.tabInactive)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            Capsule(style: .continuous)
                                .fill(selected ? AnyShapeStyle(V21.surfaceElevated) : AnyShapeStyle(.clear))
                        }
                        .overlay {
                            if selected {
                                Capsule(style: .continuous)
                                    .strokeBorder(V21.dividerStrong, lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图片（可选）")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            PhotoPickerField(imageData: imageData) { imageData = $0 }
        }
    }

    // MARK: - 逻辑

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
