import Foundation
import UIKit

// MARK: - V3.3 Lite · 收款码图片本地存储
//
// - 图片只落盘到 Application Support/PaymentCodes/，原始数据不进 UserDefaults
// - 不上传、不发网络请求、不经过 AI / Provider
// - 文件名 payment-code-<UUID>.<ext>；删除/替换只操作 metadata 指向的具体文件，
//   绝不扫描目录做批量清理，避免误删无关文件
// - 读取失败（文件缺失 / 内容损坏）统一返回 nil，由 UI 显示占位，不崩溃

struct PaymentCodeImageStore {

    /// 收款码图片目录（生产）：Application Support/PaymentCodes/
    static var defaultDirectory: URL {
        let fm = FileManager.default
        let appSupport = try? fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true)
        let dir = (appSupport ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true))
            .appendingPathComponent("PaymentCodes", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    let directory: URL

    /// - Parameter directory: 测试可注入临时目录；生产传 nil 使用 Application Support/PaymentCodes/
    init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    /// 保存图片原始 Data，返回生成的文件名（不含路径）
    /// - Threshold: 调用方需先用 UIImage 校验数据可解码
    func save(_ data: Data) throws -> String {
        let fileName = "payment-code-\(UUID().uuidString)\(Self.fileExtension(for: data))"
        try data.write(to: url(for: fileName), options: .atomic)
        return fileName
    }

    func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    func data(for fileName: String) -> Data? {
        try? Data(contentsOf: url(for: fileName))
    }

    /// 文件缺失或数据损坏时返回 nil（不抛错、不崩溃）
    func image(for fileName: String) -> UIImage? {
        guard let data = data(for: fileName) else { return nil }
        return UIImage(data: data)
    }

    /// 删除指定文件；文件不存在视为成功。只删除传入的具体文件名。
    func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// 按魔数推断容器扩展名（仅用于文件名可读性；解码不依赖扩展名）
    private static func fileExtension(for data: Data) -> String {
        let bytes = Array(data.prefix(12))
        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return ".png"
        }
        // ISO-BMFF（HEIC/HEIF）/ JPEG 2000 等：第 4...7 字节为 ftyp
        if bytes.count >= 12, bytes[4] == 0x66, bytes[5] == 0x74, bytes[6] == 0x79, bytes[7] == 0x70 {
            let brand = String(decoding: bytes[8...11], as: UTF8.self)
            if brand.contains("heic") || brand.contains("heix") || brand.contains("mif1") || brand.contains("msf1") {
                return ".heic"
            }
        }
        // JPEG: FF D8 FF
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return ".jpg"
        }
        return ".img"
    }
}
