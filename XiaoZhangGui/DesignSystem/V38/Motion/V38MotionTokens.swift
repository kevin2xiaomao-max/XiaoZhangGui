import SwiftUI

/// V3.8 Motion 意图时序 Token（正式模块）。
///
/// 隔离声明（Debug-only）：
/// - 本文件不被任何生产 View 引用；与 `Experiments/V38MotionLab/` 下的三个 PoC 文件互不重名、互不依赖。
/// - 时序数值复用 MotionLab PoC 结论（`V38MotionLabTokens`）：press = 0.18s easeOut、
///   expand = spring(response: 0.35, dampingFraction: 0.86)、contentChange = 0.28s easeInOut。
/// - Reduce Motion 开启时返回 `nil`（调用方按"无动效、直接呈现终态"处理），与
///   `V38MotionPolicy` 的降级决策保持一致。
enum V38MotionTokens {

    /// 动效意图。三种意图覆盖全部接入点：按压反馈 / 展开收起 / 内容切换。
    enum Intent: Equatable, Hashable, CaseIterable {
        case press
        case expand
        case contentChange
    }

    /// 按意图解析动效；`reduceMotion == true` 时一律返回 `nil`（静态呈现）。
    static func animation(for intent: Intent, reduceMotion: Bool) -> Animation? {
        if reduceMotion { return nil }
        switch intent {
        case .press:
            return .easeOut(duration: 0.18)
        case .expand:
            return .spring(response: 0.35, dampingFraction: 0.86)
        case .contentChange:
            return .easeInOut(duration: 0.28)
        }
    }

    /// Reduce Motion 下是否允许装饰性形变（与 PoC `allowsDecorativeMorph` 同语义）。
    static func allowsDecorativeMorph(reduceMotion: Bool) -> Bool { !reduceMotion }
}
