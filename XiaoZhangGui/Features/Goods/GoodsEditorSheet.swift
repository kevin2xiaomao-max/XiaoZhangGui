import SwiftUI

// MARK: - 临时商品新增/编辑 Sheet（V371：原生 Form）
//
// 业务语义保持 V3.6 原样：全部字段、数字解析规则、try/catch 保存。只做 presentation 迁移。

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
        NavigationStack {
            Form {
                Section("商品名称") {
                    TextField("例如：农夫山泉 550ml", text: $name)
                }
                Section("分类") {
                    Picker("分类", selection: $category) {
                        ForEach(GoodsCategory.known, id: \.self) { item in
                            Text(item).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section("条码") {
                    TextField("扫码或输入（可选）", text: $barcode)
                        .keyboardType(.numbersAndPunctuation)
                }
                Section("库存") {
                    HStack(spacing: 16) {
                        numberField("当前库存", text: $stockText)
                        numberField("最低库存", text: $minStockText)
                    }
                }
                Section("价格") {
                    HStack(spacing: 16) {
                        numberField("进货价", text: $purchaseText, decimal: true)
                        numberField("销售价", text: $saleText, decimal: true)
                    }
                }
                Section("生产日期") {
                    Toggle("设置生产日期", isOn: $hasProductionDate)
                    if hasProductionDate {
                        DatePicker("生产日期", selection: $productionDate, displayedComponents: .date)
                    }
                }
                Section("保质期") {
                    TextField("保质期天数，如 365（可选）", text: $shelfLifeText)
                        .keyboardType(.numberPad)
                }
                Section("到期日期") {
                    Toggle("设置到期日期", isOn: $hasExpiryDate)
                    if hasExpiryDate {
                        DatePicker("到期日期", selection: $expiryDate, in: Date()..., displayedComponents: .date)
                    }
                }
                Section("备注") {
                    TextField("备注（可选）", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("商品图片") {
                    PhotoPickerField(imageData: imageData) { imageData = $0 }
                }
            }
            .scrollContentBackground(.hidden)
            .background(V371.Colors.canvas)
            .tint(V371.Colors.blue)
            .navigationTitle(goods == nil ? "新增商品" : "编辑商品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear(perform: initializeIfNeeded)
    }

    // MARK: 复用

    private func numberField(_ label: String, text: Binding<String>, decimal: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(V371.Typography.rowSubtitle)
                .foregroundStyle(V371.Colors.textTertiary)
            TextField(decimal ? "0.00" : "0", text: text)
                .keyboardType(decimal ? .decimalPad : .numberPad)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 逻辑（与 V3.6 一致，不改动）

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
