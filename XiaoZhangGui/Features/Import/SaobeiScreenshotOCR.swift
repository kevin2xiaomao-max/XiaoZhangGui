import Foundation
import UIKit
import Vision

/// 扫呗截图的本地 OCR 结果转预览行。只负责识别，不写库；确认仍复用导入 commit。
enum SaobeiScreenshotOCR {
    struct Candidate: Equatable, Sendable {
        let date: Date
        let amount: Double
        let confidence: Double
        let paymentMethod: String?
        let orderNo: String?
        let sourceKey: String
    }

    static func candidates(from text: String, calendar: Calendar = .current) -> [Candidate] {
        let datePattern = #"(20\d{2})[年./-](\d{1,2})[月./-](\d{1,2})(?:\s+(\d{1,2}):?(\d{2}))?"#
        let amountPattern = #"(?:(¥|￥|金额|实收|收款)\s*)?([0-9]{1,6}(?:[,，][0-9]{3})*(?:\.\d{1,2})?)\s*(?:元)?"#
        guard let dateRegex = try? NSRegularExpression(pattern: datePattern), let amountRegex = try? NSRegularExpression(pattern: amountPattern) else { return [] }
        let lines = text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).map(String.init)
        var dates: [(index: Int, date: Date)] = []
        for (index, line) in lines.enumerated() {
            guard let match = dateRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let year = Int(value(match, group: 1, in: line) ?? ""),
                  let month = Int(value(match, group: 2, in: line) ?? ""),
                  let day = Int(value(match, group: 3, in: line) ?? "") else { continue }
            let hour = Int(value(match, group: 4, in: line) ?? "0") ?? 0
            let minute = Int(value(match, group: 5, in: line) ?? "0") ?? 0
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) {
                dates.append((index, date))
            }
        }

        return lines.enumerated().compactMap { index, line in
            let matches = amountRegex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            guard let match = matches.first(where: { value($0, group: 1, in: line) != nil || value($0, group: 2, in: line)?.contains(".") == true }) ?? matches.last,
                  let raw = value(match, group: 2, in: line) else { return nil }
            let amountText = raw.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "，", with: "")
            let explicitMarker = value(match, group: 1, in: line) != nil || line.contains("元")
            let hasDecimal = amountText.contains(".")
            // 无币种且无小数的超大 OCR 数字仍视为不确定，交由预览人工确认。
            guard let amount = Double(amountText), amount > 0,
                  (explicitMarker || hasDecimal || amount <= 10_000) else { return nil }
            if dates.contains(where: { $0.index == index }) && !explicitMarker && !hasDecimal { return nil }
            guard let associated = dates.min(by: { abs($0.index - index) < abs($1.index - index) }) else { return nil }
            let confidence = explicitMarker ? 0.96 : (hasDecimal ? 0.9 : 0.78)
            let context = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // 行号只用于区分同一截图中的两笔同日同额交易；同一截图再次导入时仍稳定去重。
            let key = "\(associated.date.timeIntervalSince1970)|\(amountText)|\(context)|line-\(index)"
            return Candidate(
                date: associated.date,
                amount: amount,
                confidence: confidence,
                paymentMethod: paymentMethod(in: lines, around: index),
                orderNo: orderNumber(in: line),
                sourceKey: key
            )
        }
    }

    static func recognize(imageData: Data, calendar: Calendar = .current) throws -> [Candidate] {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        return candidates(from: text, calendar: calendar)
    }

    private static func value(_ match: NSTextCheckingResult, group: Int, in text: String) -> String? {
        guard match.range(at: group).location != NSNotFound, let range = Range(match.range(at: group), in: text) else { return nil }
        return String(text[range])
    }

    private static func paymentMethod(in lines: [String], around index: Int) -> String? {
        let window = lines[max(0, index - 1)...min(lines.count - 1, index + 1)].joined(separator: " ")
        return ["微信", "支付宝", "扫呗", "美团", "饿了么", "现金"].first(where: { window.contains($0) })
    }

    private static func orderNumber(in line: String) -> String? {
        guard let range = line.range(of: #"(?:订单号|订单|流水号)\s*[:：#]?\s*([A-Za-z0-9-]{5,})"#, options: .regularExpression) else { return nil }
        let value = String(line[range]).replacingOccurrences(of: #"^(订单号|订单|流水号)\s*[:：#]?\s*"#, with: "", options: .regularExpression)
        return value.isEmpty ? nil : value
    }
}
