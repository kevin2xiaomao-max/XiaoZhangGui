import SwiftUI
import SwiftData

struct CustomerView: View {
    @Environment(\.modelContext) private var context
    @Query private var requests: [CustomerRequest]

    @State private var filter: CustomerFilter = .all
    @State private var showNewEditor = false
    @State private var editingRequest: CustomerRequest?
    @State private var deletingRequest: CustomerRequest?

    private var shown: [CustomerRequest] {
        let list = filter == .all ? requests : requests.filter { $0.statusEnum == filter.status }
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                V32PageHeader("客户配送") {
                    V32ToolButton(systemName: "plus") { showNewEditor = true }
                }
                V32SegmentedPicker(
                    tabs: CustomerFilter.allCases.map(\.rawValue),
                    selectionIndex: Binding(
                        get: { CustomerFilter.allCases.firstIndex(of: filter) ?? 0 },
                        set: { filter = CustomerFilter.allCases[$0] }
                    )
                )
                if shown.isEmpty {
                    V32Card {
                        VStack(spacing: 12) {
                            V32EmptyState(systemName: "shippingbox", title: "当前没有配送需求", message: nil)
                            V32PrimaryButton(title: "新增配送", systemName: "plus") { showNewEditor = true }
                                .padding(.horizontal, 24)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    V32Card(padding: 4) {
                        VStack(spacing: 0) {
                            ForEach(Array(shown.enumerated()), id: \.element.persistentModelID) { index, request in
                                if index > 0 { Rectangle().fill(V32.divider).frame(height: 1).padding(.leading, 48) }
                                CustomerRow(
                                    request: request,
                                    onEdit: { editingRequest = request },
                                    onCopyAddress: copyAddress,
                                    onAdvance: { advance(request) },
                                    onDelete: { deletingRequest = request }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32PageBottomInset()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showNewEditor) { CustomerEditorSheet(request: nil) }
        .sheet(item: $editingRequest) { CustomerEditorSheet(request: $0) }
        .confirmationDialog(
            "删除这条客户需求？",
            isPresented: Binding(get: { deletingRequest != nil }, set: { if !$0 { deletingRequest = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let request = deletingRequest {
                    Haptic.warning()
                    try? CustomerRepository(context: context).delete(request)
                }
                deletingRequest = nil
            }
            Button("取消", role: .cancel) { deletingRequest = nil }
        }
    }

    private func advance(_ request: CustomerRequest) {
        Haptic.light()
        try? CustomerRepository(context: context).advanceStatus(request)
    }

    private func copyAddress(_ request: CustomerRequest) {
        if let address = request.roomOrAddress.nonEmpty {
            UIPasteboard.general.string = address
            Haptic.success()
        }
    }
}

// MARK: - 配送行

private struct CustomerRow: View {
    let request: CustomerRequest
    let onEdit: () -> Void
    let onCopyAddress: (CustomerRequest) -> Void
    let onAdvance: () -> Void
    let onDelete: () -> Void

    private var icon: String {
        switch request.statusEnum {
        case .pending: return "clock"
        case .delivering: return "bicycle"
        case .done: return "checkmark"
        }
    }

    private var tone: V32BubbleTone {
        switch request.statusEnum {
        case .pending: return .amber
        case .delivering: return .brand
        case .done: return .neutral
        }
    }

    private var status: V32Status {
        switch request.statusEnum {
        case .pending: return .pending
        case .delivering: return .delivering
        case .done: return .done
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                V32IconBubble(systemName: icon, tone: tone, size: 34, icon: 15)
                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(request.displayTitle)
                            .v32Text(.title)
                            .foregroundStyle(V32.textPrimary)
                            .lineLimit(2)
                        Text(request.displaySubtitle)
                            .v32Text(.caption)
                            .foregroundStyle(V32.textTertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                V32StatusPill(text: request.statusEnum.rawValue, status: status)
            }
            HStack(spacing: 6) {
                Spacer().frame(width: 46)
                if !request.roomOrAddress.isEmpty {
                    rowActionButton("doc.on.doc", tint: V32.info) { onCopyAddress(request) }
                }
                if request.statusEnum != .done {
                    rowActionButton(request.statusEnum == .pending ? "bicycle" : "checkmark", tint: V32.brand, action: onAdvance)
                }
                rowActionButton("trash", tint: V32.textQuaternary, action: onDelete)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func rowActionButton(_ systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(V32.pageBGSecondary))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

extension CustomerRequest {
    var displayCustomerName: String {
        let raw = CustomerDeliveryStorage.decode(customer).legacyCustomer ?? ""
        return DisplayText.visible(raw)
    }

    var displayTitle: String {
        DisplayText.visible(content, fallback: displayCustomerName.isEmpty ? "客户配送" : displayCustomerName)
    }

    var displaySubtitle: String {
        DisplayText.joined(displayCustomerName, roomOrAddress)
    }
}

enum CustomerFilter: String, CaseIterable, Identifiable, Hashable {
    case all = "全部"
    case pending = "待处理"
    case delivering = "配送中"
    case done = "已完成"

    var id: String { rawValue }

    var status: CustomerStatus? {
        switch self {
        case .all: return nil
        case .pending: return .pending
        case .delivering: return .delivering
        case .done: return .done
        }
    }
}

extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
