import SwiftUI
import SwiftData

// MARK: - 商品页（V371：grouped list；库存概览 + 分组行）
//
// 保留 V3.6 全部功能：搜索、分类筛选、四格统计、新增/编辑/删除。不新增复杂商品管理。

struct GoodsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allGoods: [Goods]

    @State private var query = ""
    @State private var category = "全部"
    @State private var showNewEditor = false
    @State private var editingGoods: Goods?
    @State private var failedDeleteGoodsID: PersistentIdentifier?
    @State private var deleteError: String?
    // 临时诊断：重试路径状态（诊断后移除）
    @State private var retryDiag = ""
    private var isMockPreview: Bool { RuntimeMode.allowsMockData }

    private var filtered: [Goods] {
        GoodsFilter.filtered(goods: allGoods, query: query, category: category)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V371.Space.section) {
                searchField
                statSection
                categoryPicker
                #if DEBUG
                if UITestMode.isEnabled && !retryDiag.isEmpty {
                    Text(retryDiag)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("goods.retryDiag")
                }
                #endif

                if isMockPreview {
                    mockSection
                } else if filtered.isEmpty {
                    EmptyState(icon: "shippingbox", title: "还没有商品")
                        .padding(.top, 12)
                } else {
                    goodsSection
                }
            }
            .padding(.horizontal, V371.Space.page)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(V371AccessibilityID.screenGoods)
        .v371Canvas()
        .v371DockInset()
        .navigationTitle("临时商品")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("新增商品")
            }
        }
        .sheet(isPresented: $showNewEditor) {
            GoodsEditorSheet(goods: nil)
        }
        .sheet(item: $editingGoods) { goods in
            GoodsEditorSheet(goods: goods)
        }
        .alert("删除失败", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("重试") {
                retryDelete()
            }
            .accessibilityIdentifier(V371AccessibilityID.reliabilityRetry)
            Button("取消", role: .cancel) {
                deleteError = nil
                failedDeleteGoodsID = nil
            }
        } message: { Text(deleteError ?? "商品未删除，请重试。") }
    }

    // MARK: 搜索与筛选

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(V371.Colors.textTertiary)
                .accessibilityHidden(true)
            TextField("搜索商品 / 条码", text: $query)
                .font(V371.Typography.rowTitle)
                .foregroundStyle(V371.Colors.textPrimary)
                .tint(V371.Colors.blue)
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    Haptic.light()
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(V371.Colors.textTertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.leading, V371.Space.rowPadding)
        .padding(.trailing, query.isEmpty ? V371.Space.rowPadding : 4)
        .padding(.vertical, 4)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: V371.Radius.group, style: .continuous)
                .fill(V371.Colors.group)
        )
    }

    private var categoryPicker: some View {
        Picker("分类", selection: Binding(
            get: { category },
            set: { setCategory($0) }
        )) {
            ForEach(GoodsCategory.filters, id: \.self) { item in
                Text(item).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .tint(V371.Colors.blue)
        .accessibilityLabel("商品分类筛选")
    }

    private func setCategory(_ newValue: String) {
        withAnimation(V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion))) {
            category = newValue
        }
    }

    // MARK: 库存概览

    private var statSection: some View {
        GroupSurface {
            HStack(spacing: 0) {
                statCell(label: "全部商品", count: allGoods.count, color: V371.Colors.blue)
                statVDivider
                statCell(label: "库存不足", count: GoodsStats.lowStock(allGoods), color: V371.Colors.orange)
                statVDivider
                statCell(label: "临期", count: GoodsStats.expiringSoon(allGoods), color: V371.Colors.orange)
                statVDivider
                statCell(label: "总库存", count: GoodsStats.totalStock(allGoods), color: V371.Colors.textSecondary)
            }
        }
    }

    private var statVDivider: some View {
        Rectangle()
            .fill(V371.Colors.divider)
            .frame(width: 0.5)
            .padding(.vertical, 14)
    }

    private func statCell(label: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(V371.Typography.rowSubtitle)
                .foregroundStyle(V371.Colors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, V371.Space.rowPadding)
        .padding(.vertical, 14)
    }

    // MARK: 列表

    private var goodsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("商品") {
                Text("\(filtered.count)")
                    .font(V371.Typography.badge)
                    .foregroundStyle(V371.Colors.textTertiary)
            }
            GroupSurface {
                ForEach(Array(filtered.enumerated()), id: \.element.persistentModelID) { index, goods in
                    if index > 0 { V371Divider(leading: 62) }
                    goodsRow(goods)
                }
            }
        }
    }

    private func goodsRow(_ goods: Goods) -> some View {
        let state = GoodsState.of(goods)
        let tone = goodsTone(state)
        return WorkRow(
            icon: "shippingbox",
            iconColor: tone,
            title: goods.name,
            subtitle: goodsSubtitle(goods),
            action: { editingGoods = goods }
        ) {
            HStack(spacing: 4) {
                VStack(alignment: .trailing, spacing: 5) {
                    StatusBadge(state.label, color: tone)
                    Text(Fmt.money(goods.salePrice))
                        .font(V371.Typography.time)
                        .foregroundStyle(V371.Colors.textSecondary)
                        .lineLimit(1)
                }
                Button { delete(goods) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundStyle(V371.Colors.textTertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("删除商品")
                .accessibilityIdentifier(V371AccessibilityID.goodsDelete)
            }
        }
    }

    /// 状态色：已过期红 / 临期·缺货橙 / 正常蓝（warning 色只用在需要处）。
    private func goodsTone(_ state: GoodsState) -> Color {
        switch state {
        case .expired: return V371.Colors.red
        case .expiringSoon, .lowStock: return V371.Colors.orange
        case .normal: return V371.Colors.blue
        }
    }

    private func goodsSubtitle(_ goods: Goods) -> String {
        var parts = ["库存 \(goods.stock) · 最低 \(goods.minStock)"]
        if let expiry = goods.expiryDate {
            parts.append("到期 \(Fmt.formatDate(expiry))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Mock 预览（仅 Preview / UI 验收进程）

    private var mockSection: some View {
        let items: [(String, String, String)] = [
            ("鲜牛奶 ×6", "明天退货", "高优先级"),
            ("三明治 ×4", "今晚处理", "中优先级"),
            ("面包 ×8", "剩2天", ""),
            ("酸奶 ×5", "剩3天", ""),
            ("泳裤 ×2", "待退供应商", ""),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("商品")
            GroupSurface {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if index > 0 { V371Divider(leading: 62) }
                    let tone: Color = item.2 == "高优先级" ? V371.Colors.red : V371.Colors.orange
                    WorkRow(
                        icon: "shippingbox",
                        iconColor: item.2.isEmpty ? V371.Colors.blue : tone,
                        title: item.0,
                        subtitle: item.1
                    ) {
                        if !item.2.isEmpty {
                            StatusBadge(item.2, color: tone)
                        }
                    }
                }
            }
        }
    }

    // MARK: 删除

    private func delete(_ goods: Goods) {
        Haptic.warning()
        #if DEBUG
        let diagEnabled = UITestMode.isEnabled
        #else
        let diagEnabled = false
        #endif
        do {
            try UITestFailureInjection.throwIfRequested(.goodsDelete)
            let targetID = goods.persistentModelID
            try GoodsRepository(context: context).delete(goods)
            // 独立验证：用新 ModelContext 重查，确认持久化结果（不吞异常）
            if diagEnabled {
                do {
                    let verifyContext = ModelContext(context.container)
                    let fetched = verifyContext.model(for: targetID) as? Goods
                    if fetched == nil {
                        retryDiag = "DIAG-VERIFY: 独立查询目标不存在→持久化成功，查@Query/列表刷新"
                    } else {
                        retryDiag = "DIAG-VERIFY: 独立查询目标仍存在→删除未持久化，查delete/save"
                    }
                } catch {
                    retryDiag = "DIAG-VERIFY: 独立查询抛错: \(error)"
                }
            }
            failedDeleteGoodsID = nil
        } catch {
            Haptic.error()
            // 存 ID 而非对象，避免 SwiftData fault 导致重试时对象失效
            failedDeleteGoodsID = goods.persistentModelID
            deleteError = "商品未删除，请重试。"
        }
    }

    private func retryDelete() {
        #if DEBUG
        let diagEnabled = UITestMode.isEnabled
        #else
        let diagEnabled = false
        #endif
        guard let id = failedDeleteGoodsID else {
            if diagEnabled { retryDiag = "DIAG-RETRY: failedDeleteGoodsID 为空，未执行删除" }
            // 明确显示失败，不允许静默结束
            deleteError = "重试失败：未找到待删除的商品，请重新操作。"
            return
        }
        if diagEnabled { retryDiag = "DIAG-RETRY: id=\(id)" }
        deleteError = nil
        // 用 Fetch 全量后内存比对 ID（predicate 对 PersistentIdentifier 比较不可靠）
        do {
            let all = try context.fetch(FetchDescriptor<Goods>())
            if let goods = all.first(where: { $0.persistentModelID == id }) {
                if diagEnabled { retryDiag = "DIAG-RETRY: 取到对象 name=\(goods.name)，调用 delete" }
                delete(goods)
                if diagEnabled { retryDiag += " → delete 返回" }
            } else {
                if diagEnabled { retryDiag = "DIAG-RETRY: 全量fetch未找到对象，显示明确失败" }
                failedDeleteGoodsID = nil
                deleteError = "商品数据异常，无法重试删除。"
            }
        } catch {
            if diagEnabled { retryDiag = "DIAG-RETRY: fetch抛错: \(error)" }
            deleteError = "重试失败：\(error.localizedDescription)"
        }
    }
}
