import Foundation
import SwiftData

/// 备忘（对齐 Android MemoEntity：title/content/imagePaths/createdAt/updatedAt）
@Model
final class Memo {
    var title: String = ""
    var content: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(title: String, content: String, imageData: Data? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.title = title
        self.content = content
        self.imageData = imageData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
