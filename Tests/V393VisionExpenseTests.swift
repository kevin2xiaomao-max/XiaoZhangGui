import XCTest
import SwiftData
@testable import XiaoZhangGui

// MARK: - V3.9.3 B · 拍照智能记账：支出草稿、多金额拦截、支出写入与幂等。

@MainActor
final class V393VisionExpenseTests: XCTestCase {
    private var retainedContainers: [ModelContainer] = []

    override func tearDown() {
        retainedContainers.removeAll()
        super.tearDown()
    }

    private func makeHarness() throws -> (ModelContext, InMemoryExecutionJournal, RepositoryToolExecutor) {
        let container = try AppDatabase.makeInMemoryContainer()
        retainedContainers.append(container)
        let context = container.mainContext
        let journal = InMemoryExecutionJournal()
        return (context, journal, RepositoryToolExecutor(context: context, journal: journal))
    }

    private func count<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<T>()).count
    }

    // MARK: 多金额与总计

    func testMultiAmountWithoutTotalIsBlockedNotSummed() {
        let assessment = VisionDraftParser.assess(from: "收据：怡宝 800 元，可乐 40 元")
        XCTAssertNil(assessment.draft, "多金额无总计标记时绝不能出卡")
        XCTAssertEqual(assessment.confidence, .low)
        XCTAssertEqual(assessment.ambiguousAmounts, [40, 800], "必须返回全部候选金额供用户选择")
        XCTAssertEqual(assessment.reason, "multiAmount")
    }

    func testTotalMarkerWinsOverUnitPrices() throws {
        let call = try XCTUnwrap(VisionDraftParser.draftToolCall(from: "进货单：一共 840 元，其中怡宝 800 元，可乐 40 元"))
        XCTAssertEqual(call.name, .recordExpense)
        guard case .recordExpense(let arguments) = call.arguments else {
            return XCTFail("参数类型应为 recordExpense")
        }
        XCTAssertEqual(arguments.amount ?? 0, 840, accuracy: 0.001, "有总计时以总计为准，严禁单价相加")
    }

    func testExpenseWithoutAmountDraftsNothing() {
        XCTAssertNil(VisionDraftParser.draftToolCall(from: "进货单一张"))
        XCTAssertEqual(VisionDraftParser.assess(from: "进货单一张").reason, "unparsed")
    }

    func testRoomAndTimeNumbersAreNotAmounts() {
        // 房号 302、时间 8 点不带元/块单位，绝不能被当成金额。
        XCTAssertEqual(VisionDraftParser.arabicAmounts(in: "302 房 8 点送货"), [])
    }

    // MARK: 工具注册 / 校验 / 指纹

    func testRecordExpenseIsRegisteredAndValidated() {
        XCTAssertTrue(ToolCatalog.isRegistered(.recordExpense))
        XCTAssertTrue(ToolCatalog.liteTools.contains(.recordExpense))
        let valid = ToolCall(id: ToolCall.makeID(), name: .recordExpense,
                             arguments: .recordExpense(ExpenseArguments(amount: 320, category: "进货", date: nil, note: nil)))
        XCTAssertTrue(ToolArgumentValidator.validate(valid).isEmpty)
        let invalid = ToolCall(id: ToolCall.makeID(), name: .recordExpense,
                               arguments: .recordExpense(ExpenseArguments(amount: 0, category: "进货", date: nil, note: nil)))
        XCTAssertFalse(ToolArgumentValidator.validate(invalid).isEmpty)
        // 支出指纹与收入指纹前缀不同，同一金额不会互相判重。
        let revenue = ToolCall(id: ToolCall.makeID(), name: .recordRevenue,
                               arguments: .recordRevenue(RevenueArguments(amount: 320, source: nil, date: nil, note: nil)))
        XCTAssertNotEqual(ToolIdempotency.fingerprint(for: valid), ToolIdempotency.fingerprint(for: revenue))
        XCTAssertTrue(ToolIdempotency.fingerprint(for: valid).hasPrefix("exp|"))
    }

    // MARK: 支出真实写入与幂等（只走既有 RepositoryToolExecutor）

    func testRecordExpenseWritesExpenseTableNotPerformance() async throws {
        let (context, _, executor) = try makeHarness()
        let call = ToolCall(id: ToolCall.makeID(), name: .recordExpense,
                            arguments: .recordExpense(ExpenseArguments(amount: 320, category: "进货", date: Date(), note: "怡宝")))
        let result = await executor.execute(call)
        guard case .executed = result else { return XCTFail("支出应执行成功：\(result)") }
        XCTAssertEqual(try count(Expense.self, in: context), 1)
        XCTAssertEqual(try count(Performance.self, in: context), 0, "支出绝不能写进营业额表")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Expense>()).first?.category, "进货")
    }

    func testRecordExpenseRepeatConfirmIsDuplicateNotDoubleWrite() async throws {
        let (context, _, executor) = try makeHarness()
        let call = ToolCall(id: ToolCall.makeID(), name: .recordExpense,
                            arguments: .recordExpense(ExpenseArguments(amount: 320, category: "进货", date: Date(), note: nil)))
        guard case .executed = await executor.execute(call) else { return XCTFail("首次应成功") }
        // 同一调用重确认 + 同业务内容新调用，均只算幂等折叠。
        let again = await executor.execute(call)
        guard case .duplicate = again else { return XCTFail("同一调用重确认应为 duplicate：\(again)") }
        let sameBusiness = ToolCall(id: ToolCall.makeID(), name: .recordExpense,
                                    arguments: .recordExpense(ExpenseArguments(amount: 320, category: "进货", date: call.argumentsDate, note: nil)))
        guard case .duplicate = await executor.execute(sameBusiness) else {
            return XCTFail("同业务指纹应为 duplicate")
        }
        XCTAssertEqual(try count(Expense.self, in: context), 1, "重复确认绝不能重复入账")
    }

    // MARK: 修正（B 补丁：新增工具 case 必须补穷尽 switch，否则构建失败）

    func testExpenseAmountCorrectionMirrorsRevenue() {
        let current = ToolArguments.recordExpense(
            ExpenseArguments(amount: 320, category: "进货", date: nil, note: nil))
        guard case .update(let updated, let text) =
                PendingFieldCorrectionParser.parse("不是320，是380", current: current) else {
            return XCTFail("支出卡金额修正应返回 update")
        }
        guard case .recordExpense(let value) = updated else { return XCTFail("修正后仍应为支出类型") }
        XCTAssertEqual(value.amount, 380)
        XCTAssertEqual(value.category, "进货", "修正金额不得丢类别")
        XCTAssertTrue(text.contains("380"), "修正回执必须含新金额")
    }
}

private extension ToolCall {
    /// 测试用：取 recordExpense 参数的 date（与首次调用同日，用于指纹判重）。
    var argumentsDate: Date? {
        guard case .recordExpense(let arguments) = arguments else { return nil }
        return arguments.date
    }
}
