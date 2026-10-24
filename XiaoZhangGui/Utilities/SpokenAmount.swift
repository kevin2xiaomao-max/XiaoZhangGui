import Foundation

// MARK: - 口语金额归一（V3.9.2）
//
// 语音与「一句话记账」里大量出现省略单位的说法，直接按位解析会算错：
// - 「六百八」被中文数字按位解析成 608（口语是 680）；「一千二」→ 1002（应为 1200）
// - 「两块五」只剩 2（应为 2.5）；「6块5」被纯数字规则截成 6（应为 6.5）
// - 「六毛五」完全认不出（应为 0.65）
//
// 本文件只做纯文本归一：不触网、不改金额口径（元/角换算之后仍是元）。
// 调用方（AmountPhraseParser）负责 > 0 与业务校验。
enum SpokenAmount {

    /// 「两块五 / 6块5 / 六块半 / 45元」——块或元后面跟半/单个数字时按角补足。
    /// 末尾负向断言排除「45块2箱」这类后面接量词的情况（那 2 是数量，不是角）。
    private static let currencyRegex = try? NSRegularExpression(
        pattern: #"([0-9]+(?:\.[0-9]+)?|[一二两三四五六七八九十百千万零]+)\s*(?:块|元)\s*(半|[0-9]|[一二两三四五六七八九])(?![箱件瓶袋个份包条桶提扎盒罐打套支只杯])"#
    )
    /// 「6块 / 45元」——没有角位时的整数金额。
    private static let integerCurrencyRegex = try? NSRegularExpression(
        pattern: #"([0-9]+(?:\.[0-9]+)?|[一二两三四五六七八九十百千万零]+)\s*(?:块|元)"#
    )
    /// 「六毛五 / 5毛」——毛/角按角位补足。
    private static let jiaoRegex = try? NSRegularExpression(
        pattern: #"([0-9]|[一二两三四五六七八九])\s*(?:毛|角)\s*([0-9]|[一二三四五六七八九])?"#
    )
    /// 省略单位的简写：一位数 + 单位 + 一位尾数（「六百八」= 680，「三千五」= 3500）。
    private static let shorthandRegex = try? NSRegularExpression(
        pattern: #"^([一二两三四五六七八九])([百千万])([一二三四五六七八九])$"#
    )

    /// 从整句里取金额；认不出返回 nil（调用方仍需校验 > 0）。
    static func parse(_ text: String) -> Double? {
        if let value = currencyValue(text), value > 0 { return value }
        if let value = jiaoValue(text), value > 0 { return value }
        return nil
    }

    /// 纯中文数字串归一（含「六百八」式简写）；不吃阿拉伯数字之外的隐式单位。
    static func parseNumerals(_ value: String) -> Double? {
        if let shorthand = shorthandValue(value), shorthand > 0 { return shorthand }
        if let intValue = ChineseNumber.parse(value), intValue > 0 { return Double(intValue) }
        return nil
    }

    // MARK: - 私有

    private static func currencyValue(_ text: String) -> Double? {
        let fullRange = NSRange(text.startIndex..., in: text)
        // 先试「带角」的写法，再退回整数写法。
        if let regex = currencyRegex,
           let match = regex.firstMatch(in: text, range: fullRange),
           let baseRange = Range(match.range(at: 1), in: text),
           let base = numeral(String(text[baseRange])) {
            guard let fractionRange = Range(match.range(at: 2), in: text) else { return base }
            let fraction = String(text[fractionRange])
            if fraction == "半" { return base + 0.5 }
            guard let digit = digitValue(fraction) else { return base }
            return base + Double(digit) / 10
        }
        if let regex = integerCurrencyRegex,
           let match = regex.firstMatch(in: text, range: fullRange),
           let baseRange = Range(match.range(at: 1), in: text),
           let base = numeral(String(text[baseRange])), base > 0 {
            return base
        }
        return nil
    }

    private static func jiaoValue(_ text: String) -> Double? {
        guard let regex = jiaoRegex,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let jiaoRange = Range(match.range(at: 1), in: text),
              let jiao = digitValue(String(text[jiaoRange])) else { return nil }
        var value = Double(jiao) / 10
        if let fenRange = Range(match.range(at: 2), in: text),
           let fen = digitValue(String(text[fenRange])) {
            value += Double(fen) / 100
        }
        return value
    }

    private static func shorthandValue(_ value: String) -> Double? {
        guard let regex = shorthandRegex,
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let firstRange = Range(match.range(at: 1), in: value),
              let unitRange = Range(match.range(at: 2), in: value),
              let lastRange = Range(match.range(at: 3), in: value),
              let first = digitValue(String(value[firstRange])),
              let last = digitValue(String(value[lastRange])) else { return nil }
        let unit: Int
        switch String(value[unitRange]) {
        case "百": unit = 100
        case "千": unit = 1000
        case "万": unit = 10000
        default: return nil
        }
        return Double(first * unit + last * unit / 10)
    }

    private static func numeral(_ token: String) -> Double? {
        if let arabic = Double(token) { return arabic }
        return parseNumerals(token)
    }

    private static func digitValue(_ token: String) -> Int? {
        if let arabic = Int(token) { return arabic }
        return ChineseNumber.parse(token)
    }
}
