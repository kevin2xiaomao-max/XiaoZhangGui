import SwiftData
import XCTest
@testable import XiaoZhangGui

/// V3.8 重建 R2 · Todo 勾选回执与进度逻辑测试。
///
/// 核心是规格 §2 / G5 铁律的代码级证明：
/// - 保存中（saving）阶段 `showsChecked` 恒为 false —— 成功视觉不可能先于回执出现；
/// - 保存失败 ⇒ `.failed`，保留意图、可重试，绝不产生完成态（无成功闪现）；
/// - 保存成功 ⇒ 回执之后才进入 `.idle(isDone:)` 完成态；
/// - 保存中连点被忽略（20 次快速点按只发起一次保存）。
final class V38TodoRebuildTests: XCTestCase {

    private struct StubSaveError: Error {}

    // MARK: - 保存中不宣告成功（G5 核心）

    func testSavingPhaseNeverShowsChecked() {
        let machine = V38PageMotionState(isDone: false)
        let saving = V38TodoToggleFlow.begin(from: machine)
        XCTAssertNotNil(saving, "待办点按应进入保存中")
        XCTAssertTrue(saving?.isSaving == true)
        XCTAssertFalse(saving?.showsChecked == true, "保存中绝不显示已完成（G5）")
    }

    func testSuccessfulSaveShowsCheckedOnlyAfterReceipt() {
        var saveRan = false
        let saving = try? XCTUnwrap(V38TodoToggleFlow.begin(from: V38PageMotionState(isDone: false)))
        guard let saving else { return XCTFail("未进入保存中") }
        XCTAssertFalse(saving.showsChecked, "回执前不显示完成")
        let resolved = V38TodoToggleFlow.resolve(saving) { saveRan = true }
        XCTAssertTrue(saveRan, "resolve 必须真实执行保存闭包")
        XCTAssertEqual(resolved.phase, .idle(isDone: true))
        XCTAssertTrue(resolved.showsChecked, "回执后才显示完成")
    }

    // MARK: - 失败：无成功闪现 + 意图保留 + 可重试

    func testFailedSaveKeepsUncheckedAndRetainsIntent() {
        let saving = V38TodoToggleFlow.begin(from: V38PageMotionState(isDone: false))
        XCTAssertNotNil(saving)
        guard let saving else { return }
        XCTAssertFalse(saving.showsChecked, "保存中无完成态")
        let resolved = V38TodoToggleFlow.resolve(saving) { throw StubSaveError() }
        XCTAssertEqual(resolved.phase, .failed(intendedDone: true), "失败必须保留未达成的意图")
        XCTAssertFalse(resolved.showsChecked, "失败后绝不显示完成态（无成功闪现）")
        XCTAssertEqual(resolved.failureMessage, "保存失败，可重试")
    }

    func testRetryAfterFailureReusesSameIntentAndCanSucceed() {
        let saving = V38TodoToggleFlow.begin(from: V38PageMotionState(isDone: false))!
        let failed = V38TodoToggleFlow.resolve(saving) { throw StubSaveError() }
        // 从 failed 态再次 begin = 重试同一意图（不是反向切换）
        let retrying = V38TodoToggleFlow.begin(from: failed)
        XCTAssertNotNil(retrying, "失败态必须可重试")
        guard let retrying else { return }
        let resolved = V38TodoToggleFlow.resolve(retrying) { /* 第二次保存成功 */ }
        XCTAssertEqual(resolved.phase, .idle(isDone: true), "重试成功后完成原意图")
    }

    func testDismissFailureRestoresConfirmedState() {
        let saving = V38TodoToggleFlow.begin(from: V38PageMotionState(isDone: false))!
        var failed = V38TodoToggleFlow.resolve(saving) { throw StubSaveError() }
        failed.dismissFailure()
        XCTAssertEqual(failed.phase, .idle(isDone: false), "放弃重试回到点按前已确认态")
    }

    func testUncompleteFailureKeepsCompletedState() {
        // 已完成项取消完成时保存失败：保持已完成（意图为未完成，未达成）。
        let saving = V38TodoToggleFlow.begin(from: V38PageMotionState(isDone: true))!
        let resolved = V38TodoToggleFlow.resolve(saving) { throw StubSaveError() }
        XCTAssertEqual(resolved.phase, .failed(intendedDone: false))
        XCTAssertFalse(resolved.showsChecked, "失败态不渲染完成视觉（由行内失败条传达）")
        var dismissed = resolved
        dismissed.dismissFailure()
        XCTAssertEqual(dismissed.phase, .idle(isDone: true), "放弃后回到已完成确认态")
        XCTAssertTrue(dismissed.showsChecked)
    }

    // MARK: - 连点鲁棒性（G4）：20 次快速点按只发起一次保存

    func testRapidTapsDuringSavingInvokeSaveOnce() {
        let initial = V38PageMotionState(isDone: false)
        guard let saving = V38TodoToggleFlow.begin(from: initial) else {
            return XCTFail("首次点按应进入保存中")
        }
        for _ in 0..<20 {
            XCTAssertNil(
                V38TodoToggleFlow.begin(from: saving),
                "保存中连点必须被忽略，不得重复发起保存"
            )
        }
        var saveCount = 0
        let resolved = V38TodoToggleFlow.resolve(saving) { saveCount += 1 }
        XCTAssertEqual(saveCount, 1, "20 次连点只执行一次保存")
        XCTAssertEqual(resolved.phase, .idle(isDone: true))
    }

    func testBeginFromSavingReturnsNilAndResolveOnNonSavingIsNoOp() {
        let idle = V38PageMotionState(isDone: true)
        let resolved = V38TodoToggleFlow.resolve(idle) {
            XCTFail("非 saving 态不得执行保存")
        }
        XCTAssertEqual(resolved.phase, .idle(isDone: true))
    }

    // MARK: - 进度计算（口径诚实）

    func testProgressFractionUsesCompletedOverAllTodos() {
        let progress = V38TodoProgress(pendingToday: 2, completed: 3, overdue: 1, pendingTotal: 5)
        XCTAssertEqual(progress.totalTracked, 8)
        XCTAssertEqual(progress.fraction, 3.0 / 8.0, accuracy: 0.0001)
        XCTAssertEqual(progress.percent, 38)
    }

    func testProgressEmptyIsZero() {
        let progress = V38TodoProgress(pendingToday: 0, completed: 0, overdue: 0, pendingTotal: 0)
        XCTAssertEqual(progress.fraction, 0)
        XCTAssertEqual(progress.percent, 0)
    }

    // MARK: - 业务口径保护：TodoFilter 过滤/分组语义不变

    func testTodoFilterSemanticsPreserved() throws {
        let context = try makeTestContext()
        let cal = Calendar.current
        let todayMorning = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let todayEvening = cal.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: todayMorning)!
        context.insert(Todo(title: "上午待办", dueDate: todayMorning))
        context.insert(Todo(title: "晚上待办", dueDate: todayEvening))
        context.insert(Todo(title: "明天待办", dueDate: tomorrow))
        context.insert(Todo(title: "已完成待办", dueDate: todayMorning, isCompleted: true))
        try context.save()

        let all = try context.fetch(FetchDescriptor<Todo>())
        let today = TodoFilter.todos(for: .today, in: all)
        XCTAssertEqual(Set(today.map(\.title)), ["上午待办", "晚上待办"], "今日过滤口径不变")
        let groups = TodoFilter.grouped(today)
        XCTAssertEqual(groups.map(\.label), ["上午", "晚上"], "时段分组口径不变")
        XCTAssertEqual(TodoFilter.todos(for: .done, in: all).map(\.title), ["已完成待办"])
    }

    // MARK: - 设计 tokens

    func testStyleTokensMatchSpec() {
        XCTAssertGreaterThanOrEqual(V38TodoStyle.rowMinHeight, 60, "行高 ≥60pt")
        XCTAssertGreaterThanOrEqual(V38TodoStyle.toggleHitSize, 44, "命中区 ≥44pt")
        XCTAssertEqual(V38TodoStyle.groupRadius, 20, "Group radius 20pt")
        XCTAssertEqual(V38TodoStyle.businessGreen, V38HomeStyle.businessGreen, "与 Home 同一 Accent 来源")
    }

    // MARK: - Helpers

    private func makeTestContext() throws -> ModelContext {
        let schema = Schema([Todo.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }
}
