import XCTest
@testable import XiaoZhangGui

final class ToolValidatorExecutorTests: XCTestCase {

    // MARK: 参数校验

    func testValidCallsPass() {
        let cases: [ToolArguments] = [
            .recordRevenue(RevenueArguments(amount: 680, source: "美团", date: .now, note: nil)),
            .createTodo(TodoArguments(title: "下两箱可乐", detail: nil, dueDate: nil, priority: 0)),
            .createMemo(MemoArguments(title: "供应商周五来", content: "记一下供应商周五来")),
            .createDelivery(DeliveryArguments(customer: "302", roomOrAddress: "302", phone: nil,
                                              content: "怡宝 两箱", goodsName: "怡宝", quantity: "两箱",
                                              deliveryTime: nil, deliveryTimeText: "今晚8点", note: nil)),
            .searchRecords(SearchRecordsArguments(query: nil, kinds: [.delivery]))
        ]
        for args in cases {
            let call = AITestFactory.makeToolCall(args)
            XCTAssertTrue(ToolArgumentValidator.validate(call).isEmpty,
                          "\(args.toolName) 应通过校验")
        }
    }

    func testMissingAmountRejected() {
        let call = AITestFactory.makeToolCall(.recordRevenue(
            RevenueArguments(amount: nil, source: "美团", date: .now, note: nil)))
        XCTAssertFalse(ToolArgumentValidator.validate(call).isEmpty)
    }

    func testZeroAmountRejected() {
        let call = AITestFactory.makeToolCall(.recordRevenue(
            RevenueArguments(amount: 0, source: nil, date: nil, note: nil)))
        XCTAssertFalse(ToolArgumentValidator.validate(call).isEmpty)
    }

    func testEmptyTodoTitleRejected() {
        let call = AITestFactory.makeToolCall(.createTodo(
            TodoArguments(title: "  ", detail: nil, dueDate: nil, priority: 0)))
        XCTAssertFalse(ToolArgumentValidator.validate(call).isEmpty)
    }

    func testEmptyMemoRejected() {
        let call = AITestFactory.makeToolCall(.createMemo(
            MemoArguments(title: "", content: "")))
        XCTAssertFalse(ToolArgumentValidator.validate(call).isEmpty)
    }

    func testDeliveryWithoutCustomerOrGoodsRejected() {
        let call = AITestFactory.makeToolCall(.createDelivery(
            DeliveryArguments(customer: nil, roomOrAddress: nil, phone: nil,
                              content: nil, goodsName: nil, quantity: nil,
                              deliveryTime: nil, deliveryTimeText: nil, note: nil)))
        XCTAssertFalse(ToolArgumentValidator.validate(call).isEmpty)
    }

    // MARK: Foundation 预览执行器绝不写库

    func testPreviewExecutorNeverPersists() async {
        let executor = PreviewToolExecutor()
        let call = AITestFactory.makeToolCall(.recordRevenue(
            RevenueArguments(amount: 680, source: "美团", date: .now, note: nil)))
        let result = await executor.execute(call)
        guard case .previewNotPersisted(let returned) = result else {
            return XCTFail("预览执行器必须返回 previewNotPersisted")
        }
        XCTAssertEqual(returned, call)
    }
}
