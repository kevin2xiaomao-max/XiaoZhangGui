import SwiftUI

// MARK: - V32 / BusinessDesignSystem — 字体层级 Token
// 中文走系统字体；数字（金额/指标）使用 SF Rounded + 等宽数字。

enum V32Font {
    /// hero 卡内最大数字（今日营业额）
    static let heroMoney = Font.system(size: 38, weight: .bold, design: .rounded).monospacedDigit()
    /// 大数字（指标格）
    static let metric = Font.system(size: 22, weight: .bold, design: .rounded).monospacedDigit()
    /// 小数字（胶囊/时间）
    static let metricSmall = Font.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit()

    /// 问候语大标题（店名/老板名）
    static let display = Font.system(size: 32, weight: .bold)
    /// 页面导航大标题
    static let pageTitle = Font.system(size: 26, weight: .bold)
    /// 区块标题
    static let section = Font.system(size: 20, weight: .bold)
    /// 卡片标题 / 事件标题
    static let headline = Font.system(size: 16, weight: .semibold)
    /// 列表主标题
    static let title = Font.system(size: 15, weight: .semibold)
    /// 正文
    static let body = Font.system(size: 15, weight: .regular)
    /// 副标题 / 元信息（类型 · 时间）
    static let subhead = Font.system(size: 13, weight: .regular)
    /// 辅助说明
    static let caption = Font.system(size: 12, weight: .regular)
    /// 胶囊 / 小标签
    static let pill = Font.system(size: 11, weight: .semibold)
}

enum V32TextStyle {
    case heroMoney, metric, metricSmall
    case display, pageTitle, section, headline, title, body, subhead, caption, pill

    var font: Font {
        switch self {
        case .heroMoney: return V32Font.heroMoney
        case .metric: return V32Font.metric
        case .metricSmall: return V32Font.metricSmall
        case .display: return V32Font.display
        case .pageTitle: return V32Font.pageTitle
        case .section: return V32Font.section
        case .headline: return V32Font.headline
        case .title: return V32Font.title
        case .body: return V32Font.body
        case .subhead: return V32Font.subhead
        case .caption: return V32Font.caption
        case .pill: return V32Font.pill
        }
    }
}

private struct V32TextModifier: ViewModifier {
    let style: V32TextStyle
    func body(content: Content) -> some View {
        content.font(style.font)
    }
}

/// b28 T27 / P0-3：页面背景层。
/// - 壁纸启用：把 V32WallpaperBackground 直接作为**当前页面的背景层**渲染，
///   保证壁纸真实出现在首页 / 日程 / 待办 / 我的（RootView 底层会被 TabView /
///   NavigationStack 容器的不透明默认背景完全盖住，不能再依赖最底层）。
/// - 壁纸禁用：保持 b27 行为，背景 = V32.pageBG；清除壁纸后立即恢复。
/// 卡片仍是 V32.card 不透明表面，可读性不受影响。
@MainActor
private struct V32PageBackgroundModifier: ViewModifier {
    @Environment(ThemeStore.self) private var themeStore

    func body(content: Content) -> some View {
        if themeStore.wallpaper.isEnabled {
            content.background {
                V32WallpaperBackground()
            }
        } else {
            content.background(V32.pageBG.ignoresSafeArea())
        }
    }
}

extension View {
    func v32Text(_ style: V32TextStyle) -> some View {
        modifier(V32TextModifier(style: style))
    }

    /// 统一 V32 页面底色：
    /// - 壁纸启用：壁纸作为当前页面可见背景层（P0-3）
    /// - 壁纸禁用：V32.pageBG（保持 b27 行为）
    func v32PageBackground() -> some View {
        modifier(V32PageBackgroundModifier())
    }

    /// Sheet 统一圆角与拖拽指示器（detents 由调用方按场景指定）
    func v32Sheet(_ detents: Set<PresentationDetent>) -> some View {
        self
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(V32Radius.sheet)
    }
}
