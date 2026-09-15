import SwiftUI

// MARK: - V32Motion（b27 T16）
// 统一动效 token。b27 新增 / 修改的所有动画只允许引用这里的取值；
// 历史裸时长不做全量清洗，Voice / Widget / Live Activity 不在本范围。
// 数值与 spec「Motion Principles」表一致。

enum V32Motion {

    // MARK: 时长（裸数值，供单测断言）
    static let quickDuration: TimeInterval = 0.18
    static let standardDuration: TimeInterval = 0.28
    static let slowDuration: TimeInterval = 0.42
    /// Reduce Motion 开启时的统一短淡入时长（无位移 / 无弹簧 / 无缩放）
    static let reducedDuration: TimeInterval = 0.12

    // MARK: 弹簧参数（裸数值，供单测断言）
    static let softSpringResponse: Double = 0.35
    static let softSpringDamping: Double = 0.86
    static let interactiveSpringResponse: Double = 0.28
    static let interactiveSpringDamping: Double = 0.82

    // MARK: 动画 token
    static let quick: Animation = .easeOut(duration: quickDuration)
    static let standard: Animation = .easeOut(duration: standardDuration)
    static let slow: Animation = .easeOut(duration: slowDuration)
    static let softSpring: Animation = .spring(
        response: softSpringResponse, dampingFraction: softSpringDamping)
    static let interactiveSpring: Animation = .spring(
        response: interactiveSpringResponse, dampingFraction: interactiveSpringDamping)
    /// Reduce Motion 下的统一短淡入
    static let reducedFade: Animation = .easeOut(duration: reducedDuration)

    // MARK: Reduce Motion 决策（纯函数，可单测）

    /// 动效表面分类：crossfade / 弹簧位移 / 数字滚动。
    enum Surface {
        /// 短淡入 / crossfade（普通切换、状态淡入）
        case fade
        /// 弹簧 / 位移类（展开、卡片状态变化）
        case spring
        /// 数字滚动类（numericText 金额、进度数值）
        case numeric
    }

    /// 解析后的动效选择（值语义，可单测）。
    enum Resolved: Equatable {
        case quick, standard, slow, softSpring, interactiveSpring, none
    }

    /// 按系统「减弱动态效果」开关解析应使用的动效。
    /// - reduceMotion 为 true：无位移、无弹簧、无明显 scale；fade/spring 统一退化为短淡入，
    ///   numeric 直接替换终值（.none → withAnimation(nil)）。
    static func resolve(_ surface: Surface, reduceMotion: Bool) -> Resolved {
        if reduceMotion {
            return surface == .numeric ? .none : .quick
        }
        switch surface {
        case .fade: return .quick
        case .spring: return .softSpring
        case .numeric: return .standard
        }
    }

    /// 进度条宽度专用：Reduce Motion 关闭时 softSpring；开启时必须直切（nil），
    /// 不能用短动画去动 width/scale/spring。短淡入只能单独作用于 opacity。
    static func progressWidth(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : softSpring
    }

    /// 由解析结果取 Animation；.none 返回 nil（调用方传 withAnimation(nil) 即立即应用）。
    static func animation(_ resolved: Resolved) -> Animation? {
        switch resolved {
        case .quick: return quick
        case .standard: return standard
        case .slow: return slow
        case .softSpring: return softSpring
        case .interactiveSpring: return interactiveSpring
        case .none: return nil
        }
    }
}
