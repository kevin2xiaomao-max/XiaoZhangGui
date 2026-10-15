import Foundation
import UIKit

/// V3.8 Motion 降级策略（纯函数）。
///
/// 隔离声明（Debug-only）：本文件不被任何生产 View 引用。`resolve(_:)` 为纯逻辑，
/// 可在 XCTest 中直接覆盖全部降级矩阵。规则与 V371 / V32 的 Reduce Motion 语义一致：
/// Reduce Motion → 全静态（取消位移、过冲、循环，token 返回 nil）；低电量模式 → 降级档；
/// 其它情况 → 完整档。
enum V38MotionPolicy {

    /// 动效档：完整 / 降级（仅短淡入、无弹簧）/ 全静态。
    enum MotionTier: Equatable, Hashable {
        case full
        case reduced
        case staticOnly
    }

    /// 策略输入：Reduce Motion 开关、低电量模式。
    struct Environment: Equatable, Hashable {
        var reduceMotion: Bool
        var lowPowerMode: Bool
    }

    /// 纯函数：输入环境 → 输出动效档。优先级：Reduce Motion > 低电量 > 完整。
    static func resolve(_ environment: Environment) -> MotionTier {
        if environment.reduceMotion { return .staticOnly }
        if environment.lowPowerMode { return .reduced }
        return .full
    }

    /// 当前运行时的环境快照（读取系统真值）。
    static var current: Environment {
        Environment(
            reduceMotion: UIAccessibility.isReduceMotionEnabled,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    /// 装饰性形变（液滴 Morph 等）是否允许：仅完整档允许。
    static func allowsDecorativeMorph(tier: MotionTier) -> Bool { tier == .full }

    /// 位移类过渡（位移/滑入滑出）是否允许：完整档与降级档允许，全静态档禁止。
    static func allowsDisplacement(tier: MotionTier) -> Bool { tier != .staticOnly }

    /// 弹簧过冲是否允许：仅完整档允许；降级档用无过冲的短淡入替代。
    static func allowsOvershoot(tier: MotionTier) -> Bool { tier == .full }

    /// 循环/重复动效是否允许：仅完整档允许。
    static func allowsLoopedAnimation(tier: MotionTier) -> Bool { tier == .full }

    /// 与 `V38MotionTokens` 的衔接：该档位是否应使用时序 token（`.reduced` 用短淡入替代，
    /// `.staticOnly` 对应 token 返回 nil）。
    static func tokenMode(tier: MotionTier) -> TokenMode {
        switch tier {
        case .full: return .fullTokens
        case .reduced: return .shortFadeOnly
        case .staticOnly: return .none
        }
    }

    enum TokenMode: Equatable, Hashable {
        case fullTokens
        case shortFadeOnly
        case none
    }
}
