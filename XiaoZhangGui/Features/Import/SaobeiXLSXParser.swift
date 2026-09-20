import Foundation
import Compression

// P0-1：真机 XLSX 导入修复。
// 旧实现的 5 个根因：
//   1. NSData.decompressed(zlib) 期望 RFC 1950（含 zlib header + adler32 trailer），
//      但 ZIP method 8 是 RFC 1951 raw DEFLATE（无 header/trailer）。
//   2. MiniZip.extract 只读 Local File Header，不处理 Data Descriptor（bit 3 set 时 compSize=0）。
//   3. parseSheet 正则不支持 inlineStr / self-closing / 多 worksheet / 数字 cell / 日期 cell。
//   4. parseSharedStrings 正则不支持 rich text（同一 si 下多个 t）。
//   5. parseSheet 固定假设 sheet1.xml，没读 workbook.xml + rels 找活动 sheet。
// 本实现：
//   - Apple Compression framework 的 COMPRESSION_ZLIB（实际为 raw DEFLATE，命名误导）。
//   - MiniZip 改从 Central Directory 读取（先找 EOCD，再遍历 CD entries）。
//   - sharedStrings / sheet 用 Foundation XMLParser (SAX) 解析。
//   - workbook.xml + workbook.xml.rels 解析找活动 sheet。
// 不动 SaobeiExporter.swift / SaobeiCSVParser.swift / SaobeiModels.swift。

enum SaobeiXLSXParser {
    static func parse(data: Data, fileName: String) throws -> SaobeiParseResult {
        guard SaobeiFileValidator.kind(for: fileName, data: data) == .xlsx else {
            throw SaobeiImportError.unsupportedExcel("文件不是有效的 XLSX，请重新导出 XLSX 或 CSV")
        }
        // ZIP 魔数（PK\x03\x04）
        guard data.starts(with: [0x50, 0x4b, 0x03, 0x04]) else {
            throw SaobeiImportError.unsupportedExcel("无法识别 Excel 格式，请在扫呗里另存为 CSV")
        }
        // 1. 解压
        let files: [String: Data]
        do {
            files = try MiniZip.extract(data)
        } catch {
            throw SaobeiImportError.unsupportedExcel("Excel 解压失败，请另存为 CSV 后导入")
        }
        // 2. 解析 workbook.xml + rels 找活动 sheet
        guard let workbookData = findFile(in: files, suffix: "xl/workbook.xml") else {
            throw SaobeiImportError.unsupportedExcel("Excel 工作簿结构异常（缺少 workbook.xml）")
        }
        let relsData = findFile(in: files, suffix: "xl/_rels/workbook.xml.rels")
        let sheetTargets = parseWorkbook(workbookData, relsData: relsData)
        // 3. 定位 sheet 数据
        var sheetData: Data?
        if !sheetTargets.isEmpty {
            // 按顺序找第一个存在的 sheet
            for target in sheetTargets {
                if let d = findFile(in: files, suffix: target) {
                    sheetData = d
                    break
                }
            }
        }
        // 回退：直接按文件名匹配
        if sheetData == nil {
            sheetData = files.first(where: { $0.key.lowercased().contains("worksheets/sheet") })?.value
        }
        guard let sheet = sheetData else {
            throw SaobeiImportError.unsupportedExcel("Excel 中没有工作表，请另存为 CSV")
        }
        // 4. sharedStrings（可选）
        let shared = findFile(in: files, suffix: "xl/sharedstrings.xml")
        let strings = shared.flatMap { parseSharedStrings($0) } ?? []
        // 5. 解析 sheet
        let table = parseSheet(sheet, shared: strings)
        guard !table.isEmpty else {
            throw SaobeiImportError.unsupportedExcel("Excel 内容为空，请另存为 CSV")
        }
        // 6. 转 CSV 给 SaobeiCSVParser
        let csv = table.map { row in
            row.map { escapeCSV($0) }.joined(separator: ",")
        }.joined(separator: "\n")
        return try SaobeiCSVParser.parse(text: csv, fileName: fileName)
    }

    // MARK: - workbook.xml + rels 解析

    private static func parseWorkbook(_ data: Data, relsData: Data?) -> [String] {
        var sheets: [(name: String, rId: String)] = []
        let wbParser = WorkbookParser { name, rId in
            sheets.append((name: name, rId: rId))
        }
        _ = try? wbParser.parse(data: data)
        guard !sheets.isEmpty else { return [] }
        var rels: [String: String] = [:]
        if let relsData {
            let relsParser = RelsParser { id, target in
                rels[id] = target
            }
            _ = try? relsParser.parse(data: relsData)
        }
        return sheets.compactMap { s -> String? in
            guard let target = rels[s.rId] else { return nil }
            return normalizeTarget(target)
        }
    }

    /// 把 rels target 归一化为类似 `xl/worksheets/sheet1.xml` 的相对路径。
    private static func normalizeTarget(_ target: String) -> String {
        var s = target
        if s.hasPrefix("/") { s.removeFirst() }
        if !s.lowercased().hasPrefix("xl/") {
            s = "xl/" + s
        }
        return s.lowercased()
    }

    // MARK: - sharedStrings 解析（SAX）

    private static func parseSharedStrings(_ data: Data) -> [String] {
        var result: [String] = []
        let parser = SharedStringsParser { string in
            result.append(string)
        }
        _ = try? parser.parse(data: data)
        return result
    }

    // MARK: - sheet 解析（SAX）

    private static func parseSheet(_ data: Data, shared: [String]) -> [[String]] {
        var rows: [Int: [Int: String]] = [:]
        let parser = SheetParser(shared: shared) { row, col, value in
            rows[row, default: [:]][col] = value
        }
        _ = try? parser.parse(data: data)
        let keys = rows.keys.sorted()
        guard !keys.isEmpty else { return [] }
        let maxCol = rows.values.flatMap { $0.keys }.max() ?? 0
        return keys.map { key in
            (0...maxCol).map { rows[key]?[$0] ?? "" }
        }
    }

    // MARK: - helpers

    private static func findFile(in files: [String: Data], suffix: String) -> Data? {
        let lower = suffix.lowercased()
        for (key, value) in files {
            if key.lowercased().hasSuffix(lower) {
                return value
            }
        }
        return nil
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

// MARK: - SAX: WorkbookParser（解析 workbook.xml 拿 sheets）

private final class WorkbookParser: NSObject, XMLParserDelegate {
    private let onSheet: (String, String) -> Void

    init(onSheet: @escaping (String, String) -> Void) {
        self.onSheet = onSheet
    }

    func parse(data: Data) throws {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            if let err = parser.parserError { throw err }
            return
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        if elementName == "sheet" {
            let name = attributeDict["name"] ?? ""
            let rid = attributeDict["r:id"] ?? attributeDict["id"] ?? ""
            if !rid.isEmpty {
                onSheet(name, rid)
            }
        }
    }
}

// MARK: - SAX: RelsParser（解析 .rels）

private final class RelsParser: NSObject, XMLParserDelegate {
    private let onRel: (String, String) -> Void

    init(onRel: @escaping (String, String) -> Void) {
        self.onRel = onRel
    }

    func parse(data: Data) throws {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            if let err = parser.parserError { throw err }
            return
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        if elementName == "Relationship" {
            let id = attributeDict["Id"] ?? ""
            let target = attributeDict["Target"] ?? ""
            if !id.isEmpty {
                onRel(id, target)
            }
        }
    }
}

// MARK: - SAX: SharedStringsParser（处理 rich text 同 si 下多个 t）

private final class SharedStringsParser: NSObject, XMLParserDelegate {
    private let onString: (String) -> Void
    private var inSi = false
    private var inT = false
    private var current = ""

    init(onString: @escaping (String) -> Void) {
        self.onString = onString
    }

    func parse(data: Data) throws {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            if let err = parser.parserError { throw err }
            return
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "si":
            inSi = true
            current = ""
        case "t":
            if inSi { inT = true }
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inSi && inT {
            current.append(string)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "t":
            inT = false
        case "si":
            if inSi {
                onString(current)
                inSi = false
            }
        default: break
        }
    }
}

// MARK: - SAX: SheetParser（支持 shared / inlineStr / number / self-closing）

private final class SheetParser: NSObject, XMLParserDelegate {
    private let shared: [String]
    private let onCell: (Int, Int, String) -> Void  // row, col, value
    private var inCell = false
    private var inValue = false          // <v>
    private var inInlineStr = false      // <is>
    private var inT = false              // <t> inside <is>
    private var currentCellType: String = ""
    private var currentCellRef: String = ""
    private var currentValue = ""

    init(shared: [String], onCell: @escaping (Int, Int, String) -> Void) {
        self.shared = shared
        self.onCell = onCell
    }

    func parse(data: Data) throws {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            if let err = parser.parserError { throw err }
            return
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "c":
            inCell = true
            currentCellRef = attributeDict["r"] ?? ""
            currentCellType = attributeDict["t"] ?? ""
            currentValue = ""
        case "v":
            if inCell { inValue = true }
        case "is":
            if inCell { inInlineStr = true }
        case "t":
            if inInlineStr { inT = true }
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inCell && (inValue || (inInlineStr && inT)) {
            currentValue.append(string)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "t":
            if inInlineStr { inT = false }
        case "v":
            inValue = false
        case "is":
            inInlineStr = false
        case "c":
            let (col, row) = Self.parseRef(currentCellRef)
            if row > 0 {
                let resolved = resolve(type: currentCellType, value: currentValue)
                if !resolved.isEmpty {
                    onCell(row, col, resolved)
                }
            }
            inCell = false
            currentCellType = ""
            currentCellRef = ""
            currentValue = ""
        default: break
        }
    }

    private func resolve(type: String, value: String) -> String {
        if type == "s", let idx = Int(value), idx >= 0, idx < shared.count {
            return shared[idx]
        }
        if type == "inlineStr" {
            return value
        }
        // 数字 / 日期 / 空 cell：直接返回原值（CSV mapper 自己处理日期格式）
        return value
    }

    private static func parseRef(_ ref: String) -> (col: Int, row: Int) {
        var colLetters = ""
        var rowDigits = ""
        for ch in ref {
            if ch.isLetter {
                colLetters.append(ch)
            } else if ch.isNumber {
                rowDigits.append(ch)
            }
        }
        let col = colLetters.unicodeScalars.reduce(0) { $0 * 26 + Int($1.value - 64) } - 1
        return (max(col, 0), Int(rowDigits) ?? 0)
    }
}

// MARK: - MiniZip（Central Directory + Apple Compression）

enum MiniZip {
    static func extract(_ data: Data) throws -> [String: Data] {
        var result: [String: Data] = [:]
        let bytes = [UInt8](data)
        guard let eocd = findEOCD(bytes) else {
            throw MiniZipError.invalidFormat
        }
        let cdOffset = Int(u32(bytes, eocd + 16))
        let cdCount = Int(u16(bytes, eocd + 10))
        var off = cdOffset
        for _ in 0..<cdCount {
            guard off + 46 <= bytes.count, u32(bytes, off) == 0x02014b50 else { break }
            let method = u16(bytes, off + 10)
            let compSize = Int(u32(bytes, off + 20))
            let uncompSize = Int(u32(bytes, off + 24))
            let nameLen = Int(u16(bytes, off + 28))
            let extraLen = Int(u16(bytes, off + 30))
            let commentLen = Int(u16(bytes, off + 32))
            let localHeaderOffset = Int(u32(bytes, off + 42))
            let nameStart = off + 46
            guard nameStart + nameLen <= bytes.count else { break }
            let name = String(bytes: bytes[nameStart..<(nameStart + nameLen)], encoding: .utf8) ?? "file"
            // 跳到 Local Header 拿实际 payload
            if localHeaderOffset + 30 <= bytes.count, u32(bytes, localHeaderOffset) == 0x04034b50 {
                let localNameLen = Int(u16(bytes, localHeaderOffset + 26))
                let localExtraLen = Int(u16(bytes, localHeaderOffset + 28))
                let dataStart = localHeaderOffset + 30 + localNameLen + localExtraLen
                guard dataStart + compSize <= bytes.count else {
                    off += 46 + nameLen + extraLen + commentLen
                    continue
                }
                let payload = Data(bytes[dataStart..<(dataStart + compSize)])
                if method == 0 {
                    result[name] = payload
                } else if method == 8 {
                    if let inflated = inflate(payload, expected: uncompSize) {
                        result[name] = inflated
                    }
                }
            }
            off += 46 + nameLen + extraLen + commentLen
        }
        return result
    }

    /// 从文件末尾往前找 EOCD（0x06054b50，little-endian 即 0x50 0x4b 0x05 0x06）。
    /// ZIP comment 最长 65535，所以最多往前 22 + 65535。
    private static func findEOCD(_ bytes: [UInt8]) -> Int? {
        let n = bytes.count
        guard n >= 22 else { return nil }
        let minPos = max(0, n - 65557)
        var i = n - 22
        while i >= minPos {
            if bytes[i] == 0x50 && bytes[i + 1] == 0x4b && bytes[i + 2] == 0x05 && bytes[i + 3] == 0x06 {
                return i
            }
            i -= 1
        }
        return nil
    }

    private static func u16(_ b: [UInt8], _ i: Int) -> UInt16 {
        UInt16(b[i]) | UInt16(b[i + 1]) << 8
    }

    private static func u32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) | UInt32(b[i + 1]) << 8 | UInt32(b[i + 2]) << 16 | UInt32(b[i + 3]) << 24
    }

    /// 解 raw DEFLATE（RFC 1951，对应 ZIP method 8）。
    /// Apple 文档中 `COMPRESSION_ZLIB` 实际是 raw DEFLATE（命名误导，并非 RFC 1950 zlib wrapper）。
    private static func inflate(_ data: Data, expected: Int) -> Data? {
        // 优先：Apple Compression
        if let decoded = inflateWithCompression(data: data, expected: expected) {
            return decoded
        }
        // 回退 1：Foundation NSData.decompressed(zlib)（接受 RFC 1950）
        if let decoded = try? (data as NSData).decompressed(using: .zlib) as Data {
            return decoded
        }
        // 回退 2：包装 zlib header（缺 adler32 trailer，真机仍可能失败）
        var wrapped = Data([0x78, 0x9C])
        wrapped.append(data)
        if let decoded = try? (wrapped as NSData).decompressed(using: .zlib) as Data {
            return decoded
        }
        return nil
    }

    /// 用 Apple Compression 解 raw DEFLATE。
    /// `compression_decode_buffer` 如果 dst 容量不足会返回 0，需要扩容重试。
    private static func inflateWithCompression(data: Data, expected: Int) -> Data? {
        var dstCap = max(expected + 1024, 16 * 1024)
        for _ in 0..<5 {
            var dst = [UInt8](repeating: 0, count: dstCap)
            let written = data.withUnsafeBytes { srcPtr -> Int in
                guard let srcBase = srcPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return dst.withUnsafeMutableBufferPointer { dstPtr -> Int in
                    guard let dstBase = dstPtr.baseAddress else { return 0 }
                    return Int(compression_decode_buffer(dstBase, dstCap, srcBase, data.count, nil, COMPRESSION_ZLIB))
                }
            }
            if written > 0 && written < dstCap {
                return Data(dst.prefix(written))
            }
            if written == dstCap {
                // 可能空间不够，扩容重试
                dstCap *= 4
                continue
            }
            // written == 0：解码失败
            return nil
        }
        return nil
    }
}

enum MiniZipError: Error {
    case invalidFormat
}

protocol SaobeiFileImporting {
    func parse(data: Data, fileName: String) throws -> SaobeiParseResult
}

struct SaobeiImporter: SaobeiFileImporting {
    func parse(data: Data, fileName: String) throws -> SaobeiParseResult {
        let lower = fileName.lowercased()
        // P3-5：.xls 是旧二进制格式（≠.xlsx ZIP/XML），不伪装支持
        if lower.hasSuffix(".xls") && !lower.hasSuffix(".xlsx") {
            throw SaobeiImportError.unsupportedExcel("暂不支持旧版 XLS，请另存为 XLSX 或 CSV")
        }
        if lower.hasSuffix(".xlsx") || data.starts(with: [0x50, 0x4b, 0x03, 0x04]) {
            return try SaobeiXLSXParser.parse(data: data, fileName: fileName)
        }
        return try SaobeiCSVParser.parse(data: data, fileName: fileName)
    }
}
