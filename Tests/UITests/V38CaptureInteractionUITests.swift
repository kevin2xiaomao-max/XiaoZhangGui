import XCTest

/// V3.8 Worker B：AI 胶囊 + 快捷菜单隔离组件的交互 UI 测试。
///
/// 通过 launch argument `--v38-capture-demo` 进入 DEBUG-only 独立演示宿主
///（`V38CaptureDemoHost`），不经过生产 RootView/TabView；组件无业务数据、
/// 无网络、不调真实 AI。
final class V38CaptureInteractionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-id", UUID().uuidString,
            "--v38-capture-demo",
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        XCTAssertTrue(
            element("v38.capture.demo.host").waitForExistence(timeout: 10),
            "Capture demo host did not appear"
        )
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
    }

    // MARK: - AI 胶囊：展开 / 收起 / 回到原入口

    func testAICapsuleExpandCollapseReturnsToEntry() {
        let expand = element("v38.motion.ai.expand")
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        XCTAssertTrue(expand.isHittable)
        expand.tap()

        XCTAssertTrue(element("v38.motion.ai.collapse").waitForExistence(timeout: 5))
        XCTAssertTrue(element("v38.motion.ai.expanded").exists)

        element("v38.motion.ai.collapse").tap()

        // 关闭后回到原入口：展开按钮重新出现且可点，展开态视图无残影。
        let backToEntry = element("v38.motion.ai.expand")
        XCTAssertTrue(backToEntry.waitForExistence(timeout: 5))
        XCTAssertTrue(backToEntry.isHittable, "AI entry button must be tappable after collapse")
        XCTAssertTrue(
            waitForDisappearance("v38.motion.ai.expanded"),
            "Expanded AI panel must be removed after collapse (ghost check)"
        )
    }

    // MARK: - 快捷菜单：展开 / 选择 / 收起 / 回到原入口

    func testQuickMenuExpandSelectIncomeReturnsToEntry() {
        let expand = element("v38.motion.quick.expand")
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        expand.tap()

        XCTAssertTrue(element("v38.motion.quick.collapse").waitForExistence(timeout: 5))
        let income = element("v38.motion.quick.income")
        XCTAssertTrue(income.waitForExistence(timeout: 5))
        XCTAssertTrue(income.isHittable)
        income.tap()

        // 选择后菜单收起并回到原入口；演示选择仅展示，不执行保存。
        XCTAssertTrue(element("v38.motion.quick.expand").waitForExistence(timeout: 5))
        XCTAssertTrue(waitForDisappearance("v38.motion.quick.expanded"))
        let selection = element("v38.motion.demo.selection")
        XCTAssertTrue(selection.waitForExistence(timeout: 5))
        XCTAssertTrue(selection.label.contains("记收入"), "Unexpected selection label: \(selection.label)")
    }

    func testQuickMenuCollapseButtonReturnsToEntry() {
        tapHittable("v38.motion.quick.expand")
        tapHittable("v38.motion.quick.collapse")

        let expand = element("v38.motion.quick.expand")
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        XCTAssertTrue(expand.isHittable, "Quick entry button must be tappable after collapse")
        XCTAssertTrue(waitForDisappearance("v38.motion.quick.expanded"))
    }

    // MARK: - 互斥：展开其一即收起另一

    func testExpandingOneCollapsesTheOther() {
        tapHittable("v38.motion.ai.expand")
        XCTAssertTrue(element("v38.motion.ai.collapse").waitForExistence(timeout: 5))

        tapHittable("v38.motion.quick.expand")
        XCTAssertTrue(element("v38.motion.quick.collapse").waitForExistence(timeout: 5))

        // AI 面板应被互斥收起，无残影；AI 入口恢复可用。
        XCTAssertTrue(waitForDisappearance("v38.motion.ai.expanded"))
        let aiEntry = element("v38.motion.ai.expand")
        XCTAssertTrue(aiEntry.waitForExistence(timeout: 5))
        XCTAssertTrue(aiEntry.isHittable)
    }

    // MARK: - 20 次快速连续开合鲁棒性（无残影 / 无死锁 / 按钮始终可点）

    func testRapidAICapsuleOpenCloseRobustness() {
        for i in 0..<20 {
            let expand = element("v38.motion.ai.expand")
            XCTAssertTrue(expand.waitForExistence(timeout: 5), "cycle \(i): AI expand entry missing")
            XCTAssertTrue(expand.isHittable, "cycle \(i): AI expand entry not hittable (dead UI?)")
            expand.tap()

            let collapse = element("v38.motion.ai.collapse")
            XCTAssertTrue(collapse.waitForExistence(timeout: 5), "cycle \(i): AI collapse button missing")
            XCTAssertTrue(waitForHittable(collapse, timeout: 5), "cycle \(i): AI collapse not hittable")
            collapse.tap()

            // 每轮收起后立即断言无残影，避免幽灵视图堆积。
            XCTAssertTrue(
                waitForDisappearance("v38.motion.ai.expanded"),
                "cycle \(i): ghost expanded AI panel"
            )
        }
        // 20 轮后入口仍可用。
        let expand = element("v38.motion.ai.expand")
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        XCTAssertTrue(expand.isHittable, "AI entry must stay tappable after 20 rapid cycles")
        captureScreenshot(named: "v38-capture-ai-after-20-cycles")
    }

    func testRapidQuickMenuOpenCloseRobustness() {
        for i in 0..<20 {
            let expand = element("v38.motion.quick.expand")
            XCTAssertTrue(expand.waitForExistence(timeout: 5), "cycle \(i): quick expand entry missing")
            XCTAssertTrue(expand.isHittable, "cycle \(i): quick expand entry not hittable (dead UI?)")
            expand.tap()

            let collapse = element("v38.motion.quick.collapse")
            XCTAssertTrue(collapse.waitForExistence(timeout: 5), "cycle \(i): quick collapse button missing")
            XCTAssertTrue(waitForHittable(collapse, timeout: 5), "cycle \(i): quick collapse not hittable")
            collapse.tap()

            XCTAssertTrue(
                waitForDisappearance("v38.motion.quick.expanded"),
                "cycle \(i): ghost expanded quick panel"
            )
        }
        let expand = element("v38.motion.quick.expand")
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        XCTAssertTrue(expand.isHittable, "Quick entry must stay tappable after 20 rapid cycles")
        captureScreenshot(named: "v38-capture-quick-after-20-cycles")
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// 等待元素出现且可点后再 tap，降低动效过渡中的误触抖动。
    private func tapHittable(_ identifier: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing element \(identifier)", file: file, line: line)
        XCTAssertTrue(waitForHittable(target, timeout: timeout), "Element not hittable: \(identifier)", file: file, line: line)
        target.tap()
    }

    private func waitForHittable(_ target: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if target.isHittable { return true }
            usleep(60_000)
        }
        return target.isHittable
    }

    private func waitForDisappearance(_ identifier: String, timeout: TimeInterval = 3) -> Bool {
        let target = element(identifier)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !target.exists { return true }
            usleep(60_000)
        }
        return !target.exists
    }

    private func captureScreenshot(named name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(name).png")
        try? shot.pngRepresentation.write(to: url)
        print("[V38Capture] screenshot: \(url.path)")
    }

    override func record(_ issue: XCTIssue) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "failure-\(issue.type.rawValue)"
        attachment.lifetime = .keepAlways
        add(attachment)
        super.record(issue)
    }
}
