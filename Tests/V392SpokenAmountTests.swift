import XCTest
@testable import XiaoZhangGui

/// V3.9.2 · 口语金额归一
///
/// 锁住三类此前真实算错的说法（语音与一句话记账都会走到 `AmountPhraseParser`）：
/// 1. 省略单位的简写：「六百八」按位解析成 608（应为 680）、「一千二」→ 1002（应为 1200）；
/// 2. 带角的金额：「两块五」只剩 2、「6块5」被纯数字规则截成 6（应为 2.5 / 6.5）；
/// 3. 只有角没有元：「六毛五」直接认不出（应为 0.65）。
final class V392SpokenAmountTests: XCTestCase {

    private func assertAmount(
        _ text: String,
        _ expected: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let value = AmountPhraseParser.parse(text) else {
            return XCTFail("「\(text)」没解析出金额，期望 \(expected)", file: file, line: line)
        }
        XCTAssertEqual(value, expected, accuracy: 0.001, "「\(text)」", file: file, line: line)
    }

    func testShorthandWithoutUnit() {
        assertAmount("六百八", 680)
        assertAmount("一千二", 1200)
        assertAmount("三百五", 350)
        assertAmount("两百五", 250)
        assertAmount("两千五", 2500)
        assertAmount("一万二", 12000)
        assertAmount("毛利六百八", 680)
    }

    func testCurrencyWithFraction() {
        assertAmount("两块五", 2.5)
        assertAmount("6块5", 6.5)
        assertAmount("六块半", 6.5)
        assertAmount("12.5元", 12.5)
        assertAmount("3块5一斤", 3.5)
    }

    func testCurrencyIntegers() {
        assertAmount("两块", 2)
        assertAmount("45元", 45)
        assertAmount("一共45元", 45)
        assertAmount("100块", 100)
        assertAmount("今天美团680", 680)
    }

    func testJiaoOnly() {
        assertAmount("六毛五", 0.65)
        assertAmount("5毛", 0.5)
    }

    func testPlainChineseNumerals() {
        assertAmount("三百二十五元", 325)
        assertAmount("三百二十五", 325)
        assertAmount("六百八十", 680)
        assertAmount("一千零五十", 1050)
    }

    /// 末尾量词不是角位：「45块2箱」是 45 元 + 2 箱，不能读成 45.2。
    func testQuantityAfterCurrencyIsNotFraction() {
        assertAmount("45块2箱", 45)
    }

    func testParseNumeralsDirectly() {
        XCTAssertEqual(SpokenAmount.parseNumerals("六百八") ?? 0, 680, accuracy: 0.001)
        XCTAssertEqual(SpokenAmount.parseNumerals("一万二") ?? 0, 12000, accuracy: 0.001)
        XCTAssertEqual(SpokenAmount.parseNumerals("三百二十五") ?? 0, 325, accuracy: 0.001)
        XCTAssertNil(SpokenAmount.parseNumerals("abc"))
    }

    func testSentenceWithoutAmountReturnsNil() {
        XCTAssertNil(AmountPhraseParser.parse("今天客人不多"))
    }

    /// 源码审计：语音装口令（LocalBusinessParser）与一句话记账必须共用同一套金额解析。
    func testCallSitesRouteThroughAmountPhraseParser() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        func source(_ relative: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        }

        let quick = try source("XiaoZhangGui/Features/QuickRecord/QuickRecordParser.swift")
        XCTAssertTrue(quick.contains("SpokenAmount.parse(text)"), "口语归一必须先于纯数字规则")
        XCTAssertTrue(quick.contains("SpokenAmount.parseNumerals("), "中文串分支要复用简写归一")

        let assistant = try source("XiaoZhangGui/Features/Assistant/AI/Providers/LocalBusinessParser.swift")
        XCTAssertTrue(assistant.contains("AmountPhraseParser.parse("), "语音记账必须复用同一套金额解析")
    }
}
