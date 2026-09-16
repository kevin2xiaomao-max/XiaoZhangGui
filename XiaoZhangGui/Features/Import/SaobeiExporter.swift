import Foundation

// MARK: - 扫呗导出（CSV + 真 XLSX）
// P3-3：真正实现合法 .xlsx（Office Open XML Workbook），
// 禁止 CSV 改扩展名冒充 XLSX；生成文件可被 Excel/Numbers 打开。

enum SaobeiExporter {
    /// CSV 导出（保留原有格式，兼容扫呗回环导入）
    static func exportCSV(rows: [SaobeiParsedRow]) -> Data {
        let header = ["交易时间", "交易状态", "订单号", "支付方式", "收款金额"]
            .joined(separator: ",")
        let lines = rows.map { row -> String in
            let cols = [
                format(row.date),
                row.status,
                row.orderNo,
                row.paymentMethod,
                String(format: "%.2f", row.amount)
            ]
            return cols.map { escapeCSV($0) }.joined(separator: ",")
        }
        let csv = ([header] + lines).joined(separator: "\n")
        return Data(csv.utf8)
    }

    /// XLSX 导出（Office Open XML Workbook，Store 无压缩 ZIP 打包）
    static func exportXLSX(rows: [SaobeiParsedRow]) throws -> Data {
        let writer = XLSXWriter()
        writer.addRow(["交易时间", "交易状态", "订单号", "支付方式", "收款金额"])
        for row in rows {
            writer.addRow([
                format(row.date),
                row.status,
                row.orderNo,
                row.paymentMethod,
                String(format: "%.2f", row.amount)
            ])
        }
        return try writer.build()
    }

    private static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

// MARK: - 最小 Office Open XML Workbook Writer

private final class XLSXWriter {
    private var rows: [[String]] = []
    private var sharedStrings: [String: Int] = [:]
    private var sharedStringsOrdered: [String] = []

    func addRow(_ values: [String]) {
        rows.append(values)
    }

    func build() throws -> Data {
        // 1. 收集所有字符串到 sharedStrings
        for row in rows {
            for cell in row {
                if sharedStrings[cell] == nil {
                    sharedStrings[cell] = sharedStringsOrdered.count
                    sharedStringsOrdered.append(cell)
                }
            }
        }

        // 2. 生成各 XML 部件
        let contentTypes = makeContentTypes()
        let rootRels = makeRootRels()
        let workbook = makeWorkbook()
        let workbookRels = makeWorkbookRels()
        let sheet = makeSheet()
        let shared = makeSharedStrings()

        // 3. ZIP 打包（Store method，无压缩）
        var zip = ZipWriter()
        zip.add(name: "[Content_Types].xml", data: Data(contentTypes.utf8))
        zip.add(name: "_rels/.rels", data: Data(rootRels.utf8))
        zip.add(name: "xl/workbook.xml", data: Data(workbook.utf8))
        zip.add(name: "xl/_rels/workbook.xml.rels", data: Data(workbookRels.utf8))
        zip.add(name: "xl/worksheets/sheet1.xml", data: Data(sheet.utf8))
        zip.add(name: "xl/sharedStrings.xml", data: Data(shared.utf8))
        return zip.build()
    }

    private func makeContentTypes() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
        </Types>
        """
    }

    private func makeRootRels() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
    }

    private func makeWorkbook() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
        <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
        </sheets>
        </workbook>
        """
    }

    private func makeWorkbookRels() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
        </Relationships>
        """
    }

    private func makeSheet() -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">\n"
        xml += "<sheetData>\n"
        for (rowIdx, row) in rows.enumerated() {
            let rowNum = rowIdx + 1
            xml += "<row r=\"\(rowNum)\">"
            for (colIdx, value) in row.enumerated() {
                let colLetter = Self.columnLetter(colIdx)
                let cellRef = "\(colLetter)\(rowNum)"
                let idx = sharedStrings[value] ?? 0
                xml += "<c r=\"\(cellRef)\" t=\"s\"><v>\(idx)</v></c>"
            }
            xml += "</row>\n"
        }
        xml += "</sheetData>\n</worksheet>"
        return xml
    }

    private func makeSharedStrings() -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        let count = sharedStringsOrdered.count
        xml += "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"\(count)\" uniqueCount=\"\(count)\">\n"
        for str in sharedStringsOrdered {
            xml += "<si><t xml:space=\"preserve\">\(escapeXML(str))</t></si>\n"
        }
        xml += "</sst>"
        return xml
    }

    /// Excel 列字母（0-indexed）：0→A, 25→Z, 26→AA, 27→AB
    static func columnLetter(_ index: Int) -> String {
        var result = ""
        var n = index
        while n >= 0 {
            let mod = n % 26
            result = String(UnicodeScalar(65 + mod)!) + result
            n = n / 26 - 1
        }
        return result
    }

    private func escapeXML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - 最小 ZIP Writer（Store method，无压缩）
// 生成合法 ZIP 包；Excel/Numbers 可正常打开。

private struct ZipWriter {
    private var entries: [(name: String, data: Data)] = []

    mutating func add(name: String, data: Data) {
        entries.append((name, data))
    }

    func build() -> Data {
        var output = Data()
        var centralDir = Data()
        var offset: UInt32 = 0

        for entry in entries {
            let nameBytes = Array(entry.name.utf8)
            let crc = Self.crc32(entry.data)
            let size = UInt32(entry.data.count)
            let nameLen = UInt16(nameBytes.count)

            // Local File Header
            var local = Data()
            local.appendUInt32(0x04034b50)
            local.appendUInt16(20)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt32(crc)
            local.appendUInt32(size)
            local.appendUInt32(size)
            local.appendUInt16(nameLen)
            local.appendUInt16(0)
            local.append(contentsOf: nameBytes)
            output.append(local)
            output.append(entry.data)

            // Central Directory Entry
            var central = Data()
            central.appendUInt32(0x02014b50)
            central.appendUInt16(20)
            central.appendUInt16(20)
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt32(crc)
            central.appendUInt32(size)
            central.appendUInt32(size)
            central.appendUInt16(nameLen)
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt32(0)
            central.appendUInt32(offset)
            central.append(contentsOf: nameBytes)
            centralDir.append(central)

            offset += UInt32(local.count + entry.data.count)
        }

        output.append(centralDir)

        // End of Central Directory Record
        var end = Data()
        end.appendUInt32(0x06054b50)
        end.appendUInt16(0)
        end.appendUInt16(0)
        end.appendUInt16(UInt16(entries.count))
        end.appendUInt16(UInt16(entries.count))
        end.appendUInt32(UInt32(centralDir.count))
        end.appendUInt32(offset)
        end.appendUInt16(0)
        output.append(end)

        return output
    }

    /// 标准 CRC32（与 zlib/PKZIP 一致）
    static func crc32(_ data: Data) -> UInt32 {
        let table: [UInt32] = {
            (0..<256).map { i -> UInt32 in
                var c = UInt32(i)
                for _ in 0..<8 {
                    c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
                }
                return c
            }
        }()
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let idx = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ table[idx]
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendUInt32(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}
