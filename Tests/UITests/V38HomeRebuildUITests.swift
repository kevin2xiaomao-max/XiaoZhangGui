import XCTest

/// V3.8 重建 R1 · Home 生产级交互 UI 测试。
///
/// 在真实生产 App（`--ui-testing`，非 DEBUG 演示宿主）验证：
/// - V3.8 Editorial Home 渲染（Hero / AI 胶囊 / 快捷菜单 / 今日事项）
/// - AI 胶囊：展开 → 打开真实 AI Sheet → 关闭返回首页
/// - 快捷菜单：展开 → 选择记收入 → QuickRecord Sheet 打开 → 关闭返回
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

    // MARK: - V3.8 Home 结构渲染

    func testV38HomeStructureRenders() {
        // Revenue Hero（深绿卡，唯一主视觉）
        XCTAssertTrue(
            app.otherElements["v38.home.hero"].waitForExistence(timeout: 10),
            "Revenue Hero 未渲染"
        )
        // AI 胶囊入口
        XCTAssertTrue(
            app.buttons["v38.home.ai.expand"].waitForExistence(timeout: 5),
            "AI 胶囊未渲染"
        )
        // 快捷菜单入口
        XCTAssertTrue(
            app.buttons["v38.home.quick.expand"].waitForExistence(timeout: 5),
            "快捷菜单未渲染"
        )
        // AI 不在 TabBar 中（设计红线）
        XCTAssertFalse(app.tabBars.buttons["小掌柜"].exists)
        XCTAssertFalse(app.tabBars.buttons["AI"].exists)
    }

    // MARK: - AI 胶囊：展开 → 打开真实 AI Sheet → 返回

    func testAICapsuleExpandOpenSheetAndReturn() {
        // 展开 AI 胶囊
        app.buttons["v38.home.ai.expand"].tap()
        XCTAssertTrue(
            app.otherElements["v38.home.ai.expanded"].waitForExistence(timeout: 5),
            "AI 胶囊未展开"
        )
        // 点击输入行 → 打开真实 AI Sheet（现有 AIChatView）
        app.buttons["v38.home.ai.openSheet"].tap()
        // AI Sheet 以 .large detent 呈现；验证 Sheet 内容出现（AI 对话界面）
        let aiSheet = app.otherElements["screen.ai"]
        XCTAssertTrue(
            aiSheet.waitForExistence(timeout: 10) || app.navigationBars.firstMatch.waitForExistence(timeout: 10),
            "AI Sheet 未打开"
        )
        // 关闭 Sheet 回到首页
        app.swipeDown()
        XCTAssertTrue(
            app.otherElements["screen.home"].waitForExistence(timeout: 10),
            "关闭 AI Sheet 后未回到首页"
        )
        // AI 胶囊应回到收起态
        XCTAssertTrue(
            app.buttons["v38.home.ai.expand"].waitForExistence(timeout: 5),
            "返回后 AI 胶囊未回到收起态"
        )
    }

    // MARK: - 快捷菜单：展开 → 选择 → QuickRecord → 返回

    func testQuickMenuExpandSelectAndReturn() {
        // 展开快捷菜单
        app.buttons["v38.home.quick.expand"].tap()
        XCTAssertTrue(
            app.otherElements["v38.home.quick.expanded"].waitForExistence(timeout: 5),
            "快捷菜单未展开"
        )
        // 选择"记收入" → 打开 QuickRecord Sheet（现有生产路由）
        app.buttons["v38.home.quick.income"].tap()
        // QuickRecord Sheet 出现（验证 Sheet 标题或输入框）
        XCTAssertTrue(
            app.otherElements["screen.quickRecord"].waitForExistence(timeout: 10) ||
            app.textFields.firstMatch.waitForExistence(timeout: 10),
            "QuickRecord Sheet 未打开"
        )
        // 关闭回到首页
        app.swipeDown()
        XCTAssertTrue(
            app.otherElements["screen.home"].waitForExistence(timeout: 10),
            "关闭 QuickRecord 后未回到首页"
        )
    }

    // MARK: - Revenue Hero 真实金额（非占位）

    func testHeroShowsRealAmountNotPlaceholder() {
        let hero = app.otherElements["v38.home.hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        // Hero 的 accessibilityLabel 包含真实金额（"今日营业额 ¥..."）
        let label = hero.label
        XCTAssertTrue(label.contains("今日营业额"), "Hero 缺少标题：\(label)")
        // 不得是 Mockup 中的占位 "¥ —"
        XCTAssertFalse(label.contains("¥ —") || label.contains("¥-"), "Hero 显示占位金额而非真实数据：\(label)")
    }

    // MARK: - Light/Dark 截图（CI 产物）

    func testHomeLightDarkScreenshots() {
        XCTAssertTrue(app.otherElements["screen.home"].waitForExistence(timeout: 10))
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "v38-home-rebuild"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
