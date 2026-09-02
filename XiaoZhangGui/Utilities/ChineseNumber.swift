import Foundation

// MARK: - 中文数字解析（语音 NLP 用，语义对齐 Android VoiceViewModel.parseChineseOrArabic）

enum ChineseNumber {
    private static let digits: [Character: Int] = [
        "零": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
        "五": 5, "六": 6, "七": 7, "八": 8, "九": 9,
    ]

    /// 支持阿拉伯数字与"三百二十五"式中文数字
    static func parse(_ value: String) -> Int? {
        if let arabic = Int(value) { return arabic }

        var total = 0
        var section = 0
        var digit = 0

        for ch in value {
            switch ch {
            case "十", "百", "千":
                let unit = ch == "十" ? 10 : (ch == "百" ? 100 : 1000)
                section += (digit == 0 ? 1 : digit) * unit
                digit = 0
            case "万":
                total += (section + digit) * 10000
                section = 0
                digit = 0
            default:
                digit = digits[ch] ?? digit
            }
        }
        return total + section + digit
    }
}
