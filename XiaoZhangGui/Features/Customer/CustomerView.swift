import SwiftUI
import SwiftData

// MARK: - 客户需求页（状态 Tab + 需求卡片 + 电话/推进状态/复制地址/编辑/删除）
// 服务便利店真实场景，不做 CRM；状态：待处理 → 配送中 → 已完成

struct CustomerView: View {
    @Environment(\.modelContext) private var context
    @Query private var requests: [CustomerRequest]

    @State private var filter: CustomerFilter = .all
    @State private var showNewEditor = false
    @State private var editingRequest: CustomerRequest?
    @State private var deletingRequest: CustomerRequest?
    private var isMockPreview: Bool { RuntimeMode.allowsMockData }

    private var shown: [CustomerRequest] {
        let list = filter == .all
            ? requests
            : requests.filter { $0.statusEnum == filter.status }
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        PageBackground {
            ZStack(alignment: .bottomTrailing) {
                List {
                    VStack(alignment: .leading, spacing: 4) { Text("客户配送").font(AppTypography.pageTitle).foregroundColor(V21.textPrimary); Text("今天还有 \(todayPendingCount) 单待配送").font(AppTypography.bodyMedium).foregroundColor(V21.textTertiary) }
                        .listRowSeparator(.hidden).listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 20, leading: V21Layout.pageMargin, bottom: 8, trailing: V21Layout.pageMargin))
                    PillTabRow(items: CustomerFilter.allCases, label: { $0.rawValue }, selection: $filter)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                    if isMockPreview {
                        ForEach(Array([("18:30", "302别墅", "两箱矿泉水 + 冰块2袋", "恒大泉都 302别墅"), ("19:10", "208房", "可乐2瓶 + 薯片3包", "温泉酒店 208"), ("20:00", "16栋05房", "泡面4桶 + 饮料", ""), ("20:30", "温泉酒店前台", "矿泉水1箱", "")].enumerated()), id: \.offset) { _, item in
                            MockDeliveryRow(item: item, palette: AppTheme.palette(named: AppSettings.shared.appThemeName))
                                .listRowSeparator(.hidden).listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: V21Layout.pageMargin, bottom: 10, trailing: V21Layout.pageMargin))
                        }
                    } else if shown.isEmpty {
                        EmptyStateView(text: "当前没有配送需求", icon: "shippingbox")
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    } else {
                        ForEach(shown) { request in
                            CustomerCard(
                                request: request,
                                onAdvance: { advance(request) },
                                onEdit: { editingRequest = request },
                                onDelete: { deletingRequest = request }
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: V21Layout.pageMargin, bottom: 8, trailing: V21Layout.pageMargin))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deletingRequest = request
                                } label: {
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
                                .tint(V21.info)
                            }
                        }
                    }

                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                V21FAB(systemImage: "plus") {
                    showNewEditor = true
                }
                .padding(.trailing, V21Layout.spaceXL)
                .padding(.bottom, V21Layout.bottomDockContentGap - 30)
            }
        }
        .navigationTitle("配送需求")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNewEditor) {
            CustomerEditorSheet(request: nil)
        }
        .sheet(item: $editingRequest) { request in
            CustomerEditorSheet(request: request)
        }
        .confirmationDialog(
            "删除这条客户需求？",
            isPresented: Binding(
                get: { deletingRequest != nil },
                set: { if !$0 { deletingRequest = nil } }
            ),
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

    private var todayPendingCount: Int {
        if isMockPreview { return 4 }
        return requests.filter { request in
            guard request.statusEnum != .done else { return false }
            let info = CustomerDeliveryStorage.decode(request.customer)
            return (info.deliveryTime ?? request.createdAt).isToday
        }.count
    }

    /// 状态推进：待处理 → 配送中 → 已完成
    private func advance(_ request: CustomerRequest) {
        Haptic.light()
        try? CustomerRepository(context: context).advanceStatus(request)
    }
}

private struct MockDeliveryRow: View {
    let item: (String, String, String, String); let palette: AppThemePalette
    var body: some View { HStack(alignment: .top, spacing: 12) { VStack(alignment: .leading, spacing: 5) { HStack { Text(item.1).font(AppTypography.cardTitle).foregroundColor(V21.textPrimary); Spacer(); Text(item.0).font(AppTypography.bodyMedium).foregroundColor(V21.textTertiary) }; Text(item.2).font(AppTypography.body).foregroundColor(V21.textSecondary); if !item.3.isEmpty { Text("地址：\(item.3)").font(AppTypography.caption).foregroundColor(V21.textTertiary) }; Text("待配送").font(AppTypography.micro).foregroundColor(palette.accent).padding(.horizontal, 7).padding(.vertical, 3).background(palette.accent.opacity(0.10), in: Capsule()) }; Spacer() }.padding(14).background(V21.surfaceGlass, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(V21.divider.opacity(0.5))) }
}

// MARK: - 过滤（全部 + 三状态）

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

// MARK: - 客户需求卡片

struct CustomerCard: View {
    let request: CustomerRequest
    var onAdvance: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var statusColor: Color { request.statusEnum.color }
    private var deliveryInfo: CustomerDeliveryInfo { CustomerDeliveryStorage.decode(request.customer) }

    var body: some View {
        Button(action: onEdit) {
            GlassSurface {
                VStack(alignment: .leading, spacing: 6) {
                // 购买内容 + 状态徽标
                HStack {
                    Text(request.content)
                        .v21Style(.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(V21.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(request.statusEnum.rawValue)
                        .v21Style(.labelSmall)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(statusColor.opacity(0.1))
                        }
                }

                if !request.roomOrAddress.isEmpty {
                    Text(request.roomOrAddress)
                        .v21Style(.bodySmall)
                        .foregroundColor(V21.textTertiary)
                        .lineLimit(1)
                }

                if let deliveryTime = deliveryInfo.deliveryTime {
                    Label(Fmt.shortDateTime(deliveryTime), systemImage: "clock")
                        .v21Style(.bodySmall)
                        .foregroundColor(V21.textTertiary)
                }

                if !deliveryInfo.note.isEmpty {
                    Text(deliveryInfo.note)
                        .v21Style(.bodySmall)
                        .foregroundColor(V21.textSecondary)
                        .lineLimit(2)
                }

                // 电话 · 时间 + 缩略图
                HStack(spacing: 8) {
                    Text([request.phone.nonEmpty, Fmt.shortDateTime(request.createdAt)]
                        .compactMap { $0 }
                        .joined(separator: " · "))
                        .v21Style(.labelSmall)
                        .foregroundColor(V21.textQuaternary)
                    Spacer()
                    if let data = request.imageData {
                        ImageThumb(imageData: data, size: 34)
                    }
                }

                // 操作行：电话 / 推进状态
                HStack(spacing: 4) {
                    if !request.phone.isEmpty {
                        actionButton(icon: "phone", title: "电话", color: V21.info) {
                            if let url = URL(string: "tel:\(request.phone)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    if request.statusEnum != .done {
                        actionButton(
                            icon: "checkmark.circle",
                            title: request.statusEnum == .pending ? "配送" : "完成",
                            color: V21.brandGreen,
                            action: onAdvance
                        )
                    }
                    Spacer()
                }
                .padding(.top, 2)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .v21Style(.labelMedium)
            }
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension String {
    /// 去空白后非空
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
