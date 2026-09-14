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
        List {
            Section {
                Picker("状态", selection: $filter) {
                    ForEach(CustomerFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                if shown.isEmpty {
                    AppEmptyState(title: "当前没有配送需求", systemImage: "shippingbox")
                } else {
                    ForEach(shown) { request in
                        CustomerCard(
                            request: request,
                            onAdvance: { advance(request) },
                            onEdit: { editingRequest = request },
                            onDelete: { deletingRequest = request }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { deletingRequest = request } label: {
                                Label("删除", systemImage: "trash")
                            }
                            Button {
                                if let address = request.roomOrAddress.nonEmpty {
                                    UIPasteboard.general.string = address
                                    Haptic.success()
                                }
                            } label: {
                                Label("复制地址", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(V21.background)
        .navigationTitle("配送需求")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewEditor = true } label: { Image(systemName: "plus") }
            }
        }
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
}

struct CustomerCard: View {
    let request: CustomerRequest
    var onAdvance: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var statusTone: StatusBadge.Tone {
        switch request.statusEnum {
        case .pending: return .warning
        case .delivering: return .accent
        case .done: return .success
        }
    }

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 6) {
                BusinessRow(
                    title: request.content,
                    subtitle: [request.customer, request.roomOrAddress].filter { !$0.isEmpty }.joined(separator: " · "),
                    badge: request.statusEnum.rawValue,
                    badgeTone: statusTone
                )
                HStack {
                    if !request.phone.isEmpty {
                        Button("电话") {
                            if let url = URL(string: "tel:\(request.phone)") { UIApplication.shared.open(url) }
                        }
                        .font(.footnote)
                    }
                    if request.statusEnum != .done {
                        Button(request.statusEnum == .pending ? "配送" : "完成", action: onAdvance)
                            .font(.footnote)
                    }
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
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
