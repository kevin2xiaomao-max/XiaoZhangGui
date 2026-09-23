import SwiftUI

// MARK: - 临期商品新增/编辑 Sheet（V371：原生 Form + 统一 toolbar）

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
        NavigationStack {
            Form {
                Section("商品名称") {
                    TextField("例如：牛奶 250ml", text: $name)
                }
                Section("数量") {
                    Stepper(value: Binding(
                        get: { max(quantity, 1) },
                        set: { quantityText = String($0) }
                    ), in: 1...9999) {
                        TextField("1", text: $quantityText)
                            .keyboardType(.numberPad)
                    }
                }
                Section("到期日期") {
                    DatePicker(
                        "到期",
                        selection: $expiryDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                }
                Section("提前提醒") {
                    Picker("提前提醒", selection: $remindDays) {
                        ForEach(Self.remindOptions, id: \.self) { days in
                            Text("\(days) 天").tag(days)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("备注") {
                    TextField("供应商、批次等", text: $note)
                }
                Section("图片") {
                    PhotoPickerField(imageData: imageData) { imageData = $0 }
                }
            }
            .tint(V371.Colors.blue)
            .navigationTitle(item == nil ? "新增临期商品" : "编辑临期商品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
            .alert("保存失败", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("重试") { save() }
                Button("取消", role: .cancel) { saveError = nil }
            } message: { Text(saveError ?? "请稍后重试") }
        }
        .v32Sheet([.large])
        .onAppear(perform: initializeIfNeeded)
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
