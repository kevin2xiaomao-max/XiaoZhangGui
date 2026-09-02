import Foundation

// MARK: - 语音状态机（02 文档：Idle/Listening/Recognized/Parsing/Preview/Saving/Error/TextFallback）

enum VoicePhase: Equatable {
    case idle
    case listening
    case recognized
    case parsing
    case preview
    case saving
    case error(String)
    case textFallback

    var statusText: String {
        switch self {
        case .idle: return "点击麦克风开始"
        case .listening: return "正在聆听"
        case .recognized: return "正在识别…"
        case .parsing: return "正在解析…"
        case .preview: return "确认一下"
        case .saving: return "正在保存…"
        case .error(let message): return message
        case .textFallback: return "手动输入内容"
        }
    }
}

// MARK: - 记录类型（语义对齐 Android VoiceRecordType）

enum VoiceRecordType: String, CaseIterable, Identifiable {
    case todo = "待办"
    case revenue = "营业记录"
    case expense = "支出"
    case memo = "记录"
    case expiry = "临期退货"

    var id: String { rawValue }
}

// MARK: - 语音草稿（语义对齐 Android VoiceDraft）

struct VoiceDraft {
    var type: VoiceRecordType
    var title: String
    var detail: String
    var amount: Double?
    var dueAt: Date?
    var expiryDays: Int?
    var original: String
}

// MARK: - 解析器（语义对齐 Android VoiceViewModel.parse）

enum VoiceParser {
    /// 明显是查询而非记录指令的句子，不应默认生成待办。
    static func isUnsupportedQuery(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let asksWeather = value.contains("天气")
        let hasRecordIntent = value.contains("提醒")
            || value.contains("待办")
            || value.contains("记一下")
            || value.contains("营业额")
            || value.contains("收入")
            || value.contains("支出")
            || value.contains("进货")
            || value.contains("过期")
            || value.contains("临期")
        return asksWeather && !hasRecordIntent
    }

    static func parse(_ rawText: String) -> VoiceDraft {
        let value = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = detectType(value)
        let amount = parseAmount(value)
        let due = parseDueTime(value)
        let days: Int?
        if let match = value.firstMatch(of: /还有([\d一二两三四五六七八九十百千]+)天/) {
            days = ChineseNumber.parse(String(match.1))
        } else {
            days = nil
        }

        let cleaned = value
            .replacing(/^(记一下|提醒我|今天|明天|上午|下午|三点|十点)+/, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let title: String
        let detail: String
        switch type {
        case .revenue:
            title = "记录营业收入"
            detail = amount.map { "¥\(String(format: "%.2f", $0))" } ?? "请补充金额"
        case .expense:
            title = "记录进货支出"
            detail = amount.map { "¥\(String(format: "%.2f", $0))" } ?? "请补充金额"
        case .expiry:
            let before = value.split(separator: "还", maxSplits: 1).first.map(String.init) ?? value
            let name = before.split(separator: "过", maxSplits: 1).first.map(String.init) ?? before
            title = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "临期商品" : name
            detail = days.map { "还有 \($0) 天过期" } ?? value
        case .memo:
            title = "语音记录"
            detail = value
        case .todo:
            title = cleaned.isEmpty ? value : cleaned
            detail = due.map { Fmt.monthDayTime($0) } ?? value
        }

        return VoiceDraft(
            type: type,
            title: title,
            detail: detail,
            amount: amount,
            dueAt: due,
            expiryDays: days,
            original: value
        )
    }

    private static func detectType(_ value: String) -> VoiceRecordType {
        if value.contains("进货") || value.contains("支出") || value.contains("花了") { return .expense }
        if value.contains("营业额") || value.contains("收入") { return .revenue }
        if value.contains("过期") || value.contains("临期") { return .expiry }
        if value.contains("记一下") || value.contains("备忘") || value.contains("客人") { return .memo }
        return .todo
    }

    /// 金额：优先阿拉伯数字，其次中文数字
    static func parseAmount(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: ",", with: "")
        if let match = cleaned.firstMatch(of: /(\d+(?:\.\d+)?)/) {
            return Double(match.1)
        }
        if let match = cleaned.firstMatch(of: /[零一二两三四五六七八九十百千万]+/) {
            if let number = ChineseNumber.parse(String(match.0)) {
                return Double(number)
            }
        }
        return nil
    }

    /// 截止时间：今天/明天 + 简单时间词（语义对齐 Android）
    static func parseDueTime(_ text: String) -> Date? {
        guard text.contains("今天") || text.contains("明天") else { return nil }
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: text.contains("明天") ? 1 : 0, to: Date()) ?? Date()
        let hour: Int?
        if text.contains("下午三点") {
            hour = 15
        } else if text.contains("十点") {
            hour = 10
        } else if let match = text.firstMatch(of: /([0-9]{1,2})点/) {
            hour = Int(match.1)
        } else if text.contains("提醒我") || text.contains("待办") {
            hour = 9
        } else {
            hour = nil
        }
        guard let hour, (0...23).contains(hour) else { return nil }
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)
    }
}
