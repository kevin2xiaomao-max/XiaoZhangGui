import XCTest
@testable import XiaoZhangGui

/// V3.9 PR-E：首页高级质感重构的契约测试。
///
/// 用户定稿方向（2026-10-24）：太素/信息少/配色不喜欢/首页空 → 高级质感风。
/// 红线：既有无障碍标识符契约（v38.home.* / home.*）与「AI 唯一入口」不变，
/// 玻璃三档降级复用 V38HomeGlassSurface，动态字体语义样式继承 PR-D。
final class V39HomeContractTests: XCTestCase {

    // MARK: - 纯函数

    func testClampedProgress() {
        XCTAssertEqual(V39Style.clampedProgress(numerator: 64000, denominator: 100000), 0.64, accuracy: 0.0001)
        XCTAssertEqual(V39Style.clampedProgress(numerator: 150000, denominator: 100000), 1, "超目标夹到 100%")
        XCTAssertEqual(V39Style.clampedProgress(numerator: -5, denominator: 100), 0, "负数夹到 0")
        XCTAssertEqual(V39Style.clampedProgress(numerator: 50, denominator: 0), 0, "零目标 = 无进度,不除零")
    }

    // MARK: - 首页结构契约（源码回归钉）

    func testHomeUsesV39SectionsAndKeepsContracts() throws {
        let home = try source("XiaoZhangGui/Features/Home/HomeView.swift")
        // V3.9 新区块就位。
        XCTAssertTrue(home.contains("V39HeroCard("), "首页必须使用 V3.9 玻璃 Hero 卡")
        XCTAssertTrue(home.contains("V39StatChip("), "首页必须有统计 chips 行(信息密度)")
        XCTAssertTrue(home.contains("V39TrendCard("), "首页必须有近7日趋势卡")
        XCTAssertTrue(home.contains("V39SourceBar("), "首页必须有收入来源占比条")
        XCTAssertTrue(home.contains(".v39Canvas()"), "首页画布必须换 V3.9 渐变(配色定稿)")
        // 既有契约不回退；快捷行已按用户 10-23 硬决定删除、V3.9 对齐 RC edb991d 承接删除，
        // 快捷记录入口改由 RootView 呈现 QuickRecordSheet，不依赖首页快捷行。
        XCTAssertFalse(home.contains("V38HomeQuickMenu"), "首页快捷行已删除，不得复活（对齐 RC edb991d）")
        XCTAssertTrue(home.contains("V38HomeAICapsule("), "AI 唯一入口保留")
        XCTAssertTrue(home.contains("V371ScrollEndMarker(identifier: V371AccessibilityID.scrollEndHome)"), "滚动终点标识保留")
    }

    func testV39SectionsKeepPinnedIdentifiersAndGlassDegradation() throws {
        let sections = try source("XiaoZhangGui/Features/Home/V39/V39HomeSections.swift")
        // Hero 标识符契约:V38HomeRebuildUITests 依赖。
        XCTAssertTrue(sections.contains("\"v38.home.hero\""), "Hero 卡必须保留 v38.home.hero 标识符")
        // 新区块标识符：趋势/来源在 V39HomeSections；chips 行在 HomeView，且为逐项标识
        //（容器标识会遮蔽子元素 AX 查询，iOS 27 实证，故不设容器标识，逐项标识即契约）。
        for id in ["v39.home.trend", "v39.home.source"] {
            XCTAssertTrue(sections.contains(id), "V3.9 新区块标识符缺失:\(id)")
        }
        let home = try source("XiaoZhangGui/Features/Home/HomeView.swift")
        XCTAssertTrue(home.contains("v39.home.chips.todo"), "chips 待办标识缺失")
        XCTAssertTrue(home.contains("v39.home.chips.overdue"), "chips 逾期标识缺失")
        // 玻璃三档降级必须复用 V38HomeGlassSurface,不得裸用材质。
        XCTAssertTrue(sections.contains("V38HomeGlassSurface"), "玻璃卡必须复用三档降级表面(RT 安全)")
        // 展示型大数字仍走调用点缩放字号(动态字体契约)。
        XCTAssertTrue(sections.contains("heroAmountSize"), "Hero 大数字必须由调用点 @ScaledMetric 随动")
    }

    func testV39StyleTokensExist() throws {
        // V3.9 PR-F:颜色单源在 DesignSystem 层 V39Palette,Home 侧 V39Style 转发。
        let style = try source("XiaoZhangGui/Features/Home/V39/V39Style.swift")
        XCTAssertTrue(style.contains("V39Palette.gold"), "V39Style 必须转发 V39Palette 单源色")
        let palette = try source("XiaoZhangGui/DesignSystem/V39/V39Palette.swift")
        for token in ["static let gold", "heroGradient", "canvasGradientDark", "canvasGradientLight"] {
            XCTAssertTrue(palette.contains(token), "V39Palette 令牌缺失:\(token)")
        }
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
