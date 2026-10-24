import SwiftUI

// MARK: - V3.9.1 P2-E / 截图验收 · UI 测试专用外观覆盖
//
// 仅 DEBUG + UI 测试模式(--ui-testing)下生效,生产启动恒为 nil:
// - v391-force-dark:截图用深色外观(不写 UserDefaults,不污染后续测试与真实设置)。
// - v391-force-light:截图用浅色外观。
// 背景:Xcode 27 harness 下 XCUIDevice.appearance 不传导到 App 渲染(前科),
// 故深色截图必须走生产主题路径(preferredColorScheme),本覆盖即走该路径。

enum V391ScreenshotOptions {
    static var colorScheme: ColorScheme? {
        #if DEBUG
        guard UITestMode.isEnabled else { return nil }
        let args = ProcessInfo.processInfo.arguments
        if args.contains("v391-force-dark") { return .dark }
        if args.contains("v391-force-light") { return .light }
        return nil
        #else
        return nil
        #endif
    }
}
