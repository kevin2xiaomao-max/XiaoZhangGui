import SwiftUI

// MARK: - 备忘新增/编辑 Sheet（V371：原生 Form）
//
// 业务语义保持 V3.6 原样：标题/内容其一非空可保存、100/2000 字截断、图片、
// try/catch 保存 + 失败可见可重试。只做 presentation 迁移。

struct MemoEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// nil = 新增
    let memo: Memo?

    @State private var title = ""
    @State private var content = ""
    @State private var imageData: Data?
    @State private var isInitialized = false
    @State private var saveError: String?
    @State private var showDiscardAlert = false

    /// V3.9.1 P1-8:与原记录(编辑)或空态(新增)比对。
    private var isDirty: Bool {
        if let memo {
            return title != memo.title || content != memo.content || imageData != memo.imageData
        }
        return !title.isEmpty || !content.isEmpty || imageData != nil
    }

    private func cancelTapped() {
        if isDirty { showDiscardAlert = true } else { dismiss() }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("记录标题", text: $title)
                }
                Section("内容") {
                    TextField("记点什么…", text: $content, axis: .vertical)
                        .lineLimit(4...8)
                }
                Section("图片") {
                    PhotoPickerField(imageData: imageData) { imageData = $0 }
                }
            }
            .scrollContentBackground(.hidden)
            .background(V371.Colors.canvas)
            .tint(V371.Colors.blue)
            .navigationTitle(memo == nil ? "新增记录" : "编辑记录")
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
        .presentationDetents([.medium, .large])
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
        guard let memo else { return }
        title = memo.title
        content = memo.content
        imageData = memo.imageData
    }

    private func save() {
        let trimmedTitle = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        let trimmedContent = String(content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))
        let repo = MemoRepository(context: context)
        do {
            if let memo {
                memo.title = trimmedTitle
                memo.content = trimmedContent
                memo.imageData = imageData
                try repo.update(memo)
            } else {
                try repo.add(title: trimmedTitle, content: trimmedContent, imageData: imageData)
            }
            Haptic.success()
            dismiss()
        } catch {
            Haptic.error()
            saveError = "备忘未保存，请重试。"
        }
    }
}
