import Foundation

/// 扫呗文件入口的轻量校验。文件提供器可以把 xlsx 识别成泛型 data，
/// 因此选择阶段允许 data，解析阶段仍严格按扩展名和内容拒绝伪装文件。
enum SaobeiFileValidator {
    enum Kind: Equatable {
        case csv
        case xlsx
    }

    static func kind(for fileName: String, data: Data) -> Kind? {
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        if ext == "csv" || ext == "txt" {
            return isLikelyCSV(data) ? .csv : nil
        }
        if ext == "xlsx" {
            return data.count >= 4 && data.prefix(4).elementsEqual([0x50, 0x4B, 0x03, 0x04]) ? .xlsx : nil
        }
        return nil
    }

    static func isLikelyCSV(_ data: Data) -> Bool {
        guard !data.isEmpty, let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .utf16) else { return false }
        let firstLine = text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).first.map(String.init) ?? ""
        return firstLine.contains(",") || firstLine.contains("，") ||
            (firstLine.contains("交易时间") && firstLine.contains("收款金额"))
    }
}
