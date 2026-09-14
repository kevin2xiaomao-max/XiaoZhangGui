import Foundation
import CryptoKit

enum SaobeiCSVParser {
    static func parse(data: Data, fileName: String) throws -> SaobeiParseResult {
        guard !data.isEmpty else { throw SaobeiImportError.emptyFile }
        guard let text = decodeText(data) else { throw SaobeiImportError.unreadableEncoding }
        return try parse(text: text, fileName: fileName)
    }

    static func parse(text: String, fileName: String) throws -> SaobeiParseResult {
        let lines = splitLines(text)
        guard let headerIndex = lines.firstIndex(where: { looksLikeHeader($0) }) else {
            throw SaobeiImportError.noHeader
        }
        let header = parseCSVLine(lines[headerIndex])
        let dateIdx = firstIndex(in: header, matching: SaobeiColumn.dateKeys)
        let amountIdx = firstIndex(in: header, matching: SaobeiColumn.amountKeys)
        guard let dateIdx, let amountIdx else { throw SaobeiImportError.missingAmountOrDate }
        let statusIdx = firstIndex(in: header, matching: SaobeiColumn.statusKeys)
        let orderIdx = firstIndex(in: header, matching: SaobeiColumn.orderKeys)
        let payIdx = firstIndex(in: header, matching: SaobeiColumn.payKeys)

        var rows: [SaobeiParsedRow] = []
        var errors: [String] = []
        var skipped: [String] = []

        for (offset, line) in lines[(headerIndex + 1)...].enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let cols = parseCSVLine(trimmed)
            let dateText = value(cols, dateIdx)
            let amountText = value(cols, amountIdx)
            guard let date = SaobeiDateParser.parse(dateText),
                  let amount = parseAmount(amountText) else {
                errors.append("第 \(offset + 2) 行无法解析：\(trimmed)")
                continue
            }
            let status = statusIdx.map { value(cols, $0) } ?? ""
            let orderNo = orderIdx.map { value(cols, $0) } ?? ""
            let pay = payIdx.map { value(cols, $0) } ?? ""
            let success = isSuccess(status)
            let fingerprint = SaobeiFingerprint.make(
                orderNo: orderNo,
                date: date,
                amount: amount,
                paymentMethod: pay,
                raw: trimmed
            )
            let row = SaobeiParsedRow(
                date: date,
                amount: amount,
                status: status,
                orderNo: orderNo,
                paymentMethod: pay,
                fingerprint: fingerprint,
                isSuccess: success,
                rawLine: trimmed
            )
            if success {
                rows.append(row)
            } else {
                skipped.append("第 \(offset + 2) 行未计入（\(status.isEmpty ? "非成功状态" : status)）")
            }
        }

        return SaobeiParseResult(rows: rows, skipped: skipped, errors: errors, sourceFileName: fileName)
    }

    static func decodeText(_ data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) { return stripBOM(utf8) }
        if let utf16 = String(data: data, encoding: .utf16) { return utf16 }
        let gbk = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        ))
        if let gb = String(data: data, encoding: gbk) { return gb }
        return String(data: data, encoding: .isoLatin1)
    }

    private static func stripBOM(_ text: String) -> String {
        if text.hasPrefix("\u{feff}") {
            return String(text.dropFirst())
        }
        return text
    }

    private static func splitLines(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    private static func looksLikeHeader(_ line: String) -> Bool {
        SaobeiColumn.dateKeys.contains(where: { line.contains($0) })
            && SaobeiColumn.amountKeys.contains(where: { line.contains($0) })
    }

    private static func firstIndex(in header: [String], matching keys: [String]) -> Int? {
        header.firstIndex { col in
            keys.contains { col.replacingOccurrences(of: " ", with: "").contains($0) }
        }
    }

    private static func value(_ cols: [String], _ index: Int) -> String {
        guard index < cols.count else { return "" }
        return cols[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]
            if ch == "\"" {
                let next = line.index(after: i)
                if inQuotes, next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    i = next
                } else {
                    inQuotes.toggle()
                }
            } else if (ch == "," || ch == "\t" || ch == "，"), !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(ch)
            }
            i = line.index(after: i)
        }
        result.append(current)
        return result
    }

    static func parseAmount(_ raw: String) -> Double? {
        let cleaned = raw
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    static func isSuccess(_ status: String) -> Bool {
        let trimmed = status.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        if SaobeiColumn.failedStatuses.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
            return false
        }
        if SaobeiColumn.successStatuses.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
            return true
        }
        return false
    }
}

enum SaobeiDateParser {
    static func parse(_ raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy/MM/dd HH:mm",
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "yyyyMMddHHmmss",
            "yyyyMMdd",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return ISO8601DateFormatter().date(from: text)
    }
}

enum SaobeiFingerprint {
    static func make(orderNo: String, date: Date, amount: Double, paymentMethod: String, raw: String) -> String {
        let stamp = Int(date.timeIntervalSince1970)
        let cents = Int((amount * 100).rounded())
        let basis: String
        if !orderNo.isEmpty {
            basis = "saobei|\(orderNo)|\(cents)"
        } else {
            basis = "saobei|\(stamp)|\(cents)|\(paymentMethod)|\(raw)"
        }
        let digest = SHA256.hash(data: Data(basis.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
