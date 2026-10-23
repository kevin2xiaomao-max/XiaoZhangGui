import XCTest
@testable import XiaoZhangGui

/// V3.8 P0-A1：收入来源归因回归测试。
///
/// 修复前：QuickRecord / 语音保存营业额未传 incomeSource，一律落默认「门店」；
/// 语音备注统一写「语音记录」，原始语句丢失。
/// 修复后：按用户原话走既有 `IncomeSource.from(note:)` 派生
/// （美团→美团；门店/到店→门店；其余→其他），微信/支付宝等支付方式不会误判为美团。
final class QuickRecordIncomeAttributionTests: XCTestCase {

    private let parser = LocalQuickRecordParser()

    // MARK: - 快捷记录：原话 → 类型 + 来源

    func testMeituanSentenceAttributedToMeituan() {
        let draft = parser.parse("今天美团680")
        XCTAssertEqual(draft.kind, .performance, "「今天美团680」应识别为营业额")
        XCTAssertEqual(IncomeSource.from(note: draft.note), .meituan, "美团收入不得再落「门店」")
    }

    func testWeChatPaymentNotConflatedWithMeituan() {
        let draft = parser.parse("微信收款300")
        XCTAssertEqual(draft.kind, .performance)
        XCTAssertEqual(
            IncomeSource.from(note: draft.note), .other,
            "微信是支付方式不是收入渠道，不得判为美团"
        )
    }

    func testUnspecifiedSourceFallsToOtherNotStore() {
        let draft = parser.parse("今天卖了200")
        XCTAssertEqual(draft.kind, .performance)
        XCTAssertEqual(
            IncomeSource.from(note: draft.note), .other,
            "未明确来源按既有规则落「其他」，不强制推断为门店"
        )
    }

    func testInStoreRevenueAttributedToStore() {
        let draft = parser.parse("到店卖了150")
        XCTAssertEqual(draft.kind, .performance)
        XCTAssertEqual(IncomeSource.from(note: draft.note), .store)
    }

    // MARK: - 语音：原句保留 + 来源派生

    func testVoiceRevenueKeepsOriginalSentenceAndDerivesSource() {
        let draft = VoiceParser.parse("美团卖了680")
        XCTAssertEqual(draft.type, .revenue, "「美团卖了680」应识别为营业记录")
        XCTAssertEqual(draft.original, "美团卖了680", "语音草稿必须保留原句")
        XCTAssertEqual(IncomeSource.from(note: draft.original), .meituan)
    }

    // MARK: - 源码契约：保存链路不得回退为默认门店 / 「语音记录」

    func testQuickRecordSavePassesDerivedIncomeSource() throws {
        let source = try source("XiaoZhangGui/Features/QuickRecord/QuickRecordSheet.swift")
        XCTAssertTrue(
            source.contains("incomeSource: IncomeSource.from(note: draft.note)"),
            "QuickRecord 保存营业额必须按原话派生 incomeSource（P0-A1 回归钉）"
        )
    }

    func testVoiceSaveKeepsOriginalTextAndDerivesIncomeSource() throws {
        let source = try source("XiaoZhangGui/Features/Voice/VoiceViewModel.swift")
        XCTAssertFalse(
            source.contains(#"note: "语音记录""#),
            "语音保存不得再统一写「语音记录」备注（P0-A1 回归钉）"
        )
        XCTAssertTrue(
            source.contains("incomeSource: IncomeSource.from(note: draft.original)"),
            "语音保存营业额必须按原句派生 incomeSource（P0-A1 回归钉）"
        )
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
