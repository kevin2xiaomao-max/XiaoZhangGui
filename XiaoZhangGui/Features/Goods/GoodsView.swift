import SwiftUI
import SwiftData

// MARK: - 临时商品页（V32：搜索 + 四格统计 + 分类胶囊 + 商品卡片）

struct GoodsView: View {
    @Environment(\.modelContext) private var context
    @Query private var allGoods: [Goods]

    @State private var query = ""
    @State private var category = "全部"
    @State private var showNewEditor = false
    @State private var editingGoods: Goods?
    private var isMockPreview: Bool { RuntimeMode.allowsMockData }

    private var filtered: [Goods] {
        GoodsFilter.filtered(goods: allGoods, query: query, category: category)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                V32SearchField(placeholder: "搜索商品 / 条码", text: $query)
                statCard
                V32PillBar(items: GoodsCategory.filters, selection: $category)

                if isMockPreview {
                    ForEach([("鲜牛奶 ×6", "明天退货", "高优先级"), ("三明治 ×4", "今晚处理", "中优先级"), ("面包 ×8", "剩2天", ""), ("酸奶 ×5", "剩3天", ""), ("泳裤 ×2", "待退供应商", "")], id: \.0) { item in
                        mockRow(item)
                    }
                } else if filtered.isEmpty {
                    V32Card {
                        V32EmptyState(systemName: "shippingbox", title: "还没有商品", message: nil)
                            .padding(.vertical, 8)
                    }
                } else {
                    ForEach(filtered) { goods in
                        GoodsCard(goods: goods,
                                  onEdit: { editingGoods = goods },
                                  onDelete: { delete(goods) })
                    }
                }
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32PageBottomInset()
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
    }

    // MARK: 统计

    private var statCard: some View {
        V32Card {
            HStack(spacing: 6) {
                statCell(label: "全部商品", count: allGoods.count, color: V32.brand)
                statDivider
                statCell(label: "库存不足", count: GoodsStats.lowStock(allGoods), color: V32.amber)
                statDivider
                statCell(label: "临期", count: GoodsStats.expiringSoon(allGoods), color: V32.amber)
                statDivider
                statCell(label: "总库存", count: GoodsStats.totalStock(allGoods), color: V32.textSecondary)
            }
        }
    }

    private var statDivider: some View {
        Rectangle().fill(V32.divider).frame(width: 1, height: 32)
    }

    private func statCell(label: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(count)")
                .v32Text(.metricSmall)
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .v32Text(.pill)
                .foregroundStyle(V32.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mockRow(_ item: (String, String, String)) -> some View {
        V32Card {
            HStack(spacing: 12) {
                V32IconBubble(systemName: "shippingbox", tone: item.2 == "高优先级" ? .danger : .amber, size: 38, icon: 17)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.0).v32Text(.title).foregroundStyle(V32.textPrimary)
                    Text(item.1).v32Text(.caption).foregroundStyle(V32.textTertiary)
                }
                Spacer()
                if !item.2.isEmpty {
                    Text(item.2).v32Text(.pill).foregroundStyle(V32.danger)
                }
            }
        }
    }

    private func delete(_ goods: Goods) {
        Haptic.warning()
        try? GoodsRepository(context: context).delete(goods)
    }
}

// MARK: - 商品卡片（V32）

struct GoodsCard: View {
    let goods: Goods
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var state: GoodsState { GoodsState.of(goods) }

    private var stateTone: V32BubbleTone {
        switch state {
        case .expired: return .danger
        case .expiringSoon, .lowStock: return .amber
        case .normal: return .brand
        }
    }

    private var stateColor: Color {
        switch state {
        case .expired: return V32.danger
        case .expiringSoon, .lowStock: return V32.amber
        case .normal: return V32.brand
        }
    }

    var body: some View {
        V32Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    thumb
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(goods.name)
                                .v32Text(.title)
                                .foregroundStyle(V32.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            V32StatusPill(text: state.label, status: state == .normal ? .done : .expiry)
                        }
                        if !goods.barcode.isEmpty {
                            Text("码 \(goods.barcode)")
                                .v32Text(.caption)
                                .foregroundStyle(V32.textQuaternary)
                        }
                        Text("库存 \(goods.stock) · 最低 \(goods.minStock)")
                            .v32Text(.caption)
                            .foregroundStyle(V32.textSecondary)
                    }
                }

                Rectangle().fill(V32.divider).frame(height: 1)

                Text("进价 \(Fmt.money(goods.purchasePrice)) · 售价 \(Fmt.money(goods.salePrice)) · 毛利 \(Fmt.money(goods.salePrice - goods.purchasePrice))")
                    .v32Text(.caption)
                    .foregroundStyle(V32.textTertiary)
                    .lineLimit(1)

                if let expiry = goods.expiryDate {
                    Text("到期 \(Fmt.formatDate(expiry))")
                        .v32Text(.caption)
                        .foregroundStyle(stateColor)
                }

                HStack(spacing: 6) {
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(V32.brand)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(V32.brandSoft))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("编辑商品")
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(V32.textQuaternary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(V32.pageBGSecondary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("删除商品")
                }
            }
        }
        .onTapGesture(perform: onEdit)
    }

    private var thumb: some View {
        Group {
            if let data = goods.imageData {
                ImageThumb(imageData: data, size: 52)
            } else {
                V32IconBubble(systemName: "shippingbox", tone: stateTone, size: 52, icon: 22)
            }
        }
    }
}
