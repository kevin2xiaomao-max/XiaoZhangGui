import Foundation
import SwiftData

/// 临时商品（对齐 Android GoodsEntity 真实字段，字段全保留；
/// iOS UI 定位为"轻量临时商品/需要采购/退货提醒"，不做库存 ERP）
@Model
final class Goods {
    var name: String = ""
    var category: String = "其他"
    var barcode: String = ""
    var stock: Int = 0
    var minStock: Int = 0
    var purchasePrice: Double = 0
    var salePrice: Double = 0
    var productionDate: Date?
    var shelfLifeDays: Int = 0
    var expiryDate: Date?
    var note: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        name: String,
        category: String = "其他",
        barcode: String = "",
        stock: Int = 0,
        minStock: Int = 0,
        purchasePrice: Double = 0,
        salePrice: Double = 0,
        productionDate: Date? = nil,
        shelfLifeDays: Int = 0,
        expiryDate: Date? = nil,
        note: String = "",
        imageData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.name = name
        self.category = category
        self.barcode = barcode
        self.stock = stock
        self.minStock = minStock
        self.purchasePrice = purchasePrice
        self.salePrice = salePrice
        self.productionDate = productionDate
        self.shelfLifeDays = shelfLifeDays
        self.expiryDate = expiryDate
        self.note = note
        self.imageData = imageData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Goods {
    var isLowStock: Bool { stock <= minStock }
}
