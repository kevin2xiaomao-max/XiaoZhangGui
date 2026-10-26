import XCTest

/// V3.9.3 · 新界面真实模拟器验收：复合意图卡组（一键确认全部真实执行）、
/// AI 设置用量与费用区、晨报详情 Sheet。截图以 XCTAttachment 留在 xcresult，
/// CI 后可从测试产物中提取认页（不是设计图）。
final class V393SmartOperationsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning { app.terminate() }
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openAI() {
        if element("ai.input").exists { return }
        if !element("screen.home").exists {
            let homeTab = app.tabBars.buttons["首页"]
            if homeTab.waitForExistence(timeout: 5) { homeTab.tap() }
        }
        if element("v38.home.ai.openSheet").exists {
            element("v38.home.ai.openSheet").tap()
            return
        }
        let entry = element("home.ai")
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "home.ai 入口未找到")
        entry.tap()
        XCTAssertTrue(element("sheet.ai").waitForExistence(timeout: 10))
    }

    private func sendMessage(_ text: String) {
        let input = element("ai.input")
        XCTAssertTrue(input.waitForExistence(timeout: 10), "ai.input 未找到")
        input.tap()
        let tutorial = app.buttons["Continue"]
        if tutorial.waitForExistence(timeout: 1) { tutorial.tap() }
        input.typeText(text)
        let sendButton = app.buttons["ai.send"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5), "ai.send 未找到")
        XCTAssertTrue(sendButton.isHittable, "ai.send 不可点击")
        sendButton.tap()
    }

    /// 复合意图：两张卡 + 一键确认全部真实执行（按钮随后变灰，证明无待确认项残留）。
    func testCompositeGroupAndConfirmAll() {
        verifyCompositeGroupAndStamp(appearance: "light")
    }

    func testCompositeGroupAndConfirmAllDark() {
        verifyCompositeGroupAndStamp(appearance: "dark")
    }

    private func verifyCompositeGroupAndStamp(appearance: String) {
        app.terminate()
        app.launchArguments.append("v391-force-\(appearance)")
        app.launch()
        openAI()
        sendMessage("记一笔美团680，再给302送两箱怡宝")
        let group = element("ai.composite-group")
        XCTAssertTrue(group.waitForExistence(timeout: 30), "复合卡组未出现")
        let confirmAll = app.buttons["ai.composite.confirmAll"]
        XCTAssertTrue(confirmAll.waitForExistence(timeout: 10), "一键确认全部按钮未出现")
        XCTAssertTrue(confirmAll.isEnabled, "确认前按钮应可用")
        XCTAssertFalse(element("ai.action-card.recorded-stamp").exists,
                       "确认前不得出现成功印章")
        shot("v393-composite-group")
        confirmAll.tap()
        // 轮询至按钮变灰：两张卡均已执行（成功或跳过），无待确认项残留。
        let deadline = Date().addingTimeInterval(30)
        var disabled = false
        while Date() < deadline {
            if !app.buttons["ai.composite.confirmAll"].isEnabled { disabled = true; break }
            usleep(200_000)
        }
        XCTAssertTrue(disabled, "一键确认后按钮应变灰（两张卡均已处理）")
        // 确认后新增汇总消息会滚到末尾；先返回卡片，不能把屏外标记当作缺失。
        let stamp = element("ai.action-card.recorded-stamp")
        for _ in 0..<4 {
            if stamp.exists && stamp.isHittable { break }
            app.scrollViews.firstMatch.swipeDown()
        }
        shot("v400-stamp-\(appearance)")
        XCTAssertTrue(stamp.waitForExistence(timeout: 10),
                      "真实保存成功后应显示已记印章")
        let details = app.buttons["ai.action-card.details"].firstMatch
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        if details.label == "展开记录详情" { details.tap() }
        XCTAssertEqual(details.label, "收起记录详情", "成功卡必须可以展开，不能丢失记录明细")
        shot("v393-composite-confirmed")
    }

    /// AI 设置：用量与费用区（含真实模型显示与不可用声明）必须可见。
    func testUsageSectionInSettings() {
        openAI()
        let menu = app.buttons["ai.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "ai.menu 未找到")
        menu.tap()
        let settingsButton = app.buttons["AI 设置"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "AI 设置菜单项未找到")
        settingsButton.tap()
        XCTAssertTrue(element("ai.usage.section").waitForExistence(timeout: 10), "用量与费用区未出现")
        shot("v393-settings-usage")
    }

    /// 晨报详情 Sheet 可打开（UI 测试库为空库时行动区无数据属实，不强断行动区存在；
    /// 行动区构成由 V393MorningBriefActionTests 单元测试覆盖）。
    func testMorningBriefSheetOpens() {
        if !element("screen.home").exists {
            let homeTab = app.tabBars.buttons["首页"]
            if homeTab.waitForExistence(timeout: 5) { homeTab.tap() }
        }
        let card = element("v39.morningBrief.card")
        XCTAssertTrue(card.waitForExistence(timeout: 20), "晨报卡未出现")
        card.tap()
        XCTAssertTrue(app.buttons["完成"].firstMatch.waitForExistence(timeout: 10), "晨报详情 Sheet 未打开")
        shot("v393-morning-brief-sheet")
    }

    /// 全局搜索：空态范例「搜索 怡宝」直达只读本地搜索，空库返回合理空态（不写库、不出卡）。
    func testGlobalSearchEmptyState() {
        openAI()
        let chip = app.buttons["搜索 怡宝"]
        if chip.waitForExistence(timeout: 10) {
            chip.tap()
        } else {
            sendMessage("搜索 怡宝")
        }
        let empty = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '没有找到与'")).firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 30), "全局搜索空态回复未出现")
        shot("v393-global-search-empty")
    }
}
