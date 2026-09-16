import XCTest
@testable import XiaoZhangGui

final class ToolIdempotencyTests: XCTestCase {
    private let day = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 17))!

    func testCallIDFormatAndUniqueness() {
        let a = ToolIdempotency.newCallID()
        let b = ToolIdempotency.newCallID()
        XCTAssertTrue(a.hasPrefix("call_"))
        XCTAssertNotEqual(a, b)
    }

    func testRevenueFingerprintStableAndSensitiveToBusinessKey() {
        let call1 = AITestFactory.makeToolCall(.recordRevenue(
            RevenueArguments(amount: 680, source: "美团", date: day, note: nil)))
        let call2 = AITestFactory.makeToolCall(.recordRevenue(
            RevenueArguments(amount: 680, source: "美团", date: day, note: nil)))
        let differentAmount = AITestFactory.makeToolCall(.recordRevenue(
            RevenueArguments(amount: 68, source: "美团", date: day, note: nil)))
        let differentDay = AITestFactory.makeToolCall(.recordRevenue(
            RevenueArguments(amount: 680, source: "美团",
                             date: Calendar.current.date(byAdding: .day, value: 1, to: day), note: nil)))

        XCTAssertEqual(ToolIdempotency.fingerprint(for: call1),
                       ToolIdempotency.fingerprint(for: call2))
        XCTAssertNotEqual(ToolIdempotency.fingerprint(for: call1),
                          ToolIdempotency.fingerprint(for: differentAmount))
        XCTAssertNotEqual(ToolIdempotency.fingerprint(for: call1),
                          ToolIdempotency.fingerprint(for: differentDay))
    }

    func testDeliveryFingerprintIncludesCustomerTimeAndGoods() {
        let time = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 20))!
        let a = AITestFactory.makeToolCall(.createDelivery(
            DeliveryArguments(customer: "302", roomOrAddress: "302", phone: nil,
                              content: "怡宝 两箱", goodsName: "怡宝", quantity: "两箱",
                              deliveryTime: time, deliveryTimeText: "今晚8点", note: nil)))
        let b = AITestFactory.makeToolCall(.createDelivery(
            DeliveryArguments(customer: "302", roomOrAddress: "302", phone: nil,
                              content: "怡宝 两箱", goodsName: "怡宝", quantity: "两箱",
                              deliveryTime: time, deliveryTimeText: "今晚8点", note: nil)))
        let otherRoom = AITestFactory.makeToolCall(.createDelivery(
            DeliveryArguments(customer: "501", roomOrAddress: "501", phone: nil,
                              content: "怡宝 两箱", goodsName: "怡宝", quantity: "两箱",
                              deliveryTime: time, deliveryTimeText: "今晚8点", note: nil)))
        XCTAssertEqual(ToolIdempotency.fingerprint(for: a), ToolIdempotency.fingerprint(for: b))
        XCTAssertNotEqual(ToolIdempotency.fingerprint(for: a),
                          ToolIdempotency.fingerprint(for: otherRoom))
    }

    func testTodoAndMemoFingerprints() {
        let todo = AITestFactory.makeToolCall(.createTodo(
            TodoArguments(title: "下两箱可乐", detail: nil, dueDate: day, priority: 0)))
        let memo = AITestFactory.makeToolCall(.createMemo(
            MemoArguments(title: "供应商周五来", content: "记一下供应商周五来")))
        XCTAssertTrue(ToolIdempotency.fingerprint(for: todo).hasPrefix("todo|"))
        XCTAssertTrue(ToolIdempotency.fingerprint(for: memo).hasPrefix("memo|"))
    }
}
