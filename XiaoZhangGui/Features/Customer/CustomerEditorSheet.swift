import SwiftUI

// MARK: - 配送需求新增/编辑 Sheet

struct CustomerEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

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

    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !roomOrAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: V21Layout.spaceXL) {
                    contentField
                    field("配送地址 / 别墅地址", placeholder: "例：清泉八街24号", text: $roomOrAddress)
                    field("联系电话（选填）", placeholder: "请输入联系电话", text: $phone)
                        .keyboardType(.phonePad)
                    deliveryTimeSection
                    noteField
                    imageSection
                }
                .padding(.horizontal, V21Layout.pageMargin)
                .padding(.top, V21Layout.spaceLG)
                .padding(.bottom, 48)
            }
            .scrollContentBackground(.hidden)
            .background(V21.background)
            .navigationTitle(request == nil ? "新增配送需求" : "编辑配送需求")
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

    private func field(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            TextField(placeholder, text: text)
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
            Text("购买内容")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            TextField("例：矿泉水2箱、啤酒10瓶、纸巾2包", text: $content, axis: .vertical)
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

    private var deliveryTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("配送时间（选填）", isOn: $hasDeliveryTime)
                .v21Style(.labelLarge)
            if hasDeliveryTime {
                DatePicker("送达时间", selection: $deliveryTime)
                    .datePickerStyle(.compact)
            }
        }
        .foregroundColor(V21.textPrimary)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: V21Layout.radiusMD, style: .continuous)
                .fill(V21.surfaceGlass)
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注（选填）")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            TextField("例：到了打电话 / 放门口 / 晚上8点送", text: $note, axis: .vertical)
                .v21Style(.bodyMedium)
                .lineLimit(2...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: V21Layout.radiusMD, style: .continuous)
                        .fill(V21.surfaceGlass)
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
