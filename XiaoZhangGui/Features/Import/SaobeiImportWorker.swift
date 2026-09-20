import Foundation

/// 文件读取、校验和解析的非主线程接缝。UI 只负责在 MainActor 更新状态。
enum SaobeiImportWorker {
    static func parse(url: URL, fileName: String) throws -> SaobeiParseResult {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard SaobeiFileValidator.kind(for: fileName, data: data) != nil else {
            throw SaobeiImportError.noHeader
        }
        return try SaobeiImporter().parse(data: data, fileName: fileName)
    }

    static func parse(data: Data, fileName: String) throws -> SaobeiParseResult {
        guard SaobeiFileValidator.kind(for: fileName, data: data) != nil else {
            throw SaobeiImportError.noHeader
        }
        return try SaobeiImporter().parse(data: data, fileName: fileName)
    }
}
