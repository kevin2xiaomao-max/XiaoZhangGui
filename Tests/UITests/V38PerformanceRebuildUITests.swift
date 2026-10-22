import XCTest

/// V3.8 重建 R4 · Performance 经营页生产级 UI 测试。
///
/// 在真实生产 App（`--ui-testing`）验证：
/// - Editorial Hero 渲染且金额为真实种子数据（美团 ¥680.00），非占位
/// - 收入分类 chip 切换 → 汇总数字随分类变化（全部 680 / 门店 0 / 美团 680）
/// - 图表周期 chip 切换（日/周/月）→ 图表保持渲染
/// - Light/Dark 截图（CI 产物）
final class V38PerformanceRebuildUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        XCTAssertTrue(
            app.otherElements["screen.home"].waitForExistence(timeout: 10),
            "Home 未出现"
        )
        openBusinessTab()
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
    }

    /// 使用 `.any` 类型匹配（Worker B 实证：玻璃/形变容器上的 identifier
    /// 可能不暴露为特定类型，用 descendants(.any) 最可靠）。
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waitForElement(_ identifier: String, timeout: TimeInterval = 10) -> Bool {
        let el = element(identifier)
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if el.exists { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return el.exists
    }

    /// 原生 TabView 在 iOS 27 以真实标签定位（对齐 smoke 测试的 P0-A 结论）。
    private func openBusinessTab() {
        let tab = app.tabBars.buttons["经营"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "经营 Tab 不存在")
        tab.tap()
        XCTAssertTrue(
            element("screen.business").waitForExistence(timeout: 10),
            "经营页未出现"
        )
    }

    /// chip 可能在折叠线以下：先滚动到可点再点。
    private func tapChip(_ identifier: String) {
        let chip = element(identifier)
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "chip 不存在：\(identifier)")
        for _ in 0..<6 where !chip.isHittable { app.swipeUp() }
        XCTAssertTrue(chip.isHittable, "chip 不可点击：\(identifier)")
        chip.tap()
    }

    /// 轮询等待金额文本变为期望值（numericText 动画期间 AX 标签可能滞后）。
    private func waitForAmount(_ identifier: String, equals expected: String, timeout: TimeInterval = 8) -> Bool {
        let el = element(identifier)
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if el.exists && el.label == expected { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return el.exists && el.label == expected
    }

    // MARK: - Hero：Editorial 大数字 + 真实金额

    func testHeroShowsRealSeedRevenue() {
        XCTAssertTrue(waitForElement("v38.performance.hero", timeout: 10), "Hero 未渲染")
        let hero = element("v38.performance.hero")
        // UITestSeed：今日一条美团营业额 680 → 本月营业额 ¥680.00（真实数据）。
        XCTAssertTrue(hero.label.contains("本月营业额"), "Hero 标签缺少标题：\(hero.label)")
        XCTAssertTrue(hero.label.contains("¥680.00"), "Hero 必须显示真实金额 ¥680.00：\(hero.label)")
        XCTAssertFalse(hero.label.contains("¥ —"), "Hero 不得显示占位金额：\(hero.label)")
    }

    // MARK: - 收入分类 chip：切换后汇总数字随分类变化

    func testSourceChipSwitchingUpdatesSummaryAmount() {
        // 初始「全部」：¥680.00
        XCTAssertTrue(
            waitForAmount("v38.performance.sourceAmount", equals: "¥680.00"),
            "全部口径汇总应为 ¥680.00，实际：\(element("v38.performance.sourceAmount").label)"
        )
        // 切到「门店」：种子无门店收入 → ¥0.00
        tapChip("v38.performance.source.store")
        XCTAssertTrue(
            waitForAmount("v38.performance.sourceAmount", equals: "¥0.00"),
            "门店汇总应为 ¥0.00，实际：\(element("v38.performance.sourceAmount").label)"
        )
        // 切到「美团」：¥680.00
        tapChip("v38.performance.source.meituan")
        XCTAssertTrue(
            waitForAmount("v38.performance.sourceAmount", equals: "¥680.00"),
            "美团汇总应为 ¥680.00，实际：\(element("v38.performance.sourceAmount").label)"
        )
        // 切回「全部」：¥680.00（口径闭环）
        tapChip("v38.performance.source.all")
        XCTAssertTrue(
            waitForAmount("v38.performance.sourceAmount", equals: "¥680.00"),
            "切回全部应为 ¥680.00，实际：\(element("v38.performance.sourceAmount").label)"
        )
    }

    // MARK: - 图表周期 chip：日/周/月切换后图表保持渲染

    func testPeriodChipSwitchingKeepsChart() {
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 10), "趋势图未渲染")
        tapChip("v38.performance.period.month")
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 5), "切到月后趋势图消失")
        tapChip("v38.performance.period.day")
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 5), "切到日后趋势图消失")
        tapChip("v38.performance.period.week")
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 5), "切回周后趋势图消失")
    }

    // MARK: - 截图（CI 产物，Light / Dark）

    func testPerformanceScreenshotLight() {
        XCTAssertTrue(waitForElement("v38.performance.hero", timeout: 10))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "v38-performance-rebuild-light"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPerformanceScreenshotDark() throws {
        // 以 Dark 外观重新启动（-AppleInterfaceStyle 为进程级参数）。
        app.terminate()
        let darkApp = XCUIApplication()
        darkApp.launchArguments = [
            "--ui-testing", "--ui-testing-id", UUID().uuidString,
            "-AppleInterfaceStyle", "Dark",
        ]
        darkApp.launch()
        app = darkApp
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        XCTAssertTrue(
            app.otherElements["screen.home"].waitForExistence(timeout: 10),
            "Dark 外观下 Home 未出现"
        )
        openBusinessTab()
        XCTAssertTrue(waitForElement("v38.performance.hero", timeout: 10), "Dark 外观下 Hero 未渲染")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "v38-performance-rebuild-dark"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
