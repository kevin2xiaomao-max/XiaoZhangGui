import Foundation

/// 扫呗截图的本地 OCR 结果转预览行。只负责识别，不写库；确认仍复用导入 commit。
enum SaobeiScreenshotOCR {
    struct Candidate: Equatable {
        let date: Date
        let amount: Double
        let confidence: Double
    }

    static func candidates(from text: String, calendar: Calendar = .current) -> [Candidate] {
        let datePattern = #"(20\d{2})[年./-](\d{1,2})[月./-](\d{1,2})"#
        let amountPattern = #"(?:¥|￥|金额|实收|收款)?\s*([0-9]{1,6}(?:[,，][0-9]{3})*(?:\.\d{1,2})?)\s*(?:元)?"#
        guard let dateRegex = try? NSRegularExpression(pattern: datePattern), let amountRegex = try? NSRegularExpression(pattern: amountPattern) else { return [] }
        let lines = text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).map(String.init)
        return lines.compactMap { line in
            guard let dateMatch = dateRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)), let yearRange = Range(dateMatch.range(at: 1), in: line), let monthRange = Range(dateMatch.range(at: 2), in: line), let dayRange = Range(dateMatch.range(at: 3), in: line), let year = Int(line[yearRange]), let month = Int(line[monthRange]), let day = Int(line[dayRange]) else { return nil }
            let dateEnd = Range(dateMatch.range, in: line)?.upperBound ?? line.startIndex
            let remainder = String(line[dateEnd...])
            guard let amountMatch = amountRegex.firstMatch(in: remainder, range: NSRange(remainder.startIndex..., in: remainder)), let amountRange = Range(amountMatch.range(at: 1), in: remainder) else { return nil }
            let amountText = remainder[amountRange].replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "，", with: "")
            // 截图 OCR 的异常拼接（如 26805）不自动写入，交由预览人工修正。
            guard let amount = Double(amountText), amount > 0, amount <= 10_000, let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
            return Candidate(date: date, amount: amount, confidence: amountText.contains(".") ? 0.95 : 0.75)
        }
    }
}
