import XCTest

/// V3.9.1 截图验收:真实模拟器渲染,截图以 XCTAttachment 留在 xcresult,
/// CI 后可从测试产物中提取认页。不是设计图,不是 Figma。
/// 覆盖:首页/待办/日历(月/周)/经营/月报/AI 初始/我的页,浅色 + 深色 + AX3。
/// Widget 主屏/锁屏外观无法由 App 内 UI 测试截取,列为已知缺口(须真机/主屏核验)。
final class V391ScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        launch()
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning { app.terminate() }
    }

    private func launch(extraArgs: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-id", UUID().uuidString] + extraArgs
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    }

    private func relaunch(extraArgs: [String] = []) {
        if app.state != .notRunning { app.terminate() }
        launch(extraArgs: extraArgs)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    // 截图用例不做时序断言:慢速 runner 上首启可达 30 秒级,等待放宽到 30 秒,
    // 失败仍按元素缺失如实报错,不是跳过。
    private func waitFor(_ identifier: String, timeout: TimeInterval = 30) {
        XCTAssertTrue(element(identifier).waitForExistence(timeout: timeout),
                      "元素未出现: \(identifier)")
    }

    /// 月报 Sheet 关闭:必须点工具栏「关闭」按钮。实证(run 40093721488):
    /// app.swipeDown() 会被 Sheet 内 ScrollView 截获,Sheet 不关闭,
    /// 随后 Tab 点击被 Sheet 吞掉、目标页永不出现。
    private func dismissReportSheet() {
        let close = app.buttons["关闭"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10), "月报 Sheet 关闭按钮未出现")
        close.tap()
        waitFor("screen.business")
    }

    private func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func goTab(_ label: String, screen: String) {
        let tab = app.tabBars.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 30), "Tab 未出现: \(label)")
        tab.tap()
        waitFor(screen)
        Thread.sleep(forTimeInterval: 0.5)
    }

    // MARK: - 浅色

    func testScreenshotsLight() {
        waitFor("screen.home")
        shot("v391-home-light")
        goTab("待办", screen: "screen.todo")
        shot("v391-todo-light")
        goTab("日历", screen: "screen.calendar")
        shot("v391-calendar-month-light")
        if element("v38.schedule.density.week").exists {
            element("v38.schedule.density.week").tap()
            Thread.sleep(forTimeInterval: 0.5)
            shot("v391-calendar-week-light")
            element("v38.schedule.density.month").tap()
        }
        goTab("经营", screen: "screen.business")
        shot("v391-business-light")
        // 月报:经营页「更多」菜单 → 月度报表。
        if element("v39.performance.moreMenu").exists {
            element("v39.performance.moreMenu").tap()
            let reportButton = app.descendants(matching: .any).matching(identifier: "v39.performance.monthlyReport").firstMatch
            if reportButton.waitForExistence(timeout: 5) {
                reportButton.tap()
                waitFor("v39.report.sheet")
                Thread.sleep(forTimeInterval: 0.5)
                shot("v391-report-light")
                dismissReportSheet()
            }
        }
        goTab("首页", screen: "screen.home")
        // 我的页在 AI 之前:AI Sheet 无工具栏关闭按钮,swipeDown 也不可靠,
        // 故 AI 截图放最后,拍完即结束用例、不再返回。
        element("home.profile").tap()
        waitFor("screen.profile")
        shot("v391-profile-light")
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 10), "我的页返回按钮未出现")
        back.tap()
        waitFor("screen.home")
        element("v38.home.ai.openSheet").tap()
        XCTAssertTrue(element("sheet.ai").waitForExistence(timeout: 30)
                      || element("ai.input").waitForExistence(timeout: 30), "AI Sheet 未打开")
        shot("v391-ai-initial-light")
    }

    // MARK: - 深色(生产主题路径覆盖,非 XCUIDevice.appearance)

    func testScreenshotsDark() {
        relaunch(extraArgs: ["v391-force-dark"])
        waitFor("screen.home")
        shot("v391-home-dark")
        goTab("经营", screen: "screen.business")
        shot("v391-business-dark")
        if element("v39.performance.moreMenu").exists {
            element("v39.performance.moreMenu").tap()
            let reportButton = app.descendants(matching: .any).matching(identifier: "v39.performance.monthlyReport").firstMatch
            if reportButton.waitForExistence(timeout: 5) {
                reportButton.tap()
                waitFor("v39.report.sheet")
                Thread.sleep(forTimeInterval: 0.5)
                shot("v391-report-dark")
                dismissReportSheet()
            }
        }
        goTab("待办", screen: "screen.todo")
        shot("v391-todo-dark")
    }

    // MARK: - AX3 超大字体(注入机制已在字体截图轮验证生效)

    func testScreenshotsAX3() {
        relaunch(extraArgs: ["-UIPreferredContentSizeCategoryName",
                             "UICTContentSizeCategoryAccessibilityXXXL"])
        waitFor("screen.home")
        shot("v391-home-ax3")
        goTab("日历", screen: "screen.calendar")
        shot("v391-calendar-ax3")
        goTab("经营", screen: "screen.business")
        shot("v391-business-ax3")
    }
}
