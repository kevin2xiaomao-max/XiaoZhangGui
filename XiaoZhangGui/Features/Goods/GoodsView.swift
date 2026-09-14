import SwiftUI
import SwiftData

// MARK: - 临时商品页（搜索 + 四格统计 + 分类 Tab + 商品卡片 + swipeActions + FAB）
// 轻量定位：需要采购 / 退货提醒，不做库存 ERP

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
        PageBackground {
            ZStack(alignment: .bottomTrailing) {
                List {
                    searchBar
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: V21Layout.pageMargin, bottom: 12, trailing: V21Layout.pageMargin))

                    statSection
                        .padding(.horizontal, V21Layout.pageMargin)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0))

                    categoryTabs
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))

                    if isMockPreview {
                        ForEach([("鲜牛奶 ×6", "明天退货", "高优先级"), ("三明治 ×4", "今晚处理", "中优先级"), ("面包 ×8", "剩2天", ""), ("酸奶 ×5", "剩3天", ""), ("泳裤 ×2", "待退供应商", "")], id: \.0) { item in
                            HStack { Circle().fill(item.2 == "高优先级" ? V21.danger : V21.warning).frame(width: 8, height: 8); VStack(alignment: .leading, spacing: 4) { Text(item.0).font(AppTypography.cardTitle).foregroundColor(V21.textPrimary); Text(item.1).font(AppTypography.caption).foregroundColor(V21.textTertiary) }; Spacer(); Text(item.2).font(AppTypography.micro).foregroundColor(item.2.isEmpty ? V21.textTertiary : V21.danger) }.padding(.horizontal, 16).padding(.vertical, 14).background(V21.surfaceGlass, in: RoundedRectangle(cornerRadius: 16)).listRowSeparator(.hidden).listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: V21Layout.pageMargin, bottom: 9, trailing: V21Layout.pageMargin))
                        }
                    } else if filtered.isEmpty {
                        EmptyStateView(text: "还没有商品", icon: "shippingbox")
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    } else {
                        ForEach(filtered) { goods in
                            GoodsCard(goods: goods) {
                                editingGoods = goods
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: V21Layout.pageMargin, bottom: 8, trailing: V21Layout.pageMargin))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(goods)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }

                }
                .listStyle(.plain)

                V21FAB(systemImage: "plus") {
                    showNewEditor = true
                }
                .padding(.trailing, V21Layout.spaceXL)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("临时商品")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNewEditor) {
            GoodsEditorSheet(goods: nil)
        }
        .sheet(item: $editingGoods) { goods in
            GoodsEditorSheet(goods: goods)
        }
    }

    private var searchBar: some View {
        GlassSurface(radius: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(V21.textTertiary)
                TextField("搜索商品 / 条码", text: $query)
                    .v21Style(.bodyMedium)
                    .foregroundColor(V21.textPrimary)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(V21.textQuaternary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
    }

    private var statSection: some View {
        HStack(spacing: 8) {
            GoodsStatCard(label: "全部商品", count: allGoods.count, color: V21.brandGreen)
            GoodsStatCard(label: "库存不足", count: GoodsStats.lowStock(allGoods), color: V21.warning)
            GoodsStatCard(label: "临期商品", count: GoodsStats.expiringSoon(allGoods), color: V21.warning)
            GoodsStatCard(label: "总库存", count: GoodsStats.totalStock(allGoods), color: V21.textTertiary)
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(GoodsCategory.filters, id: \.self) { item in
                    let selected = category == item
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { category = item }
                        Haptic.light()
                    } label: {
                        Text(item)
                            .v21Style(.labelLarge)
                            .foregroundColor(selected ? V21.textPrimary : V21.tabInactive)
                            .fontWeight(selected ? .semibold : .medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(selected ? AnyShapeStyle(V21.surfaceElevated) : AnyShapeStyle(.clear))
                            }
                            .overlay {
                                if selected {
                                    Capsule(style: .continuous)
                                        .strokeBorder(V21.dividerStrong, lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, V21Layout.pageMargin)
        }
    }

    private func delete(_ goods: Goods) {
        Haptic.warning()
        try? GoodsRepository(context: context).delete(goods)
    }
}

// MARK: - 统计卡

struct GoodsStatCard: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        GlassSurface(radius: 14) {
            VStack(spacing: 2) {
                Text("\(count)")
                    .v21Style(.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(label)
                    .v21Style(.labelSmall)
                    .foregroundColor(V21.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
        }
    }
}

// MARK: - 商品卡片

struct GoodsCard: View {
    let goods: Goods
    var onEdit: () -> Void

    private var state: GoodsState {
        GoodsState.of(goods)
    }

    var body: some View {
        Button(action: onEdit) {
            GlassSurface {
                HStack(spacing: 12) {
                    Group {
                        if let data = goods.imageData {
                            ImageThumb(imageData: data, size: 56)
                        } else {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 20))
                                .foregroundColor(V21.brandGreen)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(V21.surfacePrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(goods.name)
                                .v21Style(.titleMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(V21.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(state.label)
                                .v21Style(.labelSmall)
                                .foregroundColor(state.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(state.color.opacity(0.12))
                                }
                        }

                        if !goods.barcode.isEmpty {
                            Text("码 \(goods.barcode)")
                                .v21Style(.labelSmall)
                                .foregroundColor(V21.textQuaternary)
                        }

                        Text("库存 \(goods.stock)    最低 \(goods.minStock)")
                            .v21Style(.bodySmall)
                            .foregroundColor(V21.textSecondary)

                        Text("进价 \(Fmt.money(goods.purchasePrice))    售价 \(Fmt.money(goods.salePrice))    毛利 \(Fmt.money(goods.salePrice - goods.purchasePrice))")
                            .v21Style(.labelSmall)
                            .foregroundColor(V21.textTertiary)

                        if let expiry = goods.expiryDate {
                            Text("到期 \(Fmt.formatDate(expiry))")
                                .v21Style(.labelSmall)
                                .foregroundColor(state.color)
                        }
                    }
                }
                .padding(12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
