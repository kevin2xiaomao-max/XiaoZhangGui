import XCTest
@testable import XiaoZhangGui

final class ContextRedactorTests: XCTestCase {
    private let redactor = ContextRedactor()

    func testWorldChatCarriesZeroBusinessData() {
        XCTAssertNil(redactor.sanitizeForWorldChat().json)
        XCTAssertNil(redactor.sanitize(.empty).json)
    }

    func testPhoneNumberIsMaskedBeforeLeavingDevice() throws {
        let context = ScopedBusinessContext(
            revenueTodayTotal: nil, revenueTodayCount: nil,
            todoTodayTitles: ["给13800138000客户送水"],
            recentMemoTitles: nil, deliveryPendingCount: nil, deliveryDeliveringCount: nil)
        let payload = redactor.sanitize(context)
        let json = try XCTUnwrap(payload.json)
        let text = String(data: json, encoding: .utf8) ?? ""
        XCTAssertFalse(text.contains("13800138000"), "完整手机号禁止进入 Provider payload")
        XCTAssertTrue(text.contains("1**********"))
    }

    func testRoomNumberIsMasked() throws {
        let context = ScopedBusinessContext(
            revenueTodayTotal: nil, revenueTodayCount: nil,
            todoTodayTitles: ["302室要水"], recentMemoTitles: nil,
            deliveryPendingCount: nil, deliveryDeliveringCount: nil)
        let text = String(data: try XCTUnwrap(redactor.sanitize(context).json), encoding: .utf8) ?? ""
        XCTAssertFalse(text.contains("302室"))
        XCTAssertTrue(text.contains("#室"))
    }

    func testCountsAndTotalsPassThrough() throws {
        let context = ScopedBusinessContext(
            revenueTodayTotal: 680.5, revenueTodayCount: 3,
            todoTodayTitles: nil, recentMemoTitles: nil,
            deliveryPendingCount: 2, deliveryDeliveringCount: 1)
        let text = String(data: try XCTUnwrap(redactor.sanitize(context).json), encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("680.5"))
        XCTAssertTrue(text.contains("\"deliveryPendingCount\":2"))
    }

    func testTitleListIsCappedToThreeAndTruncated() {
        let longTitle = String(repeating: "很长的待办标题", count: 10)
        let context = ScopedBusinessContext(
            revenueTodayTotal: nil, revenueTodayCount: nil,
            todoTodayTitles: ["一", "二", "三", "四", longTitle],
            recentMemoTitles: nil, deliveryPendingCount: nil, deliveryDeliveringCount: nil)
        let payload = redactor.sanitize(context)
        guard let data = payload.json,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let titles = object["todoTodayTitles"] as? [String] else {
            return XCTFail("应产出待办标题数组")
        }
        XCTAssertEqual(titles.count, 3)
        XCTAssertLessThanOrEqual(titles.last?.count ?? 0, 21) // 20 字 + 省略号
    }

    func testMaskSensitiveTextHelper() {
        XCTAssertTrue(ContextRedactor.maskSensitiveText("电话13912345678").contains("1**********"))
        XCTAssertFalse(ContextRedactor.maskSensitiveText("电话13912345678").contains("13912345678"))
    }
}
