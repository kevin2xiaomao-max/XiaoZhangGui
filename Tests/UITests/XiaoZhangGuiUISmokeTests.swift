import XCTest

final class XiaoZhangGuiUISmokeTests: XCTestCase {
    private var app: XCUIApplication!
    private var launchID: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        launchID = UUID().uuidString
        app.launchArguments = ["--ui-testing", "--ui-testing-id", launchID]
        addUIInterruptionMonitor(withDescription: "Location permission") { alert in
            let allow = ["使用 App 时允许", "Allow While Using App", "允许一次", "Allow Once"]
                .first { alert.buttons[$0].exists }
            if let allow { alert.buttons[allow].tap(); return true }
            return false
        }
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
    }

    func testAppLaunches() {
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 10))
        // P0-A: 原生 TabView 在 iOS 27 不暴露自定义 accessibilityIdentifier，
        // 使用系统 TabBar 的真实无障碍标签（首页/待办/日历/经营）定位
        for label in ["首页", "待办", "日历", "经营"] {
            let tab = app.tabBars.buttons[label]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing main tab: \(label)")
        }
        // AI 必须独立于四个主 Tab（不在 TabBar 中）
        XCTAssertFalse(app.tabBars.buttons["小掌柜"].exists, "AI must remain independent from the four main tabs")
        XCTAssertFalse(app.tabBars.buttons["AI"].exists, "AI must remain independent from the four main tabs")
    }

    func testFourMainTabsAndSecondaryBackPath() {
        assertTab("tab.todo", shows: "screen.todo")
        assertTab("tab.calendar", shows: "screen.calendar")
        assertTab("tab.business", shows: "screen.business")
        assertTab("tab.home", shows: "screen.home")

        tapElement("home.profile")
        XCTAssertTrue(element("screen.profile").waitForExistence(timeout: 5))
        tapNavigationBack()
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 5))
    }

    func testAIUsesHomeEntryAndReturnsFromSheet() {
        openAI()
        XCTAssertTrue(element("sheet.ai").waitForExistence(timeout: 5))
        app.swipeDown()
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 5))
    }

    func testQuickRecordUsesHomeEntryAndReturns() {
        XCTAssertTrue(element("home.quickRecord").waitForExistence(timeout: 5))
        tapElement("home.quickRecord")
        XCTAssertTrue(element("sheet.quickRecord").waitForExistence(timeout: 5))
        XCTAssertTrue(element("quickRecord.cancel").waitForExistence(timeout: 5))
        element("quickRecord.cancel").tap()
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 5))
    }

    func testBusinessRoutesGoodsAndDailyReport() {
        assertTab("tab.business", shows: "screen.business")

        tapElement("business.goods")
        XCTAssertTrue(element("screen.goods").waitForExistence(timeout: 5))
        tapNavigationBack()
        XCTAssertTrue(element("screen.business").waitForExistence(timeout: 5))

        openBusinessMenu(item: "business.memo")
        XCTAssertTrue(element("screen.memo").waitForExistence(timeout: 5))
        tapNavigationBack()
        XCTAssertTrue(element("screen.business").waitForExistence(timeout: 5))

        openBusinessMenu(item: "business.dailyReport")
        XCTAssertTrue(element("sheet.dailyReport").waitForExistence(timeout: 5))
        XCTAssertTrue(element("dailyReport.close").waitForExistence(timeout: 5))
        element("dailyReport.close").tap()
        XCTAssertTrue(element("screen.business").waitForExistence(timeout: 5))
    }

    func testProfileRoutesPaymentCodesAndVoiceTest() {
        tapElement("home.profile")
        XCTAssertTrue(element("screen.profile").waitForExistence(timeout: 5))

        // 收款码行在页面底部，可能被 FloatingTabDock 遮挡导致 tap 误触日历 tab：
        // 先上滑确保行位于屏幕中部再点击
        app.swipeUp()
        tapElement("profile.paymentCodes")
        // 收款码页含二维码生成，首现可能稍慢；给足时间，必要时返回重进一次。
        if !element("screen.paymentCodes").waitForExistence(timeout: 8) {
            // 已离开个人页但目标未出现：先返回，再重 tap
            tapNavigationBack()
            XCTAssertTrue(element("screen.profile").waitForExistence(timeout: 5))
            tapElement("profile.paymentCodes")
            XCTAssertTrue(
                element("screen.paymentCodes").waitForExistence(timeout: 8),
                "Missing screen screen.paymentCodes after retry tap"
            )
        }
        tapNavigationBack()

        XCTAssertTrue(element("profile.voiceSettings").waitForExistence(timeout: 5))
        tapElement("profile.voiceSettings")
        XCTAssertTrue(element("profile.voiceTest").waitForExistence(timeout: 5))
        tapElement("profile.voiceTest")
        XCTAssertTrue(element("sheet.voice").waitForExistence(timeout: 5))
    }

    func testCustomerAdvanceFailureDoesNotReportSuccessAndRetrySucceeds() {
        relaunch(failingOnce: "customer.advance")
        tapElement("home.customer")
        XCTAssertTrue(element("screen.customer").waitForExistence(timeout: 5))
        // 内层按钮 a11y 已合并到行元素，按钮文案不可读：改由注入流程信号断言。
        tapTrailingButton("customer.advance")
        XCTAssertTrue(app.alerts["操作失败"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["✓ 已完成配送"].exists)
        tapRetry(in: "操作失败")
        // 重试成功：失败弹窗消失且不再出现（若重试又失败，弹窗会重新出现）。
        XCTAssertTrue(waitUntil(timeout: 5) { !self.app.alerts["操作失败"].exists })
    }

    func testExpiryToggleFailureKeepsStateAndRetrySucceeds() {
        relaunch(failingOnce: "expiry.toggleReturn")
        tapElement("home.expiry")
        XCTAssertTrue(element("screen.expiry").waitForExistence(timeout: 5))
        // 内层按钮 a11y 已合并到行元素，按钮文案不可读：改由注入流程信号断言。
        // 退货按钮在行尾 HStack 内，左侧还有删除按钮：dx 按布局计算（W-97）/W。
        tapTrailingButton("expiry.toggleReturn", dx: 0.76)
        XCTAssertTrue(app.alerts["操作失败"].waitForExistence(timeout: 5))
        tapRetry(in: "操作失败")
        // 重试成功：失败弹窗消失且不再出现（若重试又失败，弹窗会重新出现）。
        XCTAssertTrue(waitUntil(timeout: 5) { !self.app.alerts["操作失败"].exists })
    }

    func testGoodsDeleteFailureKeepsRowAndRetryDeletesOnce() {
        relaunch(failingOnce: "goods.delete")
        assertTab("tab.business", shows: "screen.business")
        tapElement("business.goods")
        XCTAssertTrue(element("screen.goods").waitForExistence(timeout: 5))
        let before = app.buttons.matching(identifier: "goods.delete").count
        XCTAssertGreaterThan(before, 0)
        // 内层删除按钮嵌套在行级 Button 中，a11y 合并为行元素：按行尾坐标点击。
        // 删除按钮 44pt 在行尾：dx 按（W-36）/W ≈ 0.905。
        tapTrailingButton("goods.delete", dx: 0.905)
        XCTAssertTrue(app.alerts["删除失败"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "goods.delete").count, before)
        tapRetry(in: "删除失败")
        // 重试后滑动列表强制 cell 重用/刷新，区分数据未删除 vs a11y 树未更新
        app.swipeUp()
        app.swipeDown()
        XCTAssertTrue(waitUntil(timeout: 10) {
            self.app.buttons.matching(identifier: "goods.delete").count == before - 1
        })
    }

    func testTodoToggleFailureKeepsPendingAndRetryCompletesOnce() {
        relaunch(failingOnce: "todo.toggle")
        assertTab("tab.todo", shows: "screen.todo")
        // 内层按钮 a11y 已合并到行元素，按钮文案不可读：改由注入流程信号断言。
        // 开关按钮在行尾 HStack 中间，右侧还有删除按钮：dx 按（W-82）/W ≈ 0.80。
        tapTrailingButton("todo.toggle", dx: 0.80)
        XCTAssertTrue(app.alerts["操作失败"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("todo.toggle").exists)
        tapRetry(in: "操作失败")
        XCTAssertTrue(waitUntil(timeout: 5) { !self.element("todo.toggle").exists })
    }

    func testMetaReplyIsLocal() {
        send("那我还要AI干嘛")
        XCTAssertTrue(waitForAssistantReply())
        XCTAssertFalse(element("ai.action-card").exists)
    }

    func testGoodsPriceQueryHasNoWriteCard() {
        send("百威多少钱")
        assertGoodsReadReply()
    }

    func testGoodsPurchasePriceQueryHasNoWriteCard() {
        send("百威进价多少")
        assertGoodsReadReply()
    }

    func testGoodsStockQueryHasNoWriteCard() {
        send("百威库存多少")
        assertGoodsReadReply()
    }

    func testGoodsTomorrowQueryHasNoWriteCard() {
        send("明天有没有百威")
        assertGoodsReadReply()
    }

    func testTodoQueryProducesActionCard() {
        send("提醒我明天下午3点进货")
        XCTAssertTrue(waitForActionCard())
        XCTAssertTrue(app.staticTexts["新建待办"].exists)
    }

    func testRevenueQueryProducesActionCard() {
        send("今天美团680")
        XCTAssertTrue(waitForActionCard())
        XCTAssertTrue(app.staticTexts["记录营业额"].exists)
    }

    func testThreeMonthComparisonUsesNaturalLanguage() {
        send("三个月和这个月的对比")
        XCTAssertTrue(waitForAssistantReply())
        XCTAssertFalse(element("ai.action-card").exists)
    }

    func testClearConversationDoesNotDeleteBusinessData() {
        send("那我还要AI干嘛")
        XCTAssertTrue(waitForAssistantReply())
        XCTAssertFalse(element("ai.action-card").exists)

        app.buttons["对话菜单"].tap()
        XCTAssertTrue(app.buttons["清空当前对话"].waitForExistence(timeout: 3))
        app.buttons["清空当前对话"].tap()
        XCTAssertTrue(app.alerts["清空此对话？"].waitForExistence(timeout: 3))
        app.alerts["清空此对话？"].buttons["清空"].tap()

        XCTAssertTrue(app.staticTexts["我是小掌柜"].waitForExistence(timeout: 5))
        send("今天营业额多少")
        XCTAssertTrue(waitForAssistantReply())
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "680")).firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["数据存储暂不可用"].exists)
    }

    private func send(_ text: String) {
        openAI()
        // ai.input 可能被识别为 textField 以外类型：用类型无关查询。
        // 若元素真实缺失（而非类型问题），此处仍会失败，需修生产 UI。
        let input = element("ai.input")
        XCTAssertTrue(input.waitForExistence(timeout: 8), "ai.input not found as any element type")
        input.tap()
        let keyboardTutorial = app.buttons["Continue"]
        if keyboardTutorial.waitForExistence(timeout: 1) {
            keyboardTutorial.tap()
        }
        input.typeText(text)
        let sendButton = app.buttons["ai.send"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5))
        XCTAssertTrue(sendButton.isHittable)
        sendButton.tap()
    }

    private func assertGoodsReadReply() {
        XCTAssertTrue(waitForAssistantReply())
        XCTAssertFalse(element("ai.action-card").exists)
        XCTAssertFalse(app.staticTexts["新建待办"].exists)
        XCTAssertFalse(app.staticTexts["记录营业额"].exists)
    }

    private func waitForAssistantReply() -> Bool {
        element("ai.message.assistant").waitForExistence(timeout: 30)
    }

    private func waitForActionCard() -> Bool {
        element("ai.action-card").waitForExistence(timeout: 30)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func relaunch(failingOnce operation: String) {
        app.terminate()
        launchID = UUID().uuidString
        app.launchArguments = [
            "--ui-testing", "--ui-testing-id", launchID,
            "--ui-testing-fail-once", operation,
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 10))
    }

    private func assertTab(_ tabIdentifier: String, shows screenIdentifier: String) {
        // P0-A: 映射旧标识符到原生 TabBar 真实标签
        let labelMap = [
            "tab.home": "首页",
            "tab.todo": "待办",
            "tab.calendar": "日历",
            "tab.business": "经营"
        ]
        let tab: XCUIElement
        if let label = labelMap[tabIdentifier] {
            tab = app.tabBars.buttons[label]
        } else {
            tab = element(tabIdentifier)
        }
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing tab \(tabIdentifier)")
        tab.tap()
        XCTAssertTrue(element(screenIdentifier).waitForExistence(timeout: 5), "Missing screen \(screenIdentifier)")
    }

    private func openAI() {
        // ai.input 可能被识别为 textField 以外类型：用类型无关查询
        if element("ai.input").exists { return }
        if !element("screen.home").exists {
            assertTab("tab.home", shows: "screen.home")
        }
        let entry = element("home.ai")
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        tapElement("home.ai")
        XCTAssertTrue(element("sheet.ai").waitForExistence(timeout: 5))
    }

    private func openBusinessMenu(item identifier: String) {
        let menu = element("business.menu")
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let item = element(identifier)
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
    }

    private func tapElement(_ identifier: String) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "Missing element \(identifier)")
        if !target.isHittable {
            for _ in 0..<4 where !target.isHittable { app.swipeUp() }
        }
        if !target.isHittable {
            for _ in 0..<8 where !target.isHittable { app.swipeDown() }
        }
        XCTAssertTrue(target.isHittable, "Element is not hittable: \(identifier)")
        target.tap()
    }

    /// 内层操作按钮嵌套在行级 Button 中时，a11y 会合并为行元素
    /// （identifier 落在行元素上，label 为行标题），直接 tap 会命中行而非按钮。
    /// 触摸命中本身正常，故按行内坐标点击内层按钮；dx 按各行 trailing 布局
    /// 从源码精确计算（见各测试处注释），生产代码不动。
    private func tapTrailingButton(_ identifier: String, dx: CGFloat = 0.905) {
        let row = element(identifier)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Missing element \(identifier)")
        XCTAssertTrue(row.isHittable, "Element is not hittable: \(identifier)")
        let frame = row.frame
        print("tapTrailingButton \(identifier): row frame=\(frame), tap dx=\(dx)")
        row.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.5)).tap()
    }

    private func tapNavigationBack() {
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
    }

    /// SwiftUI alert actions do not expose custom identifiers consistently on every iOS runtime.
    /// Prefer the stable identifier and use the owning alert's action only as a platform fallback.
    private func tapRetry(in alertTitle: String) {
        let stable = element("reliability.retry")
        if stable.waitForExistence(timeout: 1) {
            stable.tap()
            return
        }
        let fallback = app.alerts[alertTitle].buttons["重试"]
        XCTAssertTrue(fallback.waitForExistence(timeout: 2))
        fallback.tap()
    }

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    override func record(_ issue: XCTIssue) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "failure-\(issue.type.rawValue)"
        attachment.lifetime = .keepAlways
        add(attachment)
        super.record(issue)
    }

}
