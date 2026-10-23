import Foundation

// MARK: - Snapshot / Widget 刷新合并器（V3.8 PR-C：trailing-edge 去抖）
//
// 背景：每个 Repository 写操作都会全量构建快照 + reload Widget + 更新 Live Activity；
// 快速连续录入（如批量勾选待办、连续记几笔账）时，同几秒内多次全量查询与
// Widget reload 全部重复浪费，且 WidgetCenter reload 风暴在低端机上有可感知卡顿。
//
// 策略（指令 B3 允许的 100–300ms 合并方案）：
// - 写操作只「预约」刷新，250ms 静默窗口内的多次预约合并为一次；
// - **最后一次成功写入必然最终同步**（trailing edge 永远执行）；
// - 需要立即刷新的调用方（scenePhase 兜底、批量导入收尾、App Intent）
//   使用 `flushNow()` 立即落地，或继续走 `SnapshotSyncManager.refreshAll`；
// - 到期执行固定派发回主线程（Task @MainActor），刷新链路始终在主线程。
//
// 线程模型：与代码库既有约定一致——`schedule` 由主线程调用（Repository 写路径
// 全部来自 MainActor 视图/VM/Intent.perform）；内部用 NSLock 保护极小临界区，
// 使状态读写本身线程安全。

final class SnapshotRefreshDebouncer {
    /// 合并窗口（秒）：指令区间 100–300ms 的中值。
    static let defaultWindow: TimeInterval = 0.25

    private let window: TimeInterval
    private let lock = NSLock()
    /// 预约代数：每次 schedule / flushNow / cancelPending 递增，
    /// 在途旧任务的到期回调按代数对账，杜绝「被替换的旧任务提前/重复触发」。
    private var generation = 0
    private var action: (() -> Void)?
    private var pendingTask: Task<Void, Never>?

    init(window: TimeInterval = SnapshotRefreshDebouncer.defaultWindow) {
        precondition(window >= 0, "合并窗口必须非负")
        self.window = window
    }

    /// 是否有尚未落地的刷新预约。
    var hasPendingFlush: Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingTask != nil
    }

    /// 预约一次刷新：窗口内重复调用只保留最后一次动作（trailing edge）。
    func schedule(_ action: @escaping () -> Void) {
        lock.lock()
        generation += 1
        let myGeneration = generation
        self.action = action
        pendingTask?.cancel()
        let waitNanos = UInt64(window * 1_000_000_000)
        pendingTask = Task { @MainActor [weak self] in
            if waitNanos > 0 {
                try? await Task.sleep(nanoseconds: waitNanos)
            }
            self?.fire(generation: myGeneration)
        }
        lock.unlock()
    }

    /// 立即执行挂起的刷新（无挂起则不做事）。使一切在途任务失效，不会二次触发。
    @discardableResult
    func flushNow() -> Bool {
        lock.lock()
        generation += 1
        pendingTask?.cancel()
        pendingTask = nil
        let action = action
        self.action = nil
        lock.unlock()
        guard let action else { return false }
        action()
        return true
    }

    /// 取消挂起的刷新（不执行；用于清理）。
    func cancelPending() {
        lock.lock()
        generation += 1
        pendingTask?.cancel()
        pendingTask = nil
        action = nil
        lock.unlock()
    }

    /// 到期对账：仅当「本任务代数 == 当前代数」且仍有挂起任务时执行。
    /// 被 schedule 替换 / flushNow / cancelPending 打断的旧任务在此安静退出。
    private func fire(generation: Int) {
        lock.lock()
        guard generation == self.generation, pendingTask != nil else {
            lock.unlock()
            return
        }
        pendingTask = nil
        let action = action
        self.action = nil
        lock.unlock()
        action?()
    }
}
