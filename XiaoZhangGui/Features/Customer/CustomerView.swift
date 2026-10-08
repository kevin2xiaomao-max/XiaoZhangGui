import SwiftUI
import SwiftData

// MARK: - 客户配送（V371：GroupSurface 按状态分组 + WorkRow）

struct CustomerView: View {
    @Environment(\.modelContext) private var context
    @Query private var requests: [CustomerRequest]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filter: CustomerFilter = .all
    @State private var showNewEditor = false
    @State private var editingRequest: CustomerRequest?
    @State private var deletingRequest: CustomerRequest?
    @State private var showDoneToast = false
    @State private var deleteError: String?
    @State private var failedAdvanceRequest: CustomerRequest?
    @State private var stateActionError: String?

    private var shown: [CustomerRequest] {
        let list = filter == .all ? requests : requests.filter { $0.statusEnum == filter.status }
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    /// §9 grouped-list language：按状态分组（待处理 → 配送中 → 已完成）。
    private var groupedSections: [(status: CustomerStatus, items: [CustomerRequest])] {
        let order: [CustomerStatus] = [.pending, .delivering, .done]
        return order.compactMap { status in
            let items = shown.filter { $0.statusEnum == status }
            return items.isEmpty ? nil : (status, items)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V371.Space.section) {
                V32SegmentedPicker(
                    tabs: CustomerFilter.allCases.map(\.rawValue),
                    selectionIndex: Binding(
                        get: { CustomerFilter.allCases.firstIndex(of: filter) ?? 0 },
                        set: { newValue in
                            withAnimation(V371.Motion.animation(V371.Motion.resolve(.fade, reduceMotion: reduceMotion))) {
                                filter = CustomerFilter.allCases[newValue]
                            }
                        }
                    )
                )
                if shown.isEmpty {
                    V32FieldGroup {
                        VStack(spacing: 12) {
                            if requests.isEmpty {
                                EmptyState(icon: "shippingbox", title: "暂无客户需求", message: "可以先新增一条配送需求")
                                V32PrimaryButton(title: "新增配送", systemName: "plus") { showNewEditor = true }
                                    .padding(.horizontal, 24)
                            } else {
                                EmptyState(icon: "line.3.horizontal.decrease.circle", title: "当前筛选暂无结果", message: "可以切换筛选查看其他需求")
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    ForEach(groupedSections, id: \.status) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(section.status.rawValue) {
                                Text("\(section.items.count)")
                                    .font(V371.Typography.badge)
                                    .foregroundStyle(V371.Colors.textTertiary)
                            }
                            GroupSurface {
                                ForEach(Array(section.items.enumerated()), id: \.element.persistentModelID) { index, request in
                                    if index > 0 { V371Divider(leading: 62) }
                                    // 状态推进动作：原生 swipeActions（pending/delivering 露出推进按钮）
                                    CustomerWorkRow(
                                        request: request,
                                        onEdit: { editingRequest = request },
                                        onCopyAddress: copyAddress,
                                        onAdvance: { advance(request) },
                                        onDelete: { deletingRequest = request }
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        ForEach(swipeActions(for: request), id: \.title) { action in
                                            Button {
                                                action.perform()
                                            } label: {
                                                Label(action.title, systemImage: action.systemName)
                                            }
                                            .tint(action.tint)
                                        }
                                    }
                                    .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.98)))
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, V371.Space.page)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(V371AccessibilityID.screenCustomer)
        .v371Canvas()
        .navigationTitle("客户配送")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("新增配送")
            }
        }
        .overlay(alignment: .bottom) {
            if showDoneToast {
                Text("✓ 已完成配送")
                    .v32Text(.subhead)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(V32.hero))
                    .padding(.bottom, V32Layout.bottomPad + 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
                    do { try CustomerRepository(context: context).delete(request) }
                    catch { deleteError = "客户需求未删除，请重试。" }
                }
                deletingRequest = nil
            }
            Button("取消", role: .cancel) { deletingRequest = nil }
        }
        .alert("删除失败", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("知道了", role: .cancel) { deleteError = nil }
        } message: { Text(deleteError ?? "请稍后重试") }
        .alert("操作失败", isPresented: Binding(get: { stateActionError != nil }, set: { if !$0 { stateActionError = nil } })) {
            Button("重试") {
                stateActionError = nil
                if let request = failedAdvanceRequest { advance(request) }
            }
            .accessibilityIdentifier(V371AccessibilityID.reliabilityRetry)
            Button("取消", role: .cancel) {
                stateActionError = nil
                failedAdvanceRequest = nil
            }
        } message: { Text(stateActionError ?? "配送状态未改变，请重试。") }
    }

    private func advance(_ request: CustomerRequest) {
        let willComplete = request.statusEnum == .delivering
        do {
            try UITestFailureInjection.throwIfRequested(.customerAdvance)
            try CustomerRepository(context: context).advanceStatus(request)
            failedAdvanceRequest = nil
            if willComplete {
                Haptic.success()
                withAnimation(reduceMotion ? nil : V371.Motion.spring) { showDoneToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(reduceMotion ? nil : V371.Motion.spring) { showDoneToast = false }
                }
            } else {
                Haptic.light()
            }
        } catch {
            Haptic.error()
            failedAdvanceRequest = request
            stateActionError = "配送状态未改变，请重试。"
        }
    }

    private func copyAddress(_ request: CustomerRequest) {
        if let address = request.roomOrAddress.nonEmpty {
            UIPasteboard.general.string = address
            Haptic.success()
        }
    }

    // P0-2：根据配送状态返回 swipe actions。
    // pending → [开始配送]；delivering → [✓ 完成]；done → []（不允许 swipe）。
    // 完成动作直接调用 advance(request)，由 CustomerRepository 写入唯一业务状态，
    // 不在 View 维护第二套 completed 状态。
    private func swipeActions(for request: CustomerRequest) -> [V32SwipeAction] {
        switch request.statusEnum {
        case .pending:
            return [V32SwipeAction(title: "开始配送", systemName: "bicycle", tint: V32.brand) {
                advance(request)
            }]
        case .delivering:
            return [V32SwipeAction(title: "完成", systemName: "checkmark", tint: V32.brand) {
                advance(request)
            }]
        case .done:
            return []
        }
    }
}

// MARK: - 配送行（V371 WorkRow：StatusBadge + 房号/客户 + 配送内容 + 时间 + 推进动作）

private struct CustomerWorkRow: View {
    let request: CustomerRequest
    let onEdit: () -> Void
    let onCopyAddress: (CustomerRequest) -> Void
    let onAdvance: () -> Void
    let onDelete: () -> Void

    private var status: CustomerStatus { request.statusEnum }

    private var icon: String {
        switch status {
        case .pending: return "clock"
        case .delivering: return "bicycle"
        case .done: return "checkmark"
        }
    }

    /// 彩色微状态只用于 icon / badge（§2-D）。
    private var statusColor: Color {
        switch status {
        case .pending: return V371.Colors.orange
        case .delivering: return V371.Colors.blue
        case .done: return V371.Colors.gray
        }
    }

    /// 行内时间（§9）：优先展示设置的送达时间，否则展示创建时间。
    private var timeText: String {
        if let deliveryTime = CustomerDeliveryStorage.decode(request.customer).deliveryTime {
            return Fmt.monthDayTime(deliveryTime)
        }
        return Fmt.monthDayTime(request.createdAt)
    }

    var body: some View {
        WorkRow(
            icon: icon,
            iconColor: statusColor,
            title: request.displayTitle,
            subtitle: request.displaySubtitle,
            action: onEdit
        ) {
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(status.rawValue, color: statusColor)
                    Text(timeText)
                        .font(V371.Typography.time)
                        .foregroundStyle(V371.Colors.textTertiary)
                        .lineLimit(1)
                }
                // P0-4：配送带图时在行内直接显示缩略图（round-trip：列表可见）
                if request.imageData != nil {
                    ImageThumb(imageData: request.imageData, size: 44)
                }
                // 行内只保留主状态操作；复制/删除等次级动作进 contextMenu
                if status != .done {
                    Button(action: onAdvance) {
                        Image(systemName: status == .pending ? "bicycle" : "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(V371.Colors.blue)
                            .frame(width: 44, height: 44)
                            .background(V371.Colors.tinted(V371.Colors.blue), in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(status == .pending ? "开始配送" : "完成配送")
                    .accessibilityIdentifier(V371AccessibilityID.customerAdvance)
                }
            }
        }
        .contextMenu {
            Button("编辑") { onEdit() }
            if request.roomOrAddress.nonEmpty != nil {
                Button("复制地址") { onCopyAddress(request) }
            }
            Button("删除", role: .destructive) { onDelete() }
        }
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

// MARK: - V32 Swipe Action（自绘 swipe，不退回裸 List 系统样式）
// P0-2：CustomerView 配送 Row 专用。pending/delivering 右滑露出操作按钮，
// done 不允许 swipe。Swipe 动画统一引用 V32Motion（不夸张）。
// V371：前景行背景透明，坐在 GroupSurface 上（不做嵌套卡片）。

private struct V32SwipeAction: Identifiable {
    let id = UUID()
    let title: String
    let systemName: String
    let tint: Color
    let perform: () -> Void
}

