import XCTest

/// V3.8 重建 R1 · Home 生产级交互 UI 测试。
///
/// 在真实生产 App（`--ui-testing`，非 DEBUG 演示宿主）验证：
/// - V3.8 Editorial Home 渲染（Hero / AI 胶囊 / 今日事项）
/// - AI 胶囊：展开 → 打开真实 AI Sheet → 关闭返回首页
/// - 首页无重复入口（2026-10-23 用户确认减法）：「快速记一笔 / 写备忘」
///   快捷行已整行删除，区块顺序固定为 日期 → 营业额 → 问小掌柜 → 今日事项
/// - Revenue Hero 显示真实金额（非演示占位）
final class V38HomeRebuildUITests: XCTestCase {
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

    // MARK: - V3.8 Home 结构渲染

    func testV38HomeStructureRenders() {
        // Revenue Hero（深绿卡，唯一主视觉）
        XCTAssertTrue(
            waitForElement("v38.home.hero", timeout: 10),
            "Revenue Hero 未渲染"
        )
        // AI 胶囊入口(单步直达)
        XCTAssertTrue(
            waitForElement("v38.home.ai.openSheet", timeout: 5),
            "AI 胶囊未渲染"
        )
        // AI 不在 TabBar 中（设计红线）
        XCTAssertFalse(app.tabBars.buttons["小掌柜"].exists)
        XCTAssertFalse(app.tabBars.buttons["AI"].exists)
    }

    // MARK: - AI 胶囊：一次点击直接打开真实 AI Sheet → 返回(V3.9.1 P1-5)

    func testAICapsuleOpensSheetDirectlyAndReturns() {
        // 单步直达：不得再有展开中间态(collapse 不得出现)
        XCTAssertFalse(
            element("v38.home.ai.collapse").exists,
            "AI 胶囊不得再有展开中间态"
        )
        // 一次点击 → 打开真实 AI Sheet（现有 AIChatView）
        element("v38.home.ai.openSheet").tap()
        // AI Sheet 以 .large detent 呈现；验证 Sheet 内容出现（sheet.ai）
        XCTAssertTrue(
            waitForElement("sheet.ai", timeout: 10) || app.navigationBars.firstMatch.waitForExistence(timeout: 10),
            "AI Sheet 未打开"
        )
        // 关闭 Sheet 回到首页
        app.swipeDown()
        XCTAssertTrue(
            waitForElement("screen.home", timeout: 10),
            "关闭 AI Sheet 后未回到首页"
        )
        // AI 胶囊应仍在首页(单步入口)
        XCTAssertTrue(
            waitForElement("v38.home.ai.openSheet", timeout: 5),
            "返回后 AI 胶囊入口未回到首页"
        )
    }

    // MARK: - 首页无重复入口 + 区块顺序固定（2026-10-23 减法回归）

    func testHomeHasNoDuplicateQuickEntriesAndFixedSectionOrder() {
        // 被删入口必须不存在：快捷菜单胶囊、独立「写备忘」按钮、展开面板。
        XCTAssertFalse(
            element("v38.home.quick.expand").exists,
            "快捷菜单胶囊已被用户确认删除，不得在首页出现"
        )
        XCTAssertFalse(
            element("v38.home.quick.collapse").exists,
            "快捷菜单展开面板不得在首页出现"
        )
        XCTAssertFalse(
            element("home.quickRecord").exists,
            "独立「写备忘」按钮已被用户确认删除，不得在首页出现"
        )
        XCTAssertFalse(
            app.staticTexts["快速记一笔"].exists,
            "「快速记一笔」标题不得在首页出现"
        )
        XCTAssertFalse(
            app.staticTexts["快速操作"].exists,
            "「快速操作」面板标题不得在首页出现"
        )

        // 固定顺序：日期 Header → 今日经营 Hero → 问小掌柜 → 今日事项。
        let dateLine = app.staticTexts["今日经营一览"]
        XCTAssertTrue(dateLine.waitForExistence(timeout: 10), "日期 Header 未渲染")
        let hero = element("v38.home.hero")
        XCTAssertTrue(waitForElement("v38.home.hero", timeout: 5), "营业额 Hero 未渲染")
        let ai = element("v38.home.ai.openSheet")
        XCTAssertTrue(waitForElement("v38.home.ai.openSheet", timeout: 5), "AI 胶囊未渲染")
        let mattersHeader = app.staticTexts["今日事项"]
        XCTAssertTrue(mattersHeader.waitForExistence(timeout: 5), "今日事项标题未渲染")
        XCTAssertLessThan(dateLine.frame.minY, hero.frame.minY, "日期 Header 必须在营业额 Hero 之上")
        XCTAssertLessThan(hero.frame.minY, ai.frame.minY, "营业额 Hero 必须在问小掌柜之上")
        XCTAssertLessThan(ai.frame.minY, mattersHeader.frame.minY, "问小掌柜必须在今日事项之上")
    }

    // MARK: - Revenue Hero 真实金额（非占位）

    func testHeroShowsRealAmountNotPlaceholder() {
        let hero = element("v38.home.hero")
        XCTAssertTrue(waitForElement("v38.home.hero", timeout: 10))
        // Hero 的 accessibilityLabel 包含真实金额（"今日营业额 ¥..."）
        let label = hero.label
        // V3.9 新 Hero 文案更紧凑（“今日 ¥680”），但本月/今日金额与目标数据点齐全；
        // 断言数据点本身，而非旧 Hero 的完整措辞。
        XCTAssertTrue(label.contains("本月营业额"), "Hero 缺少本月营业额标题：\(label)")
        XCTAssertTrue(label.contains("今日 ¥"), "Hero 缺少今日营业额：\(label)")
        // 不得是 Mockup 中的占位 "¥ —"
        XCTAssertFalse(label.contains("¥ —") || label.contains("¥-"), "Hero 显示占位金额而非真实数据：\(label)")
    }

    // MARK: - Light/Dark 截图（CI 产物）

    func testHomeLightDarkScreenshots() {
        XCTAssertTrue(waitForElement("screen.home", timeout: 10))
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "v38-home-rebuild"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
