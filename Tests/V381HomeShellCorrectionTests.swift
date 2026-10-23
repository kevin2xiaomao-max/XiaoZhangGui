import SwiftUI
import UIKit
import XCTest
@testable import XiaoZhangGui

/// V3.8.1 真机 UI 纠偏（线 A：Home + App 壳）单元回归测试。
///
/// - P0-1：快捷菜单展开面板前景对比度。根因是 Light 下深色面板配了
///   scheme 自适应的黑色 `.primary`；修复后前景由面板实际明暗解析，
///   本测试对「背景种类 × 明暗 scheme」全矩阵做 WCAG 对比度断言，
///   与 View 共用 `V38HomeQuickMenuPanelStyle` 同一份解析，防再次漂移。
/// - P0-2：浮动 Tab 栏底部避让的共享常量口径（总额外 inset = 60pt），
///   实际遮挡与否由 UI 测试的 frame 断言校验（见 V381HomeShellCorrectionUITests）。
final class V381HomeShellCorrectionTests: XCTestCase {

    // MARK: - P0-1 面板明暗解析（回归核心）

    func testQuickMenuPanelDarknessResolution() {
        // 浮动玻璃档恒为深色面板——这是 P0-1 的根因点：Light 下也是深色。
        XCTAssertTrue(V38HomeQuickMenuPanelStyle.isDarkPanel(kind: .floatingGlass, colorScheme: .light))
        XCTAssertTrue(V38HomeQuickMenuPanelStyle.isDarkPanel(kind: .floatingGlass, colorScheme: .dark))
        // 实色档（Reduce Transparency）与材质档随 scheme。
        XCTAssertFalse(V38HomeQuickMenuPanelStyle.isDarkPanel(kind: .opaqueSystemBackground, colorScheme: .light))
        XCTAssertTrue(V38HomeQuickMenuPanelStyle.isDarkPanel(kind: .opaqueSystemBackground, colorScheme: .dark))
        XCTAssertFalse(V38HomeQuickMenuPanelStyle.isDarkPanel(kind: .thinMaterial, colorScheme: .light))
        XCTAssertTrue(V38HomeQuickMenuPanelStyle.isDarkPanel(kind: .thinMaterial, colorScheme: .dark))
    }

    // MARK: - P0-1 前景对比度全矩阵（WCAG）

    func testQuickMenuForegroundContrastAcrossPanelMatrix() {
        let kinds: [V38HomeQuickMenuPanelStyle.PanelKind] = [.opaqueSystemBackground, .floatingGlass, .thinMaterial]
        let schemes: [ColorScheme] = [.light, .dark]
        for kind in kinds {
            for scheme in schemes {
                let bg = V38HomeQuickMenuPanelStyle.panelBackgroundUIColor(kind: kind, colorScheme: scheme)
                let primary = V38HomeQuickMenuPanelStyle.primaryForegroundUIColor(kind: kind, colorScheme: scheme)
                let secondary = V38HomeQuickMenuPanelStyle.secondaryForegroundUIColor(kind: kind, colorScheme: scheme)
                let accent = V38HomeQuickMenuPanelStyle.accentForegroundUIColor(kind: kind, colorScheme: scheme)
                let primaryRatio = contrastRatio(foreground: primary, over: bg)
                let secondaryRatio = contrastRatio(foreground: secondary, over: bg)
                let accentRatio = contrastRatio(foreground: accent, over: bg)
                // 主文字：WCAG AA 正文 4.5:1。
                XCTAssertGreaterThanOrEqual(
                    primaryRatio, 4.5,
                    "主前景对比度不足 kind=\(kind) scheme=\(scheme) ratio=\(primaryRatio)"
                )
                // 次级文字（44pt 符号按钮）与标题图标：WCAG 非文本/大文本 3:1。
                XCTAssertGreaterThanOrEqual(
                    secondaryRatio, 3.0,
                    "次级前景对比度不足 kind=\(kind) scheme=\(scheme) ratio=\(secondaryRatio)"
                )
                XCTAssertGreaterThanOrEqual(
                    accentRatio, 3.0,
                    "图标前景对比度不足 kind=\(kind) scheme=\(scheme) ratio=\(accentRatio)"
                )
            }
        }
    }

    /// 深色面板（Light 玻璃档）专项：修复前的前景是黑色 label，
    /// 对深色面板的对比度约 1.4:1；修复后白色前景必须 ≥ 10:1 量级。
    func testQuickMenuLightGlassPanelForegroundIsLight() {
        let fg = V38HomeQuickMenuPanelStyle.primaryForegroundUIColor(kind: .floatingGlass, colorScheme: .light)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        fg.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertGreaterThan((r + g + b) / 3, 0.9, "Light 深色面板的主前景必须为浅色，实际 rgb=(\(r),\(g),\(b))")
    }

    // MARK: - P0-2 共享避让常量

    func testFloatingTabBarClearanceTotalsSixtyPoints() {
        // 栏体高出系统安全区的部分（48）+ 呼吸间距（12）= 60pt 额外底部 inset，
        // 经 v32PageBottomInset 的 safeAreaInset 作用于四页根 ScrollView。
        XCTAssertEqual(V32Layout.floatingTabBarReservation, 48, accuracy: 0.5)
        XCTAssertEqual(
            V32Layout.floatingTabBarReservation + V32Layout.pageBottomBreathing, 60,
            accuracy: 0.5
        )
    }

    // MARK: - WCAG 对比度计算

    /// 前景（可带 alpha）合成到背景上后计算相对亮度对比度。
    private func contrastRatio(foreground: UIColor, over background: UIColor) -> Double {
        let fg = composited(foreground, over: background)
        let l1 = relativeLuminance(fg)
        let l2 = relativeLuminance(background)
        let (lighter, darker) = l1 >= l2 ? (l1, l2) : (l2, l1)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func composited(_ foreground: UIColor, over background: UIColor) -> UIColor {
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        foreground.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        background.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(
            red: fr * fa + br * (1 - fa),
            green: fg * fa + bg * (1 - fa),
            blue: fb * fa + bb * (1 - fa),
            alpha: 1
        )
    }

    private func relativeLuminance(_ color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
}
