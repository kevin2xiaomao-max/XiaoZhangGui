import SwiftUI
import UIKit

// MARK: - V3.9 · 高级质感设计令牌（Premium / 玻璃 + 渐变 + 大数字）
//
// 方向定稿（2026-10-24 掌柜确认）：现状"太素太单调、信息太少、配色不喜欢、首页空"。
// V3.9 首页走「高级质感风」——高端金融 App 的观感：
// - 夜蓝渐变画布 + 香槟金强调（替代 V3.8 暖白/经营绿的单色系）
// - 玻璃卡片浮于渐变之上（复用 V38HomeGlassSurface 三档降级：RT 实色 / 旧系统材质）
// - 数字排版全面 Rounded + 等宽（掌柜 App 的门面是数字）
//
// V3.9 PR-F：颜色与渐变已上移到 DesignSystem 层 `V39Palette`（全 App 单源，
// 供 v371Canvas 升级与各页共用）；本文件保留 Home 侧语义别名与组件级约定。
//
// 约束（延续 V3.8 红线）：
// - 动态字体：文本用语义样式，展示型大数字由调用点 @ScaledMetric 随动
// - Reduce Motion / Reduce Transparency：玻璃走既有三档门控，动效只走 V38MotionTokens
// - 无障碍标识符契约不变（v38.home.* / home.* 全保留）

enum V39Style {
    // MARK: 配色（单源转发 V39Palette，保持 Home 侧 API 不变）

    /// 香槟金（金额/目标/上涨语义；状态色不归它管）。
    static var gold: Color { V39Palette.gold }

    /// 夜蓝（Light 深蓝 / Dark 浅蓝，同语义双值）。
    static var navy: Color { V39Palette.navy }

    /// Dark 画布渐变：夜蓝深邃（同 V39Palette.canvasGradientDark）。
    static var canvasGradient: LinearGradient { V39Palette.canvasGradientDark }

    /// Light 画布渐变：冰蓝珍珠。
    static var canvasGradientLight: LinearGradient { V39Palette.canvasGradientLight }

    /// Hero 主卡渐变（深空蓝，明暗通用，数字/金字在其上高对比）。
    static var heroGradient: LinearGradient { V39Palette.heroGradient }

    /// 涨（金）/ 跌（沿用既有告警红语义）。
    static var changeUp: Color { gold }
    static var changeDown: Color { V371.Colors.red }

    /// 来源条配色：门店 = 夜蓝、美团 = 金、其他 = 灰。
    static var sourceStore: Color { navy }
    static var sourceMeituan: Color { gold }
    static var sourceOther: Color { V371.Colors.gray }

    /// 进度比例统一夹取 [0,1]（纯函数：Hero 目标环与单测共用同一口径）。
    static func clampedProgress(numerator: Double, denominator: Double) -> Double {
        guard denominator > 0 else { return 0 }
        return min(max(numerator / denominator, 0), 1)
    }
}

// MARK: - 页面画布

/// V3.9 PR-F：v39Canvas 与升级后的 v371Canvas 同源（主题感知：
/// 壁纸/自选主题原样生效，仅默认底色升级为夜蓝/冰蓝渐变）。
/// Home 用本入口表达「V3.9 画布」语义，行为与其他 19 页完全一致。
extension View {
    func v39Canvas() -> some View { v371Canvas() }
}
