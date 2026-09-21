import SwiftUI

// MARK: - 备忘新增/编辑 Sheet（V32；标题 ≤100 / 内容 ≤2000 / 图片）

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

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                titleCard
                contentCard
                imageCard
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
        .onAppear(perform: initializeIfNeeded)
        .alert("保存失败", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("重试") { save() }
            Button("取消", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "请稍后重试") }
    }

    private var header: some View {
        ZStack {
            Text(memo == nil ? "新增记录" : "编辑记录")
                .v32Text(.headline)
                .foregroundStyle(V32.textPrimary)
            HStack {
                Button("取消") { dismiss() }
                    .v32Text(.body)
                    .foregroundStyle(V32.textTertiary)
                Spacer()
            }
        }
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("标题")
            V32FieldGroup {
                TextField("记录标题", text: $title)
                    .v32Text(.headline)
                    .foregroundStyle(V32.textPrimary)
                    .tint(V32.brand)
            }
        }
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("内容")
            V32FieldGroup {
                TextField("记点什么…", text: $content, axis: .vertical)
                    .v32Text(.body)
                    .foregroundStyle(V32.textSecondary)
                    .tint(V32.brand)
                    .lineLimit(4...8)
            }
        }
    }

    private var imageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("图片")
            V32FieldGroup { PhotoPickerField(imageData: imageData) { imageData = $0 } }
        }
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
