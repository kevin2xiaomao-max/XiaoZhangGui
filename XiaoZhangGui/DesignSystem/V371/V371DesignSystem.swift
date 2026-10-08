import SwiftUI
import UIKit

// MARK: - V371 Design System（V3.7.1 presentation rebuild · 唯一视觉语义层）
//
// Surface 分级（只允许 S0–S3）：
//   S0 Canvas          页面底色
//   S1 Group Surface   大圆角 section，容纳多行（solid，不用 material）
//   S2 Hero Surface    仅重点模块（首页营业额 Hero、日历 masthead）的蓝色能量面
//   S3 Floating        Bottom Dock / AI command / 少量 overlay（允许 material）
//
// 内容区禁止 material；禁止 Card Wall（用「1 个 section surface + 多行 editorial rows」）。

enum V371 {

    // MARK: - S0–S3 Surface 色

    enum Colors {
        /// S0 页面底色：暖白 / 近黑
        static var canvas: Color { Color(UIColor.v371Canvas) }
        /// S1 分组面：白 / 深灰黑
        static var group: Color { Color(UIColor.v371Group) }
        /// S1 次级（嵌套小块）：浅灰 / 更深灰
        static var groupSecondary: Color { Color(UIColor.v371GroupSecondary) }
        /// 行内图标底（彩色微状态用）
        static func tinted(_ color: Color) -> Color { color.opacity(0.13) }

        static var textPrimary: Color { .primary }
        static var textSecondary: Color { .secondary }
        static var textTertiary: Color { Color(.tertiaryLabel) }
        static var divider: Color { Color(.separator) }

        // MARK: S2 Hero 蓝（能量焦点，暗色降亮度）
        static var heroTop: Color { Color(UIColor.v371HeroTop) }
        static var heroBottom: Color { Color(UIColor.v371HeroBottom) }
        static var heroText: Color { .white }
        static var heroTextSecondary: Color { .white.opacity(0.82) }

        // MARK: 彩色微状态（只用于 icon / badge / 小状态，不铺满屏）
        static var blue: Color { Color(UIColor.v371Blue) }
        static var green: Color { Color(UIColor.v371Green) }
        static var orange: Color { Color(UIColor.v371Orange) }
        static var red: Color { Color(UIColor.v371Red) }
        static var yellow: Color { Color(UIColor.v371Yellow) }
        static var gray: Color { Color(.systemGray) }
    }

    // MARK: - Semantic Radius（禁止各页面自写随机 radius）

    enum Radius {
        /// 小控件 / badge 内圆角
        static let control: CGFloat = 12
        /// 图标圆 / 小 tile
        static let tile: CGFloat = 20
        /// S1 分组面
        static let group: CGFloat = 24
        /// S2 Hero
        static let hero: CGFloat = 28
        /// 胶囊
        static let pill: CGFloat = 999
    }

    // MARK: - Spacing

    enum Space {
        static let page: CGFloat = 16
        static let section: CGFloat = 20
        static let rowGap: CGFloat = 12
        static let rowPadding: CGFloat = 14
    }

    // MARK: - Typography（系统字体，层级靠 size/weight/spacing）

    enum Typography {
        /// Hero 大数字
        static let heroNumber: Font = .system(size: 44, weight: .bold, design: .rounded).monospacedDigit()
        /// Hero 标题
        static let heroTitle: Font = .system(size: 15, weight: .semibold)
        /// Section 标题
        static let sectionTitle: Font = .system(size: 17, weight: .semibold)
        /// 行标题
        static let rowTitle: Font = .system(size: 16, weight: .medium)
        /// 行副标题
        static let rowSubtitle: Font = .system(size: 13, weight: .regular)
        /// 时间列
        static let time: Font = .system(size: 13, weight: .semibold).monospacedDigit()
        /// Badge
        static let badge: Font = .system(size: 12, weight: .semibold)
        /// 快捷入口 label
        static let quickAction: Font = .system(size: 12, weight: .medium)
    }

    // MARK: - Shadow（柔软浮层感，不厚重；行不加 shadow）

    enum Shadow {
        static let hero: (color: Color, radius: CGFloat, y: CGFloat) =
            (.blue.opacity(0.25), 18, 8)
        static let floating: (color: Color, radius: CGFloat, y: CGFloat) =
            (.black.opacity(0.10), 16, 6)
    }

    // MARK: - Motion（V3.7.1 统一动效语言：FAST / NATIVE / RESPONSIVE / TACTILE / RESTRAINED）
    //
    // V371Motion 是 V3.7.1 的语义动效 token 层；数值实现复用 V32Motion 的克制取值
    // （单测钉住其裸数值，不分叉、不另起数值体系）。各页面不再自写裸时长/裸 spring。
    //
    // 语义 token：instant / fast / standard / emphasized；spring 统一用克制参数；
    // 优先原生 transition；全部支持 Reduce Motion（移除装饰性 scale 与复杂位移，
    // 保留必要 opacity / state 变化，不影响功能）。

    enum Motion {
        /// 即时反馈（0.10s）：tab 选中胶囊、press 高亮等最轻反馈
        static let instant: Animation = .easeOut(duration: 0.10)
        /// 快速（0.18s）：默认状态切换、淡入、行状态变化
        static let fast: Animation = V32Motion.quick
        /// 标准（0.28s）：数字滚动（numericText）、较大过渡
        static let standard: Animation = V32Motion.standard
        /// 强调（0.42s）：极少用，仅 deliberate 的大区块展开
        static let emphasized: Animation = V32Motion.slow

        /// 统一克制弹簧（response 0.35 / damping 0.86）：展开、卡片状态、完成态
        static let spring: Animation = V32Motion.softSpring
        /// 交互弹簧（response 0.28 / damping 0.82）：跟手、拖拽类
        static let interactiveSpring: Animation = V32Motion.interactiveSpring

        /// Quick Action 按压缩放（克制，不夸张）
        static let pressScale: CGFloat = 0.97

        // MARK: Reduce Motion（统一走 V32Motion 决策，保持单测可验证）

        typealias Surface = V32Motion.Surface
        typealias Resolved = V32Motion.Resolved

        /// 按系统「减弱动态效果」开关解析应使用的动效。
        static func resolve(_ surface: Surface, reduceMotion: Bool) -> Resolved {
            V32Motion.resolve(surface, reduceMotion: reduceMotion)
        }

        /// 由解析结果取 Animation；.none 返回 nil（调用方 withAnimation(nil) 即立即应用）。
        static func animation(_ resolved: Resolved) -> Animation? {
            V32Motion.animation(resolved)
        }

        /// 进度条宽度专用：Reduce Motion 关闭时 spring；开启时直切（nil）。
        static func progressWidth(reduceMotion: Bool) -> Animation? {
            V32Motion.progressWidth(reduceMotion: reduceMotion)
        }

        /// 语义 token 的 Reduce Motion 安全版本：开启时返回 nil（立即应用，无装饰动效）。
        static func safe(_ animation: Animation, reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : animation
        }
    }
}

// MARK: - 动态 UIColor（Light / Dark 双正确）

private extension UIColor {
    static var v371Canvas: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.030, green: 0.030, blue: 0.045, alpha: 1.0)   // 近黑
                : UIColor(red: 0.955, green: 0.955, blue: 0.968, alpha: 1.0)   // 暖白
        }
    }

    static var v371Group: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.105, green: 0.105, blue: 0.125, alpha: 1.0)   // 深灰黑
                : UIColor.white
        }
    }

    static var v371GroupSecondary: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.155, green: 0.155, blue: 0.180, alpha: 1.0)
                : UIColor(red: 0.945, green: 0.945, blue: 0.955, alpha: 1.0)
        }
    }

    static var v371HeroTop: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.180, green: 0.380, blue: 0.880, alpha: 1.0)    // 暗色降亮度
                : UIColor(red: 0.290, green: 0.610, blue: 1.000, alpha: 1.0)   // 能量蓝
        }
    }

    static var v371HeroBottom: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.110, green: 0.280, blue: 0.720, alpha: 1.0)
                : UIColor(red: 0.170, green: 0.430, blue: 0.950, alpha: 1.0)
        }
    }

    static var v371Blue: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.360, green: 0.620, blue: 1.000, alpha: 1.0)
                : UIColor(red: 0.180, green: 0.460, blue: 0.960, alpha: 1.0)
        }
    }

    static var v371Green: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.300, green: 0.780, blue: 0.480, alpha: 1.0)
                : UIColor(red: 0.130, green: 0.640, blue: 0.350, alpha: 1.0)
        }
    }

    static var v371Orange: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.000, green: 0.660, blue: 0.300, alpha: 1.0)
                : UIColor(red: 0.910, green: 0.570, blue: 0.050, alpha: 1.0)
        }
    }

    static var v371Red: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.000, green: 0.420, blue: 0.420, alpha: 1.0)
                : UIColor(red: 0.900, green: 0.280, blue: 0.300, alpha: 1.0)
        }
    }

    static var v371Yellow: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.000, green: 0.800, blue: 0.350, alpha: 1.0)
                : UIColor(red: 0.790, green: 0.600, blue: 0.000, alpha: 1.0)
        }
    }
}

// Haptic 统一定义点见 XiaoZhangGui/DesignSystem/FloatingDock.swift（enum Haptic）。

// MARK: - Canvas / Dock 安全区 Modifier

/// S0 页面底色。
struct V371CanvasModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(V371.Colors.canvas.ignoresSafeArea())
    }
}

/// 为悬浮 Dock 预留底部安全区（内容不被 Dock 遮挡）。
struct V371DockInsetModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.bottom, 104)
    }
}

extension View {
    /// S0 底色
    func v371Canvas() -> some View { modifier(V371CanvasModifier()) }
    /// 悬浮 Dock 底部避让
    func v371DockInset() -> some View { modifier(V371DockInsetModifier()) }
}
