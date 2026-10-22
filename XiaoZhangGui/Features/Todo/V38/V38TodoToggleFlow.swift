import Foundation

/// V3.8 重建 R2 · 待办勾选两段式流程（纯逻辑，可单测）。
///
/// 对应 `Docs/V38-Page-Motion-Spec.md` §2 与 G5 铁律：
/// 「持久化完成之前不宣告成功；`isCompleted` 的 UI 完成态只在 Repository 回写成功后渲染」。
///
/// 流程被刻意拆成两步，让 View 能在两步之间真实渲染「保存中」态：
/// 1. `begin`：点按 → 进入 `.saving`（只显示转圈/灰色，**不显示任何完成视觉**）；
///    已在 saving 时返回 nil（连点忽略，防状态错乱）。
/// 2. `resolve`：执行真实保存闭包（生产为 Repository 写链），按回执收口：
///    成功 → `.idle(isDone: 意图)`，此后才允许渲染完成态；
///    抛出 → `.failed`，回到未勾选态并保留意图供重试。
///
/// 状态机本体复用 C 线纯逻辑 `V38PageMotionState`（已有单元测试覆盖），此处不复制实现。
enum V38TodoToggleFlow {

    /// 第一步：发起一次勾选/重试。返回进入保存中的状态机；不应发起（连点）时返回 nil。
    static func begin(from current: V38PageMotionState) -> V38PageMotionState? {
        var machine = current
        machine.requestToggle()
        return machine.isSaving ? machine : nil
    }

    /// 第二步：执行保存并按回执收口。`save` 抛错 ⇒ 失败态，绝不产生完成态。
    static func resolve(_ saving: V38PageMotionState, save: () throws -> Void) -> V38PageMotionState {
        var machine = saving
        guard machine.isSaving else { return machine }
        do {
            try save()
            machine.saveSucceeded()
        } catch {
            machine.saveFailed()
        }
        return machine
    }
}

/// V3.8 Todo 顶部进度（纯计算，可单测）。
///
/// 口径诚实：`fraction` = 已完成 /（已完成 + 全部未完成），是整体完成进度，
/// 不冒充「今日完成率」（已完成数含历史完成项，与今日待办口径不同，UI 文案分开呈现）。
struct V38TodoProgress: Equatable {
    /// 今日待办（未完成且到期为今日/未安排）。
    let pendingToday: Int
    /// 已完成总数。
    let completed: Int
    /// 逾期未完成数。
    let overdue: Int
    /// 全部未完成数。
    let pendingTotal: Int

    /// 进度分母：已完成 + 全部未完成（即全部待办）。
    var totalTracked: Int { completed + pendingTotal }

    /// 整体完成比例（无待办时为 0）。
    var fraction: Double {
        guard totalTracked > 0 else { return 0 }
        return Double(completed) / Double(totalTracked)
    }

    /// 整体进度百分比（四舍五入，供 VoiceOver 播报）。
    var percent: Int { Int((fraction * 100).rounded()) }
}
