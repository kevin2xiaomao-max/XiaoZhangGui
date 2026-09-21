import SwiftUI

// MARK: - 配送需求新增/编辑 Sheet（V32）

struct CustomerEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// nil = 新增
    let request: CustomerRequest?

    @State private var roomOrAddress = ""
    @State private var phone = ""
    @State private var content = ""
    @State private var hasDeliveryTime = false
    @State private var deliveryTime = Date()
    @State private var note = ""
    @State private var imageData: Data?
    @State private var isInitialized = false
    @State private var saveError: String?

    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !roomOrAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                contentCard
                addressCard
                timeCard
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
            Text(request == nil ? "新增配送需求" : "编辑配送需求")
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

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("购买内容")
            V32FieldGroup {
                TextField("例：矿泉水2箱、啤酒10瓶、纸巾2包", text: $content, axis: .vertical)
                    .v32Text(.body)
                    .foregroundStyle(V32.textPrimary)
                    .tint(V32.brand)
                    .lineLimit(3...6)
            }
        }
    }

    private var addressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("地址与联系")
            V32FieldGroup {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("配送地址 / 别墅地址，例：清泉八街24号", text: $roomOrAddress)
                        .v32Text(.body)
                        .foregroundStyle(V32.textPrimary)
                        .tint(V32.brand)
                    Rectangle().fill(V32.divider).frame(height: 1)
                    TextField("联系电话（选填）", text: $phone)
                        .v32Text(.body)
                        .foregroundStyle(V32.textSecondary)
                        .tint(V32.brand)
                        .keyboardType(.phonePad)
                }
            }
        }
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("配送时间")
            V32FieldGroup {
                VStack(spacing: 12) {
                    HStack {
                        Text("设置配送时间")
                            .v32Text(.title)
                            .foregroundStyle(V32.textPrimary)
                        Spacer()
                        Toggle("", isOn: $hasDeliveryTime)
                            .labelsHidden()
                            .tint(V32.brand)
                    }
                    if hasDeliveryTime {
                        Rectangle().fill(V32.divider).frame(height: 1)
                        DatePicker("送达时间", selection: $deliveryTime)
                            .v32Text(.title)
                            .tint(V32.brand)
                    }
                }
            }
        }
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("备注")
            V32FieldGroup {
                TextField("例：到了打电话 / 放门口 / 晚上8点送", text: $note, axis: .vertical)
                    .v32Text(.body)
                    .foregroundStyle(V32.textSecondary)
                    .tint(V32.brand)
                    .lineLimit(2...5)
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
        guard let request else { return }
        roomOrAddress = request.roomOrAddress
        phone = request.phone
        content = request.content
        let info = CustomerDeliveryStorage.decode(request.customer)
        if let savedTime = info.deliveryTime {
            hasDeliveryTime = true
            deliveryTime = savedTime
        }
        note = info.note
        imageData = request.imageData
    }

    private func save() {
        let repo = CustomerRepository(context: context)
        do {
            if let request {
                request.customer = CustomerDeliveryStorage.encode(
                    existingValue: request.customer,
                    deliveryTime: hasDeliveryTime ? deliveryTime : nil,
                    note: note
                )
                request.roomOrAddress = roomOrAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                request.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
                request.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
                request.imageData = imageData
                try repo.update(request)
            } else {
                try repo.add(
                    customer: CustomerDeliveryStorage.encode(
                        existingValue: "",
                        deliveryTime: hasDeliveryTime ? deliveryTime : nil,
                        note: note
                    ),
                    roomOrAddress: roomOrAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                    phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageData: imageData
                )
            }
            Haptic.success()
            dismiss()
        } catch {
            Haptic.error()
            saveError = "配送需求未保存，请重试。"
        }
    }
}

struct CustomerDeliveryInfo: Codable {
    var deliveryTime: Date?
    var note: String
    var legacyCustomer: String?
}

enum CustomerDeliveryStorage {
    private static let prefix = "xzg-delivery-v1:"

    static func decode(_ value: String) -> CustomerDeliveryInfo {
        guard value.hasPrefix(prefix),
              let data = Data(base64Encoded: String(value.dropFirst(prefix.count))),
              let info = try? JSONDecoder().decode(CustomerDeliveryInfo.self, from: data) else {
            return CustomerDeliveryInfo(deliveryTime: nil, note: "", legacyCustomer: value.nonEmpty)
        }
        return info
    }

    static func encode(existingValue: String, deliveryTime: Date?, note: String) -> String {
        let existing = decode(existingValue)
        let info = CustomerDeliveryInfo(
            deliveryTime: deliveryTime,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            legacyCustomer: existing.legacyCustomer
        )
        guard let data = try? JSONEncoder().encode(info) else { return existingValue }
        return prefix + data.base64EncodedString()
    }
}
