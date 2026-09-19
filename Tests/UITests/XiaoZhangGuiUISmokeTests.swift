import XCTest

final class XiaoZhangGuiUISmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-id", UUID().uuidString]
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
        XCTAssertTrue(app.tabBars.buttons["小掌柜"].waitForExistence(timeout: 10))
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
        let tab = app.tabBars.buttons["小掌柜"]
        if tab.exists { tab.tap() }
        let input = app.textFields["ai.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 8))
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
