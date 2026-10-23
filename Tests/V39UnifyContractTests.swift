import XCTest
@testable import XiaoZhangGui

/// V3.9 PR-F：设计语言统一(全 App)契约测试。
///
/// 统一手段:升级共享组件单点生效——v371Canvas(默认底色→V39 渐变,主题系统保留)、
/// SectionHeader(金色签名竖条)、经营页 Hero(与首页同语言深空蓝卡)。
final class V39UnifyContractTests: XCTestCase {

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    // MARK: - 画布升级 + 主题系统兼容(红线)

    func testCanvasUpgradesDefaultOnlyAndKeepsThemes() throws {
        let design = try source("XiaoZhangGui/DesignSystem/V371/V371DesignSystem.swift")
        // 默认底色升级为 V39 渐变。
        XCTAssertTrue(design.contains("V39Palette.canvasGradientDark"), "默认 Dark 底色必须是 V39 夜蓝渐变")
        XCTAssertTrue(design.contains("V39Palette.canvasGradientLight"), "默认 Light 底色必须是 V39 冰蓝渐变")
        // 红线:壁纸与自选主题分支原样保留。
        XCTAssertTrue(design.contains("themeStore.wallpaper.isEnabled"), "壁纸能力必须保留(V3.7.1 稳定能力)")
        XCTAssertTrue(design.contains("themeStore.backgroundTheme == BackgroundTheme.default"),
                      "仅默认背景升级;自选主题(纯净白/鼠尾草/雾霾蓝/中性灰/柔紫)必须原样生效")
        XCTAssertTrue(design.contains("themeStore.backgroundPalette.pageBG"), "非默认主题走原 palette 路径")
    }

    func testV39CanvasAliasSameSource() throws {
        let style = try source("XiaoZhangGui/Features/Home/V39/V39Style.swift")
        XCTAssertTrue(
            style.contains("func v39Canvas() -> some View { v371Canvas() }"),
            "首页 v39Canvas 必须与升级后的 v371Canvas 同源(全 App 行为一致)"
        )
    }

    // MARK: - SectionHeader 金色签名(全 App)

    func testSectionHeaderHasGoldTick() throws {
        let primitives = try source("XiaoZhangGui/DesignSystem/V371/V371Primitives.swift")
        XCTAssertTrue(primitives.contains("V39Palette.headerTick"), "SectionHeader 必须带金色签名竖条")
        XCTAssertTrue(primitives.contains(".accessibilityHidden(true)"), "装饰竖条必须无障碍隐藏")
        XCTAssertFalse(primitives.contains("children: .combine)"), "SectionHeader 不得 combine(会吞 trailing 元素标识符)")
    }

    func testHomeSectionHeaderMatchesGlobalTick() throws {
        let homeStyle = try source("XiaoZhangGui/Features/Home/V38/V38HomeStyle.swift")
        XCTAssertTrue(homeStyle.contains("V39Palette.headerTick"), "首页 SectionHeader 必须同款金条(与全 App 一致)")
    }

    // MARK: - 经营页 Hero 同语言

    func testPerformanceHeroUsesV39CardAndKeepsIdentifier() throws {
        let perf = try source("XiaoZhangGui/Features/Performance/PerformanceView.swift")
        XCTAssertTrue(perf.contains("V39Palette.heroGradient"), "经营页 Hero 必须用 V39 深空蓝渐变(与首页同语言)")
        XCTAssertTrue(perf.contains("V39Palette.heroStroke"), "经营页 Hero 必须带金色包边")
        XCTAssertTrue(perf.contains("\"v38.performance.hero\""), "Hero 无障碍标识符契约不变")
        XCTAssertTrue(perf.contains("V39Style.changeUp"), "环比徽标必须用 V39 语义色(涨金/跌红)")
    }

    // MARK: - 纯函数回归(随单源迁移保持)

    func testClampedProgressStillSame() {
        XCTAssertEqual(V39Style.clampedProgress(numerator: 1, denominator: 2), 0.5, accuracy: 0.0001)
        XCTAssertEqual(V39Style.clampedProgress(numerator: 3, denominator: 2), 1)
        XCTAssertEqual(V39Style.clampedProgress(numerator: 1, denominator: 0), 0)
    }
}
