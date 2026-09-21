import SwiftUI

// MARK: - 临时商品新增/编辑 Sheet（V32）

struct GoodsEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                nameCard
                categoryCard
                barcodeCard
                stockCard
                priceCard
                productionCard
                shelfLifeCard
                expiryCard
                noteCard
                imageCard
                V32PrimaryButton(title: "保存", systemName: "checkmark") { save() }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 14)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32Sheet([.large])
        .onAppear(perform: initializeIfNeeded)
    }

    private var header: some View {
        ZStack {
            Text(goods == nil ? "新增商品" : "编辑商品")
                .v32Text(.headline)
                .foregroundStyle(V32.textPrimary)
            HStack {
                Button("取消") { dismiss() }
                    .v32Text(.body)
                    .foregroundStyle(V32.textTertiary)
                Spacer()
            }
        }
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("商品名称")
            V32FieldGroup {
                TextField("例如：农夫山泉 550ml", text: $name)
                    .v32Text(.body)
                    .foregroundStyle(V32.textPrimary)
                    .tint(V32.brand)
            }
        }
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("分类")
            V32SegmentedPicker(
                tabs: GoodsCategory.known,
                selectionIndex: Binding(
                    get: { GoodsCategory.known.firstIndex(of: category) ?? GoodsCategory.known.count - 1 },
                    set: { category = GoodsCategory.known[$0] }
                )
            )
        }
    }

    private var barcodeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("条码")
            V32FieldGroup {
                TextField("扫码或输入（可选）", text: $barcode)
                    .v32Text(.body)
                    .foregroundStyle(V32.textPrimary)
                    .tint(V32.brand)
                    .keyboardType(.numbersAndPunctuation)
            }
        }
    }

    private var stockCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("库存")
            V32FieldGroup {
                HStack(spacing: 12) {
                    numberField("当前库存", text: $stockText)
                    Rectangle().fill(V32.divider).frame(width: 1, height: 36)
                    numberField("最低库存", text: $minStockText)
                }
            }
        }
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("价格")
            V32FieldGroup {
                HStack(spacing: 12) {
                    numberField("进货价", text: $purchaseText, decimal: true)
                    Rectangle().fill(V32.divider).frame(width: 1, height: 36)
                    numberField("销售价", text: $saleText, decimal: true)
                }
            }
        }
    }

    private var productionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("生产日期")
            V32FieldGroup {
                VStack(spacing: 12) {
                    toggleRow("设置生产日期", isOn: $hasProductionDate)
                    if hasProductionDate {
                        Rectangle().fill(V32.divider).frame(height: 1)
                        DatePicker("生产日期", selection: $productionDate, displayedComponents: .date)
                            .v32Text(.title)
                            .tint(V32.brand)
                    }
                }
            }
        }
    }

    private var shelfLifeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("保质期")
            V32FieldGroup {
                TextField("保质期天数，如 365（可选）", text: $shelfLifeText)
                    .v32Text(.body)
                    .foregroundStyle(V32.textPrimary)
                    .tint(V32.brand)
                    .keyboardType(.numberPad)
            }
        }
    }

    private var expiryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("到期日期")
            V32FieldGroup {
                VStack(spacing: 12) {
                    toggleRow("设置到期日期", isOn: $hasExpiryDate)
                    if hasExpiryDate {
                        Rectangle().fill(V32.divider).frame(height: 1)
                        DatePicker("到期日期", selection: $expiryDate, in: Date()..., displayedComponents: .date)
                            .v32Text(.title)
                            .tint(V32.brand)
                    }
                }
            }
        }
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("备注")
            V32FieldGroup {
                TextField("备注（可选）", text: $note, axis: .vertical)
                    .v32Text(.body)
                    .foregroundStyle(V32.textSecondary)
                    .tint(V32.brand)
                    .lineLimit(2...4)
            }
        }
    }

    private var imageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("商品图片")
            V32FieldGroup { PhotoPickerField(imageData: imageData) { imageData = $0 } }
        }
    }

    // MARK: 复用

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .v32Text(.title)
                .foregroundStyle(V32.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(V32.brand)
        }
    }

    private func numberField(_ label: String, text: Binding<String>, decimal: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .v32Text(.caption)
                .foregroundStyle(V32.textTertiary)
            TextField(decimal ? "0.00" : "0", text: text)
                .v32Text(.headline)
                .foregroundStyle(V32.textPrimary)
                .tint(V32.brand)
                .keyboardType(decimal ? .decimalPad : .numberPad)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 逻辑

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
