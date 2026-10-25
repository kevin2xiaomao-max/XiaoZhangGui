import XCTest
import SwiftData
@testable import XiaoZhangGui

// MARK: - V3.9.3 C · 复合意图与配送闭环：拆分、金额合并、推进工具、
// 一键确认（顺序执行、单项失败隔离、重确认幂等）。

final class V393CompositeIntentTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private var wednesdayEvening: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 28
        components.hour = 20
        return calendar.date(from: components)!
    }

    // MARK: 拆分

    func testCompositeSplitsRevenueAndDelivery() {
        let result = CompositeIntentParser.parse("记一笔美团680，再给302送两箱怡宝", now: wednesdayEvening)
        XCTAssertEqual(result.calls.count, 2, "应拆成营业额 + 配送两张卡")
        XCTAssertEqual(result.calls[0].name, .recordRevenue)
        XCTAssertEqual(result.calls[1].name, .createDelivery)
        guard case .createDelivery(let delivery) = result.calls[1].arguments else {
            return XCTFail("第二张应为配送卡")
        }
        XCTAssertTrue((delivery.roomOrAddress ?? "").contains("302"), "房号 302 必须进配送卡，不能被金额混淆")
    }

    func testAmountOnlySegmentMergesIntoPreviousCardNotSummed() {
        let result = CompositeIntentParser.parse("给302送两箱怡宝，一共45元", now: wednesdayEvening)
        XCTAssertEqual(result.calls.count, 1, "金额段绝不能另起一卡")
        guard case .createDelivery(let delivery) = result.calls[0].arguments else {
            return XCTFail("应为配送卡")
        }
        XCTAssertEqual(delivery.amount ?? 0, 45, accuracy: 0.001, "总金额 45 应合并进配送卡")
    }

    func testRoomNumberIsNotConfusedWithAmount() {
        let result = CompositeIntentParser.parse("记一笔美团680，再给302送两箱怡宝，一共45元", now: wednesdayEvening)
        XCTAssertEqual(result.calls.count, 2)
        guard case .createDelivery(let delivery) = result.calls[1].arguments else {
            return XCTFail("第二张应为配送卡")
        }
        XCTAssertEqual(delivery.amount ?? 0, 45, accuracy: 0.001, "房号 302 绝不能被当成金额")
        XCTAssertTrue((delivery.roomOrAddress ?? "").contains("302"))
    }

    func testDeliveryWithoutRoomPromptsForCompletion() {
        let result = CompositeIntentParser.parse("记一笔美团680，送两箱怡宝", now: wednesdayEvening)
        XCTAssertEqual(result.calls.count, 1, "缺房号的配送不出卡")
        XCTAssertFalse(result.clarifications.isEmpty, "必须提示补齐房号")
        XCTAssertTrue(result.clarifications.joined().contains("房号"))
    }

    func testCrossMidnightDeliveryTimeUsesLocalTomorrow() {
        let result = CompositeIntentParser.parse("明天凌晨1点给302送两箱怡宝", now: wednesdayEvening)
        XCTAssertEqual(result.calls.count, 1)
        guard case .createDelivery(let delivery) = result.calls[0].arguments,
              let time = delivery.deliveryTime else {
            return XCTFail("应解析出配送时间")
        }
        XCTAssertEqual(calendar.component(.day, from: time), 29, "明天凌晨 1 点应落在次日")
        XCTAssertEqual(calendar.component(.hour, from: time), 1, "凌晨 1 点不是下午 1 点")
    }

    func testAdvanceAndCompleteCallConstruction() {
        let advance = CompositeIntentParser.parse("302那单送到了", now: wednesdayEvening)
        XCTAssertEqual(advance.calls.count, 1)
        XCTAssertEqual(advance.calls[0].name, .advanceDelivery)
        guard case .advanceDelivery(let arguments) = advance.calls[0].arguments else {
            return XCTFail("应为推进配送调用")
        }
        XCTAssertTrue((arguments.roomOrAddress ?? "").contains("302"))

        let complete = CompositeIntentParser.parse("把盘点做完", now: wednesdayEvening)
        XCTAssertEqual(complete.calls.count, 1)
        XCTAssertEqual(complete.calls[0].name, .completeTodo)
    }

    // MARK: 推进工具真实执行（只走既有 Repository）

    @MainActor
    func testAdvanceDeliveryAndCompleteTodoWriteThroughRepositories() async throws {
        let container = try AppDatabase.makeInMemoryContainer()
        let context = container.mainContext
        let journal = InMemoryExecutionJournal()
        let executor = RepositoryToolExecutor(context: context, journal: journal)

        context.insert(Todo(title: "盘点", detail: "", dueDate: nil, priority: 0))
        context.insert(CustomerRequest(customer: "阿东", roomOrAddress: "302", phone: "", content: "怡宝两箱"))
        try context.save()

        let complete = ToolCall(id: ToolCall.makeID(), name: .completeTodo,
                                arguments: .completeTodo(CompleteTodoArguments(titleKeyword: "盘点")))
        guard case .executed = await executor.execute(complete) else { return XCTFail("完成待办应成功") }
        XCTAssertTrue(try context.fetch(FetchDescriptor<Todo>()).first?.isCompleted == true)

        let advance = ToolCall(id: ToolCall.makeID(), name: .advanceDelivery,
                               arguments: .advanceDelivery(AdvanceDeliveryArguments(customer: nil, roomOrAddress: "302", goodsKeyword: nil)))
        guard case .executed = await executor.execute(advance) else { return XCTFail("推进配送应成功") }
        XCTAssertEqual(try context.fetch(FetchDescriptor<CustomerRequest>()).first?.statusEnum, .delivering)

        // 找不到单时失败，不假显示完成。
        let missing = ToolCall(id: ToolCall.makeID(), name: .advanceDelivery,
                               arguments: .advanceDelivery(AdvanceDeliveryArguments(customer: nil, roomOrAddress: "999", goodsKeyword: nil)))
        guard case .failed = await executor.execute(missing) else { return XCTFail("找不到单必须失败") }
    }

    // MARK: AgentCore 复合流：一键确认顺序执行 + 重确认幂等

    @MainActor
    func testConfirmCompositeExecutesInOrderAndSkipsDuplicates() async throws {
        let container = try AppDatabase.makeInMemoryContainer()
        let context = container.mainContext
        let journal = InMemoryExecutionJournal()
        let executor = RepositoryToolExecutor(context: context, journal: journal)
        let env = try AgentEnvironment.makeLive(
            provider: UnconfiguredRemoteProvider(), fallback: nil,
            contextProvider: UnavailableBusinessContextProvider(),
            toolExecutor: executor,
            conversation: InMemoryConversationStore(),
            pending: InMemoryPendingActionStore(),
            journal: journal)
        let agent = AgentCore(env)
        let userMessage = AIMessage(role: .user, content: "记一笔美团680，再给302送两箱怡宝")

        let parsed = CompositeIntentParser.parse("记一笔美团680，再给302送两箱怡宝", now: wednesdayEvening)
        XCTAssertEqual(parsed.calls.count, 2)
        let turn = await agent.proposeComposite(parsed, userMessage: userMessage)
        XCTAssertEqual(turn.assistantMessage?.compositeProposalIDs.count, 2)

        await agent.confirmComposite(turn.assistantMessage!.compositeProposalIDs)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Performance>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CustomerRequest>()).count, 1)

        // 同一组卡重确认：已执行卡全部跳过，不重复写入。
        await agent.confirmComposite(turn.assistantMessage!.compositeProposalIDs)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Performance>()).count, 1, "重确认绝不能重复入账")
        XCTAssertEqual(try context.fetch(FetchDescriptor<CustomerRequest>()).count, 1)
        let messages = await agent.messages()
        XCTAssertTrue(messages.last?.content.contains("一键确认结果") == true, "必须有汇总反馈")
        XCTAssertTrue(messages.last?.content.contains("已经处理过") == true, "重确认必须明确反馈已跳过")
    }
}
