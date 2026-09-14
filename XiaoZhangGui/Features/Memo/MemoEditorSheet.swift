import SwiftUI

// MARK: - 备忘新增/编辑 Sheet（标题 ≤100 / 内容 ≤2000 / 图片）

struct MemoEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    /// nil = 新增
    let memo: Memo?

    @State private var title = ""
    @State private var content = ""
    @State private var imageData: Data?
    @State private var isInitialized = false

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: V21Layout.spaceXL) {
                    titleField
                    contentField
                    imageSection
                }
                .padding(.horizontal, V21Layout.pageMargin)
                .padding(.top, V21Layout.spaceLG)
                .padding(.bottom, 48)
            }
            .navigationTitle(memo == nil ? "新增记录" : "编辑记录")
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

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标题")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            TextField("记录标题", text: $title)
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

    private var contentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("内容")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            TextField("记点什么…", text: $content, axis: .vertical)
                .v21Style(.bodyMedium)
                .foregroundColor(V21.textPrimary)
                .lineLimit(4...8)
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

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图片（可选）")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            PhotoPickerField(imageData: imageData) { imageData = $0 }
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
        }
    }
}
