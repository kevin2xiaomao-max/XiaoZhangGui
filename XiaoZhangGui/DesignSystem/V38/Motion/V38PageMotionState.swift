import Foundation

/// 待办勾选反馈的状态机（纯逻辑，无 SwiftUI 依赖，可单元测试）。
///
/// 对应 `Docs/V38-Page-Motion-Spec.md` §2 与 G5 铁律：
/// 「持久化完成之前不宣告成功；失败保持可操作并保留重试」。
/// 演示组件 `TodoToggleDemoView` 只消费这个状态机，不直接碰 Repository。
enum V38PageTogglePhase: Equatable {
    /// 静息态。`isDone` 为已落库确认的真实完成态。
    case idle(isDone: Bool)
    /// 保存中。`intendedDone` 为用户意图；此阶段 UI 只允许展示"保存中"，不许展示成功态。
    case saving(intendedDone: Bool)
    /// 保存失败。`intendedDone` 为未达成的用户意图；UI 必须提供重试并回到原态的出口。
    case failed(intendedDone: Bool)
}

struct V38PageMotionState: Equatable {
    private(set) var phase: V38PageTogglePhase

    init(isDone: Bool = false) {
        phase = .idle(isDone: isDone)
    }

    /// 用户点按勾选/取消勾选。saving 中重复点按被忽略（防连点错乱，G4）。
    mutating func requestToggle() {
        switch phase {
        case .idle(let isDone):
            phase = .saving(intendedDone: !isDone)
        case .failed(let intendedDone):
            phase = .saving(intendedDone: intendedDone) // 重试走同一入口
        case .saving:
            break // 忽略：一次只允许一个在途保存
        }
    }

    /// 持久化成功回执。只在 saving 态有效 —— 这是 G5 的代码级保证。
    mutating func saveSucceeded() {
        if case .saving(let intendedDone) = phase {
            phase = .idle(isDone: intendedDone)
        }
    }

    /// 持久化失败回执。只在 saving 态有效；失败后回到可重试态。
    mutating func saveFailed() {
        if case .saving(let intendedDone) = phase {
            phase = .failed(intendedDone: intendedDone)
        }
    }

    /// 用户放弃重试，回到点按之前的已确认态。
    mutating func dismissFailure() {
        if case .failed(let intendedDone) = phase {
            phase = .idle(isDone: !intendedDone)
        }
    }

    // MARK: - 派生（供 View 渲染，无业务含义）

    /// 复选框视觉：只有 idle(isDone:true) 才是"已完成"。
    var showsChecked: Bool {
        if case .idle(let isDone) = phase { return isDone }
        return false
    }

    var isSaving: Bool {
        if case .saving = phase { return true }
        return false
    }

    var failureMessage: String? {
        if case .failed = phase { return "保存失败，可重试" }
        return nil
    }
}
