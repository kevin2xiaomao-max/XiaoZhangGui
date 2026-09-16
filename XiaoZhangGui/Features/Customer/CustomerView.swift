import SwiftUI
import SwiftData

struct CustomerView: View {
    @Environment(\.modelContext) private var context
    @Query private var requests: [CustomerRequest]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filter: CustomerFilter = .all
    @State private var showNewEditor = false
    @State private var editingRequest: CustomerRequest?
    @State private var deletingRequest: CustomerRequest?
    @State private var showDoneToast = false

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
                        set: { newValue in
                            withAnimation(V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion))) {
                                filter = CustomerFilter.allCases[newValue]
                            }
                        }
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
                    // P0-2：每个 Row 用 V32SwipeRow 包装，
                    // 让 pending → 右滑露出「开始配送」、delivering → 右滑露出「✓ 完成」。
                    // done 状态 actions 为空，不允许 swipe。
                    // 整体保留 b27 的 V32Card 外观（圆角 + 白底 + 描边），
                    // 额外加 clipShape 让 swipe 偏移不溢出圆角边界。
                    VStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element.persistentModelID) { index, request in
                            if index > 0 {
                                Rectangle().fill(V32.divider).frame(height: 1).padding(.leading, 48)
                            }
                            V32SwipeRow(actions: swipeActions(for: request)) {
                                CustomerRow(
                                    request: request,
                                    onEdit: { editingRequest = request },
                                    onCopyAddress: copyAddress,
                                    onAdvance: { advance(request) },
                                    onDelete: { deletingRequest = request }
                                )
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: V32Radius.card, style: .continuous)
                            .fill(V32.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: V32Radius.card, style: .continuous)
                            .strokeBorder(V32.cardOutline, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: V32Radius.card, style: .continuous))
                }
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32PageBottomInset()
        .toolbar(.hidden, for: .navigationBar)
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
                    try? CustomerRepository(context: context).delete(request)
                }
                deletingRequest = nil
            }
            Button("取消", role: .cancel) { deletingRequest = nil }
        }
    }

    private func advance(_ request: CustomerRequest) {
        let willComplete = request.statusEnum == .delivering
        try? CustomerRepository(context: context).advanceStatus(request)
        if willComplete {
            Haptic.success()
            withAnimation(V32Motion.softSpring) { showDoneToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(V32Motion.softSpring) { showDoneToast = false }
            }
        } else {
            Haptic.light()
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
                // P0-4：配送带图时在行内直接显示缩略图（round-trip：列表可见）
                if request.imageData != nil {
                    ImageThumb(imageData: request.imageData, size: 44)
                }
                V32StatusPill(text: request.statusEnum.rawValue, status: status)
            }
            // 行内只保留主状态操作；复制/删除等次级动作进 contextMenu（T19）
            if request.statusEnum != .done {
                HStack(spacing: 6) {
                    Spacer().frame(width: 46)
                    Spacer()
                    rowActionButton(request.statusEnum == .pending ? "bicycle" : "checkmark",
                                    tint: V32.brand, action: onAdvance)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contextMenu {
            Button("编辑") { onEdit() }
            if request.roomOrAddress.nonEmpty != nil {
                Button("复制地址") { onCopyAddress(request) }
            }
            Button("删除", role: .destructive) { onDelete() }
        }
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

// MARK: - V32 Swipe Action（自绘 swipe，不退回裸 List 系统样式）
// P0-2：CustomerView 配送 Row 专用。pending/delivering 右滑露出操作按钮，
// done 不允许 swipe。Swipe 动画统一引用 V32Motion（不夸张）。

private struct V32SwipeAction: Identifiable {
    let id = UUID()
    let title: String
    let systemName: String
    let tint: Color
    let perform: () -> Void
}

private struct V32SwipeRow<Content: View>: View {
    let actions: [V32SwipeAction]
    @ViewBuilder var content: Content

    @State private var offsetX: CGFloat = 0
    @State private var startOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let buttonWidth: CGFloat = 76
    private var maxSwipe: CGFloat { CGFloat(actions.count) * buttonWidth }
    private var animation: Animation {
        reduceMotion ? V32Motion.reducedFade : V32Motion.interactiveSpring
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // 背景按钮（右滑露出）
            if !actions.isEmpty {
                HStack(spacing: 0) {
                    Spacer()
                    ForEach(actions) { action in
                        Button {
                            trigger(action)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: action.systemName)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(action.title)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(Color.white)
                            .frame(width: buttonWidth)
                            .frame(maxHeight: .infinity)
                            .background(action.tint)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            // 前景内容：done 时无 swipe 手势，避免拦截 ScrollView 滚动
            foreground
        }
    }

    @ViewBuilder
    private var foreground: some View {
        if actions.isEmpty {
            content.background(V32.card)
        } else {
            content
                .background(V32.card)
                .offset(x: offsetX)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 14)
                        .onChanged { value in
                            // 只允许左滑（向负方向），不超过 -maxSwipe
                            let target = startOffset + value.translation.width
                            offsetX = min(0, max(-maxSwipe, target))
                        }
                        .onEnded { value in
                            let snapped = snap(offset: offsetX, predicted: value.predictedEndTranslation.width)
                            startOffset = snapped
                            withAnimation(animation) {
                                offsetX = snapped
                            }
                        }
                )
        }
    }

    private func snap(offset: CGFloat, predicted: CGFloat) -> CGFloat {
        if actions.isEmpty { return 0 }
        let threshold = -maxSwipe / 2
        if offset < threshold || predicted < -maxSwipe * 0.6 {
            return -maxSwipe
        }
        return 0
    }

    private func trigger(_ action: V32SwipeAction) {
        withAnimation(animation) {
            offsetX = 0
            startOffset = 0
        }
        action.perform()
    }
}
