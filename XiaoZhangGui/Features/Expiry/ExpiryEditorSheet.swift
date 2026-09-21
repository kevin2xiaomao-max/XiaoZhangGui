import SwiftUI

// MARK: - 临期商品新增/编辑 Sheet（V32）

struct ExpiryEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// nil = 新增
    let item: ExpiryItem?

    @State private var name = ""
    @State private var quantityText = "1"
    @State private var expiryDate = Date()
    @State private var remindDays = 7
    @State private var note = ""
    @State private var imageData: Data?
    @State private var isInitialized = false
    @State private var saveError: String?

    private var quantity: Int {
        Int(quantityText.filter(\.isNumber)) ?? 0
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && quantity > 0
    }

    private static let remindOptions = [3, 7, 15]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                nameCard
                quantityCard
                expiryCard
                remindCard
                noteCard
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
        .v32Sheet([.large])
        .onAppear(perform: initializeIfNeeded)
        .alert("保存失败", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("重试") { save() }
            Button("取消", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "请稍后重试") }
    }

    private var header: some View {
        ZStack {
            Text(item == nil ? "新增临期商品" : "编辑临期商品")
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

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("商品名称")
            V32FieldGroup {
                TextField("例如：牛奶 250ml", text: $name)
                    .v32Text(.body)
                    .foregroundStyle(V32.textPrimary)
                    .tint(V32.brand)
            }
        }
    }

    private var quantityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("数量")
            V32FieldGroup {
                Stepper(value: Binding(
                    get: { max(quantity, 1) },
                    set: { quantityText = String($0) }
                ), in: 1...9999) {
                    TextField("1", text: $quantityText)
                        .v32Text(.headline)
                        .foregroundStyle(V32.textPrimary)
                        .tint(V32.brand)
                        .keyboardType(.numberPad)
                }
                .tint(V32.brand)
            }
        }
    }

    private var expiryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("到期日期")
            V32FieldGroup {
                DatePicker(
                    "到期",
                    selection: $expiryDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(V32.brand)
            }
        }
    }

    private var remindCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("提前提醒")
            V32SegmentedPicker(
                tabs: Self.remindOptions.map { "\($0) 天" },
                selectionIndex: Binding(
                    get: { Self.remindOptions.firstIndex(of: remindDays) ?? 1 },
                    set: { remindDays = Self.remindOptions[$0] }
                )
            )
        }
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("备注")
            V32FieldGroup {
                TextField("供应商、批次等", text: $note)
                    .v32Text(.body)
                    .foregroundStyle(V32.textSecondary)
                    .tint(V32.brand)
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
        guard let item else { return }
        name = item.name
        quantityText = String(max(item.quantity, 1))
        expiryDate = item.expiryDate
        remindDays = item.remindDaysBefore
        note = item.note
        imageData = item.imageData
    }

    private func save() {
        let trimmedName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        let trimmedNote = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        let repo = ExpiryRepository(context: context)
        do {
            if let item {
                item.name = trimmedName
                item.quantity = quantity
                item.expiryDate = expiryDate
                item.remindDaysBefore = remindDays
                item.note = trimmedNote
                item.imageData = imageData
                try repo.update(item)
            } else {
                try repo.add(
                    name: trimmedName,
                    quantity: quantity,
                    expiryDate: expiryDate,
                    remindDaysBefore: remindDays,
                    note: trimmedNote,
                    imageData: imageData
                )
            }
            Haptic.success()
            dismiss()
        } catch {
            Haptic.error()
            saveError = "临期记录未保存，请重试。"
        }
    }
}
