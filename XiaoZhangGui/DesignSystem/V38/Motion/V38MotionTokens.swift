import SwiftUI

/// V3.8 Motion 意图时序 Token（正式模块）。
///
/// 隔离声明：
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

    /// 可断言的时序值（`Animation` 本身不可 Equatable，故用此值类型承载单测断言）。
    struct Token: Equatable {
        enum Curve: Equatable {
            case easeOut(duration: Double)
            case easeInOut(duration: Double)
            case spring(response: Double, dampingFraction: Double)
        }
        let curve: Curve
    }

    /// 纯函数：意图 + Reduce Motion → 时序值；Reduce Motion 开启时一律 `nil`（静态呈现）。
    static func token(for intent: Intent, reduceMotion: Bool) -> Token? {
        if reduceMotion { return nil }
        switch intent {
        case .press:
            return Token(curve: .easeOut(duration: 0.18))
        case .expand:
            return Token(curve: .spring(response: 0.35, dampingFraction: 0.86))
        case .contentChange:
            return Token(curve: .easeInOut(duration: 0.28))
        }
    }

    /// 由时序值构造 SwiftUI `Animation`；`nil` 表示静态呈现（调用方 `withAnimation(nil)`）。
    static func animation(for intent: Intent, reduceMotion: Bool) -> Animation? {
        guard let token = token(for: intent, reduceMotion: reduceMotion) else { return nil }
        switch token.curve {
        case .easeOut(let duration):
            return .easeOut(duration: duration)
        case .easeInOut(let duration):
            return .easeInOut(duration: duration)
        case .spring(let response, let dampingFraction):
            return .spring(response: response, dampingFraction: dampingFraction)
        }
    }

    /// Reduce Motion 下是否允许装饰性形变（与 PoC `allowsDecorativeMorph` 同语义）。
    static func allowsDecorativeMorph(reduceMotion: Bool) -> Bool { !reduceMotion }
}
