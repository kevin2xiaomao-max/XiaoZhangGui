import SwiftUI

// MARK: - 临期商品新增/编辑 Sheet（名称/数量/到期日期/提前提醒/备注/图片 + 退货/恢复）

struct ExpiryEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    /// nil = 新增
    let item: ExpiryItem?

    @State private var name = ""
    @State private var quantityText = "1"
    @State private var expiryDate = Date()
    @State private var remindDays = 7
    @State private var note = ""
    @State private var imageData: Data?
    @State private var isInitialized = false

    private var quantity: Int {
        Int(quantityText.filter(\.isNumber)) ?? 0
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && quantity > 0
    }

    private static let remindOptions = [3, 7, 15]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: V21Layout.spaceXL) {
                    nameField
                    quantityField
                    expirySection
                    remindSection
                    noteField
                    imageSection
                }
                .padding(.horizontal, V21Layout.pageMargin)
                .padding(.top, V21Layout.spaceLG)
                .padding(.bottom, 48)
            }
            .navigationTitle(item == nil ? "新增临期商品" : "编辑临期商品")
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

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("商品名称")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            TextField("例如：牛奶 250ml", text: $name)
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

    private var quantityField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("数量")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            Stepper(value: Binding(
                get: { max(quantity, 1) },
                set: { quantityText = String($0) }
            ), in: 1...9999) {
                TextField("1", text: $quantityText)
                    .keyboardType(.numberPad)
                    .v21Style(.bodyLarge)
                    .foregroundColor(V21.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
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

    private var expirySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("到期日期")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            GlassSurface {
                DatePicker(
                    "到期",
                    selection: $expiryDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .font(.system(size: 15, weight: .medium))
                .padding(12)
            }
        }
    }

    private var remindSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提前提醒")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            HStack(spacing: 6) {
                ForEach(Self.remindOptions, id: \.self) { days in
                    let selected = remindDays == days
                    Button {
                        remindDays = days
                        Haptic.light()
                    } label: {
                        Text("\(days) 天")
                            .font(.system(size: 13, weight: selected ? .semibold : .medium))
                            .foregroundColor(selected ? V21.textPrimary : V21.tabInactive)
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

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注（可选）")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            TextField("供应商、批次等", text: $note)
                .v21Style(.bodyMedium)
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
        }
    }
}
