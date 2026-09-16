import Foundation
import UIKit
import Observation

// MARK: - V3.3 Lite · 收款码 Store
//
// 职责：编排轻量 metadata（UserDefaults）与图片文件（Application Support/PaymentCodes/）。
// 不变量：
// - metadata 永远不包含图片 Data/base64
// - 删除：先移除文件再更新 metadata，只删自己指向的文件
// - 替换：新文件落盘成功 + metadata 更新后才删除旧文件（失败时旧图原样保留，无孤儿）
// - 顺序：追加 order 递增；codes 始终按 order 升序

@Observable
@MainActor
final class PaymentCodeStore {

    static let shared = PaymentCodeStore()

    private(set) var codes: [PaymentCode] = []

    private let metadata: PaymentCodeMetadataStore
    private let images: PaymentCodeImageStore

    init(metadata: PaymentCodeMetadataStore? = nil, images: PaymentCodeImageStore? = nil) {
        self.metadata = metadata ?? PaymentCodeMetadataStore()
        self.images = images ?? PaymentCodeImageStore()
        load()
    }

    // MARK: - 读取

    func load() {
        codes = metadata.load()
    }

    /// 读取某张码的图片；文件缺失 / 损坏返回 nil（UI 显示占位）
    func image(for code: PaymentCode) -> UIImage? {
        images.image(for: code.fileName)
    }

    // MARK: - 新增

    @discardableResult
    func addCode(name: String, kind: PaymentCodeKind, imageData: Data) throws -> PaymentCode {
        guard UIImage(data: imageData) != nil else { throw PaymentCodeError.invalidImageData }

        let fileName = try images.save(imageData)
        let code = PaymentCode(id: UUID(),
                               name: Self.resolvedName(name, kind: kind),
                               kind: kind,
                               fileName: fileName,
                               createdAt: Date(),
                               order: (codes.map(\.order).max() ?? -1) + 1)
        codes.append(code)
        sortAndPersist()
        return code
    }

    // MARK: - 重命名

    func rename(id: UUID, to name: String) {
        guard let index = codes.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        codes[index].name = trimmed
        persist()
    }

    // MARK: - 替换图片

    /// 用新图片替换指定码。新文件落盘成功并更新 metadata 后才清理旧文件。
    @discardableResult
    func replaceImage(id: UUID, with imageData: Data) throws -> PaymentCode {
        guard let index = codes.firstIndex(where: { $0.id == id }) else {
            throw PaymentCodeError.invalidImageData
        }
        guard UIImage(data: imageData) != nil else { throw PaymentCodeError.invalidImageData }

        let newFileName = try images.save(imageData)
        let oldFileName = codes[index].fileName
        codes[index].fileName = newFileName
        persist()
        // 只有此刻旧文件才可清理（metadata 已指向新文件）
        if newFileName != oldFileName {
            images.delete(oldFileName)
        }
        return codes[index]
    }

    // MARK: - 删除

    func delete(id: UUID) {
        guard let index = codes.firstIndex(where: { $0.id == id }) else { return }
        let fileName = codes[index].fileName
        images.delete(fileName)
        codes.remove(at: index)
        persist()
    }

    // MARK: - Private

    private func sortAndPersist() {
        codes.sort { lhs, rhs in
            lhs.order != rhs.order ? lhs.order < rhs.order : lhs.createdAt < rhs.createdAt
        }
        persist()
    }

    private func persist() {
        metadata.save(codes)
    }

    private static func resolvedName(_ raw: String, kind: PaymentCodeKind) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.displayName : trimmed
    }
}
