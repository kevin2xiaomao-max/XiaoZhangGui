import SwiftUI
import UIKit

/// V3.8 三档材质门控（纯函数）。
///
/// 隔离声明（Debug-only）：本文件不被任何生产 View 引用；`resolve(_:)` 为纯逻辑，
/// 可在 XCTest 中直接覆盖全部 2×2 门控矩阵。实现语义与 MotionLab PoC
/// `V38MotionLabSurface` 的三档分支一致（glass → ultraThinMaterial → 不透明回退），
/// 只做语义收敛、不修改 PoC 文件。
enum V38CapabilityGate {

    /// 材质三档：iOS 26+ glassEffect / 旧系统 ultraThinMaterial / Reduce Transparency 不透明回退。
    enum MaterialTier: Equatable, Hashable {
        case glass
        case ultraThin
        case opaque
    }

    /// 门控输入：系统版本可用性（编译期 SDK 用 `#available` 判定，见 `current`）与用户透明度偏好。
    struct Capabilities: Equatable, Hashable {
        /// glassEffect（iOS 26+）是否可用。
        var glassEffectAvailable: Bool
        /// 用户是否开启了 Reduce Transparency。
        var reduceTransparency: Bool
    }

    /// 纯函数：输入能力 → 输出材质档。规则：
    /// 1. Reduce Transparency 开启 → 一律 `.opaque`（不透明回退）；
    /// 2. 否则 iOS 26+ 可用 → `.glass`；
    /// 3. 旧系统 → `.ultraThin`。
    static func resolve(_ capabilities: Capabilities) -> MaterialTier {
        if capabilities.reduceTransparency { return .opaque }
        return capabilities.glassEffectAvailable ? .glass : .ultraThin
    }

    /// 当前运行时的能力快照（读取 `UIAccessibility` 真值；glassEffect 可用性由 `#available` 判定）。
    static var current: Capabilities {
        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled
        if #available(iOS 26.0, *) {
            return Capabilities(glassEffectAvailable: true, reduceTransparency: reduceTransparency)
        } else {
            return Capabilities(glassEffectAvailable: false, reduceTransparency: reduceTransparency)
        }
    }
}
