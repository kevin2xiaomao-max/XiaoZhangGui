import SwiftUI

// MARK: - 临时商品新增/编辑 Sheet（名称/分类/条码/库存/价格/日期/保质期/备注/图片）

struct GoodsEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    /// nil = 新增
    let goods: Goods?

    @State private var name = ""
    @State private var category = "其他"
    @State private var barcode = ""
    @State private var stockText = "0"
    @State private var minStockText = "0"
    @State private var purchaseText = ""
    @State private var saleText = ""
    @State private var hasProductionDate = false
    @State private var productionDate = Date()
    @State private var shelfLifeText = ""
    @State private var hasExpiryDate = false
    @State private var expiryDate = Date()
    @State private var note = ""
    @State private var imageData: Data?
    @State private var isInitialized = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: V21Layout.spaceXL) {
                    nameField
                    categorySection
                    barcodeField
                    stockSection
                    priceSection
                    productionSection
                    shelfLifeField
                    expirySection
                    noteField
                    imageSection
                }
                .padding(.horizontal, V21Layout.pageMargin)
                .padding(.top, V21Layout.spaceLG)
                .padding(.bottom, 48)
            }
            .navigationTitle(goods == nil ? "新增商品" : "编辑商品")
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

    // MARK: - 输入区块

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("商品名称")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            TextField("例如：农夫山泉 550ml", text: $name)
                .v21Style(.bodyLarge)
                .foregroundColor(V21.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background { editorBackground }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分类")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            HStack(spacing: 6) {
                ForEach(GoodsCategory.known, id: \.self) { item in
                    let selected = category == item
                    Button {
                        category = item
                        Haptic.light()
                    } label: {
                        Text(item)
                            .font(.system(size: 13, weight: selected ? .semibold : .medium))
                            .foregroundColor(selected ? V21.textPrimary : V21.tabInactive)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
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
                Spacer()
            }
        }
    }

    private var barcodeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("条码（可选）")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            TextField("扫码或输入", text: $barcode)
                .keyboardType(.numbersAndPunctuation)
                .v21Style(.bodyLarge)
                .foregroundColor(V21.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background { editorBackground }
        }
    }

    private var stockSection: some View {
        HStack(spacing: 12) {
            numberField("当前库存", text: $stockText)
            numberField("最低库存", text: $minStockText)
        }
    }

    private var priceSection: some View {
        HStack(spacing: 12) {
            numberField("进货价", text: $purchaseText, decimal: true)
            numberField("销售价", text: $saleText, decimal: true)
        }
    }

    private var productionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("生产日期（可选）")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            GlassSurface {
                VStack(spacing: 0) {
                    Toggle("设置生产日期", isOn: $hasProductionDate.animation(.easeOut(duration: 0.15)))
                        .tint(AppTheme.palette(named: settings.appThemeName).accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    if hasProductionDate {
                        Divider().overlay(V21.divider)
                        DatePicker("生产日期", selection: $productionDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .font(.system(size: 15, weight: .medium))
                    }
                }
            }
        }
    }

    private var shelfLifeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("保质期（天，可选）")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            TextField("如 365", text: $shelfLifeText)
                .keyboardType(.numberPad)
                .v21Style(.bodyLarge)
                .foregroundColor(V21.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background { editorBackground }
        }
    }

    private var expirySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("到期日期（可选）")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            GlassSurface {
                VStack(spacing: 0) {
                    Toggle("设置到期日期", isOn: $hasExpiryDate.animation(.easeOut(duration: 0.15)))
                        .tint(AppTheme.palette(named: settings.appThemeName).accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    if hasExpiryDate {
                        Divider().overlay(V21.divider)
                        DatePicker("到期日期", selection: $expiryDate, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .font(.system(size: 15, weight: .medium))
                    }
                }
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注（可选）")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            TextField("备注", text: $note, axis: .vertical)
                .v21Style(.bodyMedium)
                .foregroundColor(V21.textPrimary)
                .lineLimit(2...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background { editorBackground }
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("商品图片（可选）")
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            PhotoPickerField(imageData: imageData) { imageData = $0 }
        }
    }

    // MARK: - 复用样式

    private var editorBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: V21Layout.radiusMD, style: .continuous)
                .fill(V21.surfaceGlass)
            RoundedRectangle(cornerRadius: V21Layout.radiusMD, style: .continuous)
                .strokeBorder(V21.dividerStrong, lineWidth: 1)
        }
    }

    private func numberField(_ label: String, text: Binding<String>, decimal: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .v21Style(.labelLarge)
                .foregroundColor(V21.textTertiary)
            TextField(decimal ? "0.00" : "0", text: text)
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .v21Style(.bodyLarge)
                .foregroundColor(V21.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background { editorBackground }
        }
    }

    // MARK: - 逻辑

    private func initializeIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true
        guard let goods else { return }
        name = goods.name
        category = GoodsCategory.known.contains(goods.category) ? goods.category : "其他"
        barcode = goods.barcode
        stockText = String(goods.stock)
        minStockText = String(goods.minStock)
        purchaseText = goods.purchasePrice == 0 ? "" : String(goods.purchasePrice)
        saleText = goods.salePrice == 0 ? "" : String(goods.salePrice)
        if let production = goods.productionDate {
            hasProductionDate = true
            productionDate = production
        }
        shelfLifeText = goods.shelfLifeDays == 0 ? "" : String(goods.shelfLifeDays)
        if let expiry = goods.expiryDate {
            hasExpiryDate = true
            expiryDate = expiry
        }
        note = goods.note
        imageData = goods.imageData
    }

    private func save() {
        let trimmedName = String(name.trimmingCharacters(in: .whitespacesAndNewlines))
        let repo = GoodsRepository(context: context)
        do {
            if let goods {
                goods.name = trimmedName
                goods.category = category
                goods.barcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
                goods.stock = Int(stockText.filter(\.isNumber)) ?? 0
                goods.minStock = Int(minStockText.filter(\.isNumber)) ?? 0
                goods.purchasePrice = Double(purchaseText) ?? 0
                goods.salePrice = Double(saleText) ?? 0
                goods.productionDate = hasProductionDate ? productionDate : nil
                goods.shelfLifeDays = Int(shelfLifeText.filter(\.isNumber)) ?? 0
                goods.expiryDate = hasExpiryDate ? expiryDate : nil
                goods.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                goods.imageData = imageData
                try repo.update(goods)
            } else {
                let goods = Goods(
                    name: trimmedName,
                    category: category,
                    barcode: barcode.trimmingCharacters(in: .whitespacesAndNewlines),
                    stock: Int(stockText.filter(\.isNumber)) ?? 0,
                    minStock: Int(minStockText.filter(\.isNumber)) ?? 0,
                    purchasePrice: Double(purchaseText) ?? 0,
                    salePrice: Double(saleText) ?? 0,
                    productionDate: hasProductionDate ? productionDate : nil,
                    shelfLifeDays: Int(shelfLifeText.filter(\.isNumber)) ?? 0,
                    expiryDate: hasExpiryDate ? expiryDate : nil,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageData: imageData
                )
                try repo.add(goods)
            }
            Haptic.success()
            dismiss()
        } catch {
            Haptic.error()
        }
    }
}
