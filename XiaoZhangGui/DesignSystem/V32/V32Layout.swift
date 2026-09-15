import SwiftUI

// MARK: - V32 / BusinessDesignSystem — 间距与尺寸 Token

enum V32Layout {
    // 页面
    static let pageMargin: CGFloat = 22
    static let sectionGap: CGFloat = 26
    static let cardGap: CGFloat = 12
    static let bottomPad: CGFloat = 28
    /// 页面底部呼吸间距（b27 T16）：叠加在系统安全区之上的设计间距；
    /// 不是机型 safe-area 测量值，Home Indicator / 浮动 Tab 高度一律由系统在运行时提供。
    static let pageBottomBreathing: CGFloat = 12

    // 卡片内边距
    static let cardPad: CGFloat = 16
    static let cardPadLarge: CGFloat = 18
    static let heroPad: CGFloat = 20

    // 行
    static let rowGap: CGFloat = 12
    static let rowMinHeight: CGFloat = 56
    static let listRowGap: CGFloat = 10

    // 图标容器
    static let bubbleSmall: CGFloat = 36
    static let bubbleRegular: CGFloat = 42
    static let iconSmall: CGFloat = 16
    static let iconRegular: CGFloat = 19

    // 圆形勾选
    static let checkbox: CGFloat = 26

    // 顶部工具行圆形按钮
    static let toolCircle: CGFloat = 40
    static let toolIcon: CGFloat = 18

    // 头像
    static let avatarSmall: CGFloat = 38
    static let avatarLarge: CGFloat = 64

    // 横向卡片
    static let hCardWidth: CGFloat = 248
}
