import XCTest

/// V3.8 Worker B：AI 胶囊 + 快捷菜单隔离组件的交互 UI 测试。
///
/// 通过 launch argument `--v38-capture-demo` 进入 DEBUG-only 独立演示宿主
///（`V38CaptureDemoHost`），不经过生产 RootView/TabView；组件无业务数据、
/// 无网络、不调真实 AI。
///
/// 等待策略：全部使用快照轮询（`exists` / `isHittable`），不使用 XCTest 的
/// `waitForExistence`（expectation 式）。实测结论（CI iPhone 17 / iOS 26）：
/// 展开态玻璃面板视觉上完全展开后，`waitForExistence` 仍持续超时——
/// 动效/玻璃使 app 无法进入 XCTest 期望的静默（quiescent）状态；
/// 直接轮询快照则稳定可靠（与 ThinkingIndicatorUITests 既有结论一致）。
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
            waitForElement("v38.capture.demo.host", timeout: 10),
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
        XCTAssertTrue(waitForElement("v38.motion.ai.expand"), "AI expand entry missing")
        XCTAssertTrue(waitForHittable(element("v38.motion.ai.expand")), "AI expand entry not hittable")
        element("v38.motion.ai.expand").tap()

        XCTAssertTrue(waitForElement("v38.motion.ai.collapse"), "AI collapse button missing after expand")
        XCTAssertTrue(element("v38.motion.ai.expanded").exists, "AI expanded panel missing")

        element("v38.motion.ai.collapse").tap()

        // 关闭后回到原入口：展开按钮重新出现且可点，展开态视图无残影。
        XCTAssertTrue(waitForElement("v38.motion.ai.expand"), "AI entry did not return after collapse")
        XCTAssertTrue(
            waitForHittable(element("v38.motion.ai.expand")),
            "AI entry button must be tappable after collapse"
        )
        XCTAssertTrue(
            waitForDisappearance("v38.motion.ai.expanded"),
            "Expanded AI panel must be removed after collapse (ghost check)"
        )
    }

    // MARK: - 快捷菜单：展开 / 选择 / 收起 / 回到原入口

    func testQuickMenuExpandSelectIncomeReturnsToEntry() {
        tapHittable("v38.motion.quick.expand")

        XCTAssertTrue(waitForElement("v38.motion.quick.collapse"), "Quick collapse button missing after expand")
        XCTAssertTrue(waitForElement("v38.motion.quick.income"), "Quick income row missing")
        XCTAssertTrue(
            waitForHittable(element("v38.motion.quick.income")),
            "Quick income row not hittable"
        )
        element("v38.motion.quick.income").tap()

        // 选择后菜单收起并回到原入口；演示选择仅展示，不执行保存。
        XCTAssertTrue(waitForElement("v38.motion.quick.expand"), "Quick entry did not return after selection")
        XCTAssertTrue(waitForDisappearance("v38.motion.quick.collapse"), "Ghost quick panel after selection")
        XCTAssertTrue(waitForElement("v38.motion.demo.selection"), "Demo selection echo missing")
        let selection = element("v38.motion.demo.selection")
        XCTAssertTrue(selection.label.contains("记收入"), "Unexpected selection label: \(selection.label)")
    }

    func testQuickMenuCollapseButtonReturnsToEntry() {
        tapHittable("v38.motion.quick.expand")
        tapHittable("v38.motion.quick.collapse")

        XCTAssertTrue(waitForElement("v38.motion.quick.expand"), "Quick entry did not return after collapse")
        XCTAssertTrue(
            waitForHittable(element("v38.motion.quick.expand")),
            "Quick entry button must be tappable after collapse"
        )
        XCTAssertTrue(waitForDisappearance("v38.motion.quick.collapse"), "Ghost quick panel after collapse")
    }

    // MARK: - 互斥：展开其一即收起另一

    func testExpandingOneCollapsesTheOther() {
        tapHittable("v38.motion.ai.expand")
        XCTAssertTrue(waitForElement("v38.motion.ai.collapse"), "AI collapse button missing after expand")

        tapHittable("v38.motion.quick.expand")
        XCTAssertTrue(waitForElement("v38.motion.quick.collapse"), "Quick collapse button missing after expand")

        // AI 面板应被互斥收起，无残影；AI 入口恢复可用。
        XCTAssertTrue(waitForDisappearance("v38.motion.ai.expanded"), "AI panel ghost after mutual exclusion")
        XCTAssertTrue(waitForElement("v38.motion.ai.expand"), "AI entry did not return after mutual exclusion")
        XCTAssertTrue(waitForHittable(element("v38.motion.ai.expand")), "AI entry not hittable after mutual exclusion")
    }

    // MARK: - 20 次快速连续开合鲁棒性（无残影 / 无死锁 / 按钮始终可点）

    func testRapidAICapsuleOpenCloseRobustness() {
        for i in 0..<20 {
            XCTAssertTrue(waitForElement("v38.motion.ai.expand"), "cycle \(i): AI expand entry missing")
            XCTAssertTrue(
                waitForHittable(element("v38.motion.ai.expand")),
                "cycle \(i): AI expand entry not hittable (dead UI?)"
            )
            element("v38.motion.ai.expand").tap()

            XCTAssertTrue(waitForElement("v38.motion.ai.collapse"), "cycle \(i): AI collapse button missing")
            XCTAssertTrue(
                waitForHittable(element("v38.motion.ai.collapse")),
                "cycle \(i): AI collapse not hittable"
            )
            element("v38.motion.ai.collapse").tap()

            // 每轮收起后立即断言无残影，避免幽灵视图堆积。
            XCTAssertTrue(
                waitForDisappearance("v38.motion.ai.expanded"),
                "cycle \(i): ghost expanded AI panel"
            )
        }
        // 20 轮后入口仍可用。
        XCTAssertTrue(waitForElement("v38.motion.ai.expand"), "AI entry missing after 20 cycles")
        XCTAssertTrue(
            waitForHittable(element("v38.motion.ai.expand")),
            "AI entry must stay tappable after 20 rapid cycles"
        )
        captureScreenshot(named: "v38-capture-ai-after-20-cycles")
    }

    func testRapidQuickMenuOpenCloseRobustness() {
        for i in 0..<20 {
            XCTAssertTrue(waitForElement("v38.motion.quick.expand"), "cycle \(i): quick expand entry missing")
            XCTAssertTrue(
                waitForHittable(element("v38.motion.quick.expand")),
                "cycle \(i): quick expand entry not hittable (dead UI?)"
            )
            element("v38.motion.quick.expand").tap()

            XCTAssertTrue(waitForElement("v38.motion.quick.collapse"), "cycle \(i): quick collapse button missing")
            XCTAssertTrue(
                waitForHittable(element("v38.motion.quick.collapse")),
                "cycle \(i): quick collapse not hittable"
            )
            element("v38.motion.quick.collapse").tap()

            XCTAssertTrue(
                waitForDisappearance("v38.motion.quick.collapse"),
                "cycle \(i): ghost expanded quick panel"
            )
        }
        XCTAssertTrue(waitForElement("v38.motion.quick.expand"), "Quick entry missing after 20 cycles")
        XCTAssertTrue(
            waitForHittable(element("v38.motion.quick.expand")),
            "Quick entry must stay tappable after 20 rapid cycles"
        )
        captureScreenshot(named: "v38-capture-quick-after-20-cycles")
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// 不依赖 app 静默（quiescent）的存在性轮询。
    ///
    /// 实测（CI iPhone 17 / iOS 26）：展开态玻璃面板视觉完全展开后，
    /// XCTest 的 `waitForExistence`（expectation 式，等待 app 静默）持续超时；
    /// 直接轮询 `exists`（快照查询）稳定可靠。
    /// 与 ThinkingIndicatorUITests 中的既有结论一致。
    @discardableResult
    private func waitForElement(_ identifier: String, timeout: TimeInterval = 8) -> Bool {
        let target = element(identifier)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if target.exists { return true }
            usleep(100_000)
        }
        return target.exists
    }

    /// 等待元素出现且可点后再 tap，降低动效过渡中的误触抖动。
    private func tapHittable(_ identifier: String, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waitForElement(identifier, timeout: timeout), "Missing element \(identifier)", file: file, line: line)
        XCTAssertTrue(waitForHittable(element(identifier), timeout: timeout), "Element not hittable: \(identifier)", file: file, line: line)
        element(identifier).tap()
    }

    private func waitForHittable(_ target: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if target.isHittable { return true }
            usleep(100_000)
        }
        return target.isHittable
    }

    private func waitForDisappearance(_ identifier: String, timeout: TimeInterval = 3) -> Bool {
        let target = element(identifier)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !target.exists { return true }
            usleep(100_000)
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
