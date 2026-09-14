import SwiftUI

// MARK: - V2.1 Design Tokens — Spacing / Radius / Sizes
// 全 App UI 精修：统一来源，减少 magic numbers

enum V21Layout {
    // ========== 页面布局 ==========
    /// 页面左右边距（统一 20pt）
    static let pageMargin: CGFloat = 20
    /// 列表底部额外呼吸空间（给 Tab Bar + 独立语音按钮留位置）
    static let bottomContentPadding: CGFloat = 120
    
    // ========== Section 间距 ==========
    static let spaceXS: CGFloat = 4
    static let spaceSM: CGFloat = 8
    static let spaceMD: CGFloat = 12
    static let spaceLG: CGFloat = 16
    static let spaceXL: CGFloat = 20
    static let spaceXXL: CGFloat = 28
    static let spaceXXXL: CGFloat = 32

    // ========== 圆角 ==========
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 20
    static let radiusPill: CGFloat = 20
    static let radiusDock: CGFloat = 28

    // ========== 组件尺寸 ==========
    /// 自定义 FAB / 加号按钮尺寸（48pt，视觉直径 44-52pt 区间内）
    static let fabSize: CGFloat = 48
    /// FAB 内部图标尺寸
    static let fabIconSize: CGFloat = 18
    /// 独立语音主按钮视觉直径（60pt，56-68pt 区间内）
    static let centralVoiceButton: CGFloat = 60
    /// 语音按钮内部麦克风图标尺寸
    static let voiceButtonIconSize: CGFloat = 22
    /// 列表项最小高度
    static let listItemMinHeight: CGFloat = 52
    /// 快速入口图标框尺寸
    static let quickEntryIconBox: CGFloat = 52
    
    // ========== 顶部导航按钮尺寸 ==========
    /// 导航栏自定义圆形按钮（返回/关闭）
    static let navCircleButtonSize: CGFloat = 36
    /// 导航栏圆形按钮图标尺寸
    static let navCircleIconSize: CGFloat = 16
}
