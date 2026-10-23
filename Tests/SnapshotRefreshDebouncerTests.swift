import XCTest
@testable import XiaoZhangGui

/// V3.8 PR-C：Snapshot/Widget 刷新合并器（trailing-edge 去抖）真实行为测试。
///
/// 修复背景：每个 Repository 写操作都全量刷新快照 + reload Widget，
/// 快速连续录入时全部重复。策略：250ms 窗口合并、最后一次写必然同步。
final class SnapshotRefreshDebouncerTests: XCTestCase {

    /// 测试用短窗口（真实 Task.sleep 计时，非 mock）。
    private let shortWindow: TimeInterval = 0.05

    @MainActor
    func testRapidSchedulesCoalesceToSingleTrailingExecution() async {
        let debouncer = SnapshotRefreshDebouncer(window: shortWindow)
        var executions: [String] = []

        // 连续预约三次（模拟快速连续写），窗口内只应执行最后一次。
        debouncer.schedule { executions.append("A") }
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        debouncer.schedule { executions.append("B") }
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        debouncer.schedule { executions.append("C") }

        XCTAssertTrue(debouncer.hasPendingFlush, "窗口期内必须有挂起预约")
        // 等窗口 + 余量（C 是最后一次预约，其 trailing edge 必然执行）。
        try? await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertEqual(executions, ["C"], "三次预约合并为一次，且执行最后一次动作（trailing edge）")
        XCTAssertFalse(debouncer.hasPendingFlush, "执行完毕后无挂起")
    }

    @MainActor
    func testFlushNowExecutesImmediatelyWithoutDoubleFire() async {
        let debouncer = SnapshotRefreshDebouncer(window: shortWindow)
        var count = 0
        debouncer.schedule { count += 1 }
        XCTAssertTrue(debouncer.hasPendingFlush)

        let didFlush = debouncer.flushNow()
        XCTAssertTrue(didFlush, "有挂起时 flushNow 必须执行")
        XCTAssertEqual(count, 1, "flushNow 立即执行一次")

        // 过了原窗口后，被顶替的定时任务不得再次触发（代数对账）。
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(count, 1, "flushNow 之后不得出现第二次执行")
        XCTAssertFalse(debouncer.hasPendingFlush)
    }

    @MainActor
    func testFlushNowWithoutPendingIsNoOp() {
        let debouncer = SnapshotRefreshDebouncer(window: shortWindow)
        var count = 0
        XCTAssertFalse(debouncer.flushNow(), "无挂起时 flushNow 返回 false")
        XCTAssertEqual(count, 0)
    }

    @MainActor
    func testCancelPendingDropsExecution() async {
        let debouncer = SnapshotRefreshDebouncer(window: shortWindow)
        var count = 0
        debouncer.schedule { count += 1 }
        XCTAssertTrue(debouncer.hasPendingFlush)

        debouncer.cancelPending()
        XCTAssertFalse(debouncer.hasPendingFlush)

        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(count, 0, "取消后到期不得执行")
    }

    @MainActor
    func testReplacedScheduleNeverFiresStaleAction() async {
        let debouncer = SnapshotRefreshDebouncer(window: shortWindow)
        var executions: [String] = []
        debouncer.schedule { executions.append("old") }
        // 立刻被新预约顶替（旧任务已取消；即便取消唤醒，代数对账也必须拦下）。
        debouncer.schedule { executions.append("new") }
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(executions, ["new"], "被顶替的旧预约绝不执行（无论取消时序如何）")
    }

    @MainActor
    func testZeroWindowExecutesOnNextMainTick() async {
        // 边界：window = 0（等同立即），预约仍应恰好执行一次。
        let debouncer = SnapshotRefreshDebouncer(window: 0)
        var count = 0
        debouncer.schedule { count += 1 }
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(count, 1)
        XCTAssertFalse(debouncer.hasPendingFlush)
    }

    // MARK: - Repository 接入与 Intent 消重（源码回归钉）

    func testRepositoriesUseDebouncedRefreshExceptBulkImport() throws {
        let source = try source("XiaoZhangGui/Repositories/AppRepository.swift")
        XCTAssertGreaterThan(
            source.components(separatedBy: "SnapshotSyncManager.scheduleDebouncedRefresh(context: context)").count - 1,
            20,
            "Repository 单条写路径必须全部走合并刷新（V3.8 PR-C 回归钉）"
        )
        XCTAssertTrue(
            source.contains("func importSaobei")
                && source.range(of: "func importSaobei[\\s\\S]*?SnapshotSyncManager\\.refreshAll\\(context: context\\)", options: .regularExpression) != nil,
            "批量导入收尾保持立即刷新（一次性写完，立即同步体验最好）"
        )
    }

    func testIntentsReuseRepositoryAndFlushInsteadOfDoubleRefresh() throws {
        let source = try source("XiaoZhangGui/Features/Intents/XZGAppIntents.swift")
        XCTAssertTrue(
            source.contains("try TodoRepository(context: context).add("),
            "AddTodoIntent 必须复用 TodoRepository（PR-C 回归钉）"
        )
        XCTAssertFalse(
            source.contains("SnapshotSyncManager.refreshAll(container: container)"),
            "Intent 不得再手动 refreshAll 造成与 Repository 的双重刷新"
        )
        XCTAssertEqual(
            source.components(separatedBy: "SnapshotSyncManager.flushDebouncedRefresh()").count - 1, 3,
            "三个 Intent 都必须在 Repository 写后立即落地合并刷新"
        )
        XCTAssertTrue(
            source.contains("AppDatabase.makeCachedContainer()"),
            "Intent 必须使用容器缓存（不再每次重开 store）"
        )
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
