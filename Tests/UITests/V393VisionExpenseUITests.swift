import XCTest

/// V3.9.3 B · 拍照智能记账 UI 验收：AI 设置页「图片与文件」区必须出现
/// 「发送图片与文件前先确认」开关（B 把原图片开关扩展为图片与文件同款确认）。
/// 图片/文件真实外发确认弹窗与多金额澄清由单测 + 集成测试覆盖；
/// UI 测试库内无法可靠构造相册/文件导入，故此处只断设置页入口文案与截图。
final class V393VisionExpenseUITests: XCTestCase {
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

    /// 设置页图片与文件确认开关文案（B）必须可见。
    func testDocumentConsentToggleCopy() {
        openAI()
        let menu = app.buttons["ai.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "ai.menu 未找到")
        menu.tap()
        let settingsButton = app.buttons["AI 设置"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "AI 设置菜单项未找到")
        settingsButton.tap()
        let toggle = app.switches["发送图片与文件前先确认"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "图片与文件确认开关未出现（B 文案）")
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "v393-settings-document-consent"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
