import XCTest

/// E·QA：V3.8 MotionLab 隔离演示的动效门禁。
///
/// 每个用例以 `--v38-motion-lab` 启动 App，直接进入 DEBUG-only 的
/// `V38MotionLabView`（见 `V38MotionLabQA.swift`），驱动 AI 展开/收起与
/// 快捷菜单的真实过渡。CI 在这些用例执行期间用
/// `xcrun simctl io booted recordVideo` 录屏，并校验视频非静止帧。
///
/// 录静止画面不算通过：每个动效用例都先断言"展开态不存在"，tap 后再断言
/// "展开态出现"，证明 tap 真实触发了一次状态过渡，而非录制静止画面。
final class V38MotionLabUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        if app.state != .notRunning {
            app.terminate()
        }
    }

    // MARK: - Motion recording tests (driven while simctl records video)

    func testAIExpandCollapseTriggersRealTransition() {
        launchMotionLab()
        // 前置：收起态可见、展开态不存在——tap 必须造成一次真实过渡。
        XCTAssertTrue(element("v38.motion.ai.expand").waitForExistence(timeout: 10))
        XCTAssertFalse(element("v38.motion.ai.expanded").exists)

        element("v38.motion.ai.expand").tap()
        XCTAssertTrue(
            element("v38.motion.ai.expanded").waitForExistence(timeout: 5),
            "AI expand did not trigger a real transition"
        )
        // 保持展开态，让录屏捕获过渡中的帧。
        sleep(2)

        element("v38.motion.ai.collapse").tap()
        XCTAssertTrue(
            element("v38.motion.ai.expand").waitForExistence(timeout: 5),
            "AI collapse did not return to the entry button"
        )
        sleep(1)
    }

    func testQuickMenuExpandSelectTriggersRealTransition() {
        launchMotionLab()
        XCTAssertTrue(element("v38.motion.quick.expand").waitForExistence(timeout: 10))
        XCTAssertFalse(element("v38.motion.quick.expanded").exists)

        element("v38.motion.quick.expand").tap()
        XCTAssertTrue(
            element("v38.motion.quick.expanded").waitForExistence(timeout: 5),
            "Quick menu expand did not trigger a real transition"
        )
        sleep(2)

        element("v38.motion.quick.income").tap()
        XCTAssertTrue(
            element("v38.motion.demo.selection").waitForExistence(timeout: 5),
            "Quick menu selection feedback missing"
        )
        // 选择演示动作后菜单收起，回到入口按钮。
        XCTAssertTrue(element("v38.motion.quick.expand").waitForExistence(timeout: 5))
        sleep(1)
    }

    // MARK: - Accessibility launch-argument matrix (smoke)

    /// Reduce Motion 模拟：动效取无动画分支，展开/收起仍可用。
    /// 覆盖参数仅模拟系统设置对 PoC 动效路径的影响；真实系统级设置为 NOT RUN。
    func testReduceMotionSmoke() {
        launchMotionLab(extraArgs: ["--v38-reduce-motion"])
        element("v38.motion.ai.expand").tap()
        XCTAssertTrue(element("v38.motion.ai.expanded").waitForExistence(timeout: 5))
        element("v38.motion.ai.collapse").tap()
        XCTAssertTrue(element("v38.motion.ai.expand").waitForExistence(timeout: 5))
        attachScreenshot(named: "v38-reduce-motion")
    }

    /// Reduce Transparency 模拟：材质取不透明回退，命中几何不变。
    func testReduceTransparencySmoke() {
        launchMotionLab(extraArgs: ["--v38-reduce-transparency"])
        element("v38.motion.quick.expand").tap()
        XCTAssertTrue(element("v38.motion.quick.expanded").waitForExistence(timeout: 5))
        attachScreenshot(named: "v38-reduce-transparency")
    }

    /// 大字体（AXXXL）：动效入口与展开态在超大字号下仍可达。
    func testLargeTextSmoke() {
        launchMotionLab(extraArgs: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        tapVisible("v38.motion.ai.expand")
        XCTAssertTrue(element("v38.motion.ai.expanded").waitForExistence(timeout: 5))
        tapVisible("v38.motion.ai.collapse")
        XCTAssertTrue(element("v38.motion.ai.expand").waitForExistence(timeout: 5))
        tapVisible("v38.motion.quick.expand")
        XCTAssertTrue(element("v38.motion.quick.expanded").waitForExistence(timeout: 5))
        attachScreenshot(named: "v38-large-text-axxxl")
    }

    // MARK: - Helpers

    /// 超大字号下入口可能被挤到首屏外：先断言存在，不可点则滚一屏再点。
    private func tapVisible(_ identifier: String, file: StaticString = #file, line: UInt = #line) {
        let e = element(identifier)
        XCTAssertTrue(e.waitForExistence(timeout: 10), "missing element: \(identifier)", file: file, line: line)
        if !e.isHittable {
            app.swipeUp()
        }
        e.tap()
    }

    private func launchMotionLab(extraArgs: [String] = []) {
        app.launchArguments = ["--ui-testing", "--v38-motion-lab"] + extraArgs
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    override func record(_ issue: XCTIssue) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "failure-\(issue.type.rawValue)"
        attachment.lifetime = .keepAlways
        add(attachment)
        super.record(issue)
    }
}
