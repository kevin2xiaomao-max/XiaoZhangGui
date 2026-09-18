import SwiftUI
import UIKit

// MARK: - V3.3 Lite · 全屏收款码亮度守卫
//
// 设计目标（不承诺强制 kill 时即时回调）：
// 1. 进入全屏：保存进入前亮度，临时拉高到便于扫码的亮度
// 2. 正常退出：恢复保存值
// 3. scenePhase 进入 inactive/background（控制中心 / 来电 / 切后台）：立即恢复
// 4. 异常终止保护：进入时在 UserDefaults 留下「提升中 + 保存亮度」标记；
//    App 下次启动由 applyStartupRecovery() 检查并恢复，再清除标记。
//    iOS 不保证强杀进程执行退出回调，因此恢复保护放在下次启动而非依赖 onDisappear。

/// 亮度控制抽象（UIScreen.main 生产实现；测试注入替身）
protocol BrightnessControlling: AnyObject {
    var brightness: CGFloat { get set }
}

extension UIScreen: BrightnessControlling {}

@MainActor
final class PaymentCodeBrightnessGuard {

    /// 全屏展示时的目标亮度（0.95：足够扫码又避免长时间 100% 刺眼/发热）
    static let presentationBrightness: CGFloat = 0.95

    static let activeFlagKey = "xzg.paymentCode.brightness.active.v1"
    static let savedBrightnessKey = "xzg.paymentCode.brightness.saved.v1"

    private let controller: any BrightnessControlling
    private let defaults: UserDefaults
    private var savedBrightness: CGFloat?
    private var isActive = false

    init(controller: (any BrightnessControlling)? = nil,
         defaults: UserDefaults = .standard) {
        self.controller = controller ?? UIScreen.main
        self.defaults = defaults
    }

    /// 进入全屏：先落「恢复保护」标记，再拉高亮度。重复进入不覆盖原始保存值。
    func begin(targetLevel: CGFloat = PaymentCodeBrightnessGuard.presentationBrightness) {
        guard !isActive else { return }
        let current = controller.brightness
        savedBrightness = current
        defaults.set(Double(current), forKey: Self.savedBrightnessKey)
        defaults.set(true, forKey: Self.activeFlagKey)
        isActive = true
        controller.brightness = targetLevel
    }

    /// 退出全屏 / 进入后台：恢复进入前亮度并清除标记。未进入时调用无副作用。
    func end() {
        guard isActive else { return }
        if let savedBrightness {
            controller.brightness = savedBrightness
        }
        savedBrightness = nil
        isActive = false
        defaults.removeObject(forKey: Self.activeFlagKey)
        defaults.removeObject(forKey: Self.savedBrightnessKey)
    }

    /// App 启动恢复保护：上次异常终止遗留「提升中」标记时恢复合理亮度。
    /// - 标记不存在：完全不动当前亮度
    /// - 保存值合法（0...1）：恢复
    /// - 保存值非法：只清标记，不写屏幕
    /// 无论哪种情况，处理完都清除遗留标记（只执行一次）。
    static func applyStartupRecovery(controller: (any BrightnessControlling)? = nil,
                                     defaults: UserDefaults = .standard) {
        let screen = controller ?? UIScreen.main
        guard defaults.bool(forKey: activeFlagKey) else { return }

        if let saved = defaults.object(forKey: savedBrightnessKey) as? Double,
           (0.0...1.0).contains(saved) {
            screen.brightness = CGFloat(saved)
        }
        defaults.removeObject(forKey: activeFlagKey)
        defaults.removeObject(forKey: savedBrightnessKey)
    }
}
