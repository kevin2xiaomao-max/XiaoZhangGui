import SwiftUI

// MARK: - V32 页面底部安全区（b27 T16 / T17）
// 目标：主 TabView / NavigationStack 下、实际会被底部浮动 Dock 覆盖的可滚动页面，
// 统一用本修饰器收口底部留白，禁止每页各写各的 padding。
//
// 边界与验证口径：
// - 不写死任何机型的 Home Indicator / safe-area / Dock 数值；
// - 优先依赖 SwiftUI safe-area 行为（safeAreaPadding 在系统安全区之上叠加）；
// - iOS 27 浮动 Tab / Dock 是否被系统完整计入安全区，必须由 T17 真机验证；
// - 若 T17 真机仍遮挡，按实际布局再修，不提前硬编码 Dock 高度；
// - Sheet / modal 不使用本修饰器——它们只使用系统自身 safe area，不计算 Dock 高度。

extension View {
    /// 在页面滚动内容底部叠加「系统安全区之上的呼吸间距」。
    /// - Parameter breathing: 设计常量 V32Layout.pageBottomBreathing（非设备测量值）
    func v32PageBottomInset(breathing: CGFloat = V32Layout.pageBottomBreathing) -> some View {
        safeAreaPadding(.bottom, breathing)
    }
}
