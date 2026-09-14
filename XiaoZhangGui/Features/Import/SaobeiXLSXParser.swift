import Foundation
import Compression

/// 轻量 xlsx 读取：不解第三方库。失败时提示另存为 CSV。
enum SaobeiXLSXParser {
    static func parse(data: Data, fileName: String) throws -> SaobeiParseResult {
        if let csvText = SaobeiCSVParser.decodeText(data),
           csvText.contains("交易") || csvText.contains("金额") {
            return try SaobeiCSVParser.parse(text: csvText, fileName: fileName)
        }
        guard data.starts(with: [0x50, 0x4b, 0x03, 0x04]) else {
            throw SaobeiImportError.unsupportedExcel("无法识别 Excel 格式，请在扫呗里另存为 CSV")
        }
        let files: [String: Data]
        do {
            files = try MiniZip.extract(data)
        } catch {
            throw SaobeiImportError.unsupportedExcel("Excel 解压失败，请另存为 CSV 后导入")
        }
        let sheetKey = files.keys.first { $0.hasSuffix("sheet1.xml") || $0.contains("worksheets/sheet") }
        guard let sheetKey, let sheet = files[sheetKey] else {
            throw SaobeiImportError.unsupportedExcel("Excel 中没有工作表，请另存为 CSV")
        }
        let shared = files.first { $0.key.contains("sharedStrings.xml") }?.value
        let strings = shared.flatMap { parseSharedStrings($0) } ?? []
        let table = parseSheet(sheet, shared: strings)
        guard !table.isEmpty else {
            throw SaobeiImportError.unsupportedExcel("Excel 内容为空，请另存为 CSV")
        }
        let csv = table.map { row in
            row.map { escapeCSV($0) }.joined(separator: ",")
        }.joined(separator: "\n")
        return try SaobeiCSVParser.parse(text: csv, fileName: fileName)
    }

    private static func parseSharedStrings(_ data: Data) -> [String] {
        guard let xml = String(data: data, encoding: .utf8) else { return [] }
        var result: [String] = []
        let pattern = try? NSRegularExpression(pattern: "<si[\\s\\S]*?<t[^>]*>([\\s\\S]*?)</t>", options: [])
        let ns = xml as NSString
        pattern?.enumerateMatches(in: xml, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match, match.numberOfRanges > 1 else { return }
            result.append(ns.substring(with: match.range(at: 1)).decodingXMLEntities())
        }
        return result
    }

    private static func parseSheet(_ data: Data, shared: [String]) -> [[String]] {
        guard let xml = String(data: data, encoding: .utf8) else { return [] }
        var rows: [Int: [Int: String]] = [:]
        let pattern = try? NSRegularExpression(
            pattern: "<c[^>]*r=\"([A-Z]+)(\\d+)\"[^>]*?(?:t=\"([^\"]+)\")?[^>]*>[\\s\\S]*?<v>([\\s\\S]*?)</v>",
            options: []
        )
        let ns = xml as NSString
        pattern?.enumerateMatches(in: xml, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match, match.numberOfRanges > 4 else { return }
            let colLetters = ns.substring(with: match.range(at: 1))
            let rowNum = Int(ns.substring(with: match.range(at: 2))) ?? 1
            let type = match.range(at: 3).location == NSNotFound ? "" : ns.substring(with: match.range(at: 3))
            let value = ns.substring(with: match.range(at: 4))
            let col = columnIndex(colLetters)
            let resolved: String
            if type == "s", let idx = Int(value), idx < shared.count {
                resolved = shared[idx]
            } else {
                resolved = value
            }
            rows[rowNum, default: [:]][col] = resolved
        }
        return rows.keys.sorted().map { key in
            let cols = rows[key] ?? [:]
            let maxCol = cols.keys.max() ?? 0
            return (0...maxCol).map { cols[$0] ?? "" }
        }
    }

    private static func columnIndex(_ letters: String) -> Int {
        letters.unicodeScalars.reduce(0) { $0 * 26 + Int($1.value - 64) } - 1
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

private extension String {
    func decodingXMLEntities() -> String {
        replacingOccurrences(of: "<", with: "<")
            .replacingOccurrences(of: ">", with: ">")
            .replacingOccurrences(of: "&", with: "&")
            .replacingOccurrences(of: """, with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}

enum MiniZip {
    static func extract(_ data: Data) throws -> [String: Data] {
        var result: [String: Data] = [:]
        var offset = 0
        let bytes = [UInt8](data)
        while offset + 30 < bytes.count {
            let sig = u32(bytes, offset)
            if sig != 0x04034b50 { break }
            let method = u16(bytes, offset + 8)
            let compSize = Int(u32(bytes, offset + 18))
            let nameLen = Int(u16(bytes, offset + 26))
            let extraLen = Int(u16(bytes, offset + 28))
            let nameStart = offset + 30
            let nameEnd = nameStart + nameLen
            guard nameEnd + extraLen + compSize <= bytes.count else { break }
            let name = String(bytes: bytes[nameStart..<nameEnd], encoding: .utf8) ?? "file"
            let dataStart = nameEnd + extraLen
            let payload = Data(bytes[dataStart..<(dataStart + compSize)])
            if method == 0 {
                result[name] = payload
            } else if method == 8, let inflated = inflate(payload) {
                result[name] = inflated
            }
            offset = dataStart + compSize
        }
        return result
    }

    private static func u16(_ b: [UInt8], _ i: Int) -> UInt16 {
        UInt16(b[i]) | UInt16(b[i + 1]) << 8
    }

    private static func u32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) | UInt32(b[i + 1]) << 8 | UInt32(b[i + 2]) << 16 | UInt32(b[i + 3]) << 24
    }

    private static func inflate(_ data: Data) -> Data? {
        if let decoded = try? (data as NSData).decompressed(using: .zlib) as Data {
            return decoded
        }
        var wrapped = Data([0x78, 0x9C])
        wrapped.append(data)
        return try? (wrapped as NSData).decompressed(using: .zlib) as Data
    }
}

protocol SaobeiFileImporting {
    func parse(data: Data, fileName: String) throws -> SaobeiParseResult
}

struct SaobeiImporter: SaobeiFileImporting {
    func parse(data: Data, fileName: String) throws -> SaobeiParseResult {
        let lower = fileName.lowercased()
        if lower.hasSuffix(".xlsx") || lower.hasSuffix(".xls") || data.starts(with: [0x50, 0x4b, 0x03, 0x04]) {
            return try SaobeiXLSXParser.parse(data: data, fileName: fileName)
        }
        return try SaobeiCSVParser.parse(data: data, fileName: fileName)
    }
}
