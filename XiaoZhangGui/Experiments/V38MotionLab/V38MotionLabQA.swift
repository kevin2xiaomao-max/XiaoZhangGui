import SwiftUI

/// E·QA：V3.8 MotionLab 的 UI 测试 / CI 截图录屏专用启动参数。
///
/// 全部只在 DEBUG + UI 测试模式下生效；Release 构建中 `isMotionLabSession`
/// 恒为 false，生产启动路径、生产页面、RootView 本体均不受影响。
///
/// 启动参数（XCUITest 用 `--` 前缀形式；`xcrun simctl launch` 直启用无横线别名，
/// 避免宿主对 `--` 参数的解析歧义）：
/// - `--v38-motion-lab`：以 MotionLab 演示替代 RootView 作为 App 根视图
/// - `--v38-color-scheme light|dark`：强制浅色/深色（CI 截图用，不传则跟随系统）
/// - `--v38-reduce-motion`：模拟 Reduce Motion（动效路径取无动画分支）
/// - `--v38-reduce-transparency`：模拟 Reduce Transparency（材质取不透明回退）
///
/// Reduce Motion / Reduce Transparency 覆盖仅模拟系统设置对 PoC 动效路径的影响，
/// 真实系统级设置（设置 App 内开关）的验证仍为 NOT RUN，需真机/人工验收。
enum V38QALaunchOptions {
    private static var args: [String] { ProcessInfo.processInfo.arguments }

    private static func has(_ dashed: String, _ plain: String) -> Bool {
        let a = args
        return a.contains(dashed) || a.contains(plain)
    }

    static var isMotionLabSession: Bool {
        #if DEBUG
        let a = args
        guard a.contains("--ui-testing") || a.contains("ui-testing") else { return false }
        return has("--v38-motion-lab", "v38-motion-lab")
        #else
        return false
        #endif
    }

    static var colorScheme: ColorScheme? {
        #if DEBUG
        let a = args
        for flag in ["--v38-color-scheme", "v38-color-scheme"] {
            if let i = a.firstIndex(of: flag), a.indices.contains(i + 1) {
                switch a[i + 1].lowercased() {
                case "dark": return .dark
                case "light": return .light
                default: break
                }
            }
        }
        #endif
        return nil
    }

    static var reduceMotionOverride: Bool? {
        #if DEBUG
        if has("--v38-reduce-motion", "v38-reduce-motion") { return true }
        #endif
        return nil
    }

    static var reduceTransparencyOverride: Bool? {
        #if DEBUG
        if has("--v38-reduce-transparency", "v38-reduce-transparency") { return true }
        #endif
        return nil
    }
}

/// SwiftUI 的 `\.accessibilityReduceMotion` / `\.accessibilityReduceTransparency`
/// 是只读 KeyPath（系统值，不可经 `.environment(_:_:)` 注入；直接写会编译失败）。
/// 因此 QA 覆盖走自定义可写 EnvironmentKey；参数不存在时默认 nil，
/// 视图回退到系统真实值，生产行为不受影响。
private struct V38QAReduceMotionOverrideKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

private struct V38QAReduceTransparencyOverrideKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    var v38qaReduceMotionOverride: Bool? {
        get { self[V38QAReduceMotionOverrideKey.self] }
        set { self[V38QAReduceMotionOverrideKey.self] = newValue }
    }
    var v38qaReduceTransparencyOverride: Bool? {
        get { self[V38QAReduceTransparencyOverrideKey.self] }
        set { self[V38QAReduceTransparencyOverrideKey.self] = newValue }
    }
}

/// 仅在覆盖参数存在时改写无障碍环境值；参数不存在时保留系统值不变。
struct V38QAAccessibilityOverrides: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.v38qaReduceMotionOverride, V38QALaunchOptions.reduceMotionOverride)
            .environment(\.v38qaReduceTransparencyOverride, V38QALaunchOptions.reduceTransparencyOverride)
    }
}
