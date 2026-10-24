import XCTest

/// V3.9.1 P2-E · skip 真实原因(非核心测试被跳过):
/// 两个 skip 用例(testThinkingIndicatorAppearsDuringSlowRealRequestThenStops /
/// testThinkingIndicatorStopsOnRequestFailure)依赖外部慢速验证服务
/// (outputs/thinking-orbs/slow_server.py,需本机起服务 + harnessReachable),
/// CI  runner 上无该服务故 XCTSkipUnless 跳过;这不是断言失败,也不是测试被删除。
/// 思考指示的状态机本身由单元测试(V38AIOperationStateTests)与本地查询用例
/// (testThinkingIndicatorNotPersistentAfterLocalQuery,CI 内运行)覆盖;
/// 慢请求/失败请求的端到端窗口须在起服务后本地补跑,不得以 skip 冒充通过。

/// V3.7.1：AI 思考态指示（ThinkingOrbs）必须由**真实请求状态**驱动。
///
/// 覆盖三条要求：
/// 1. 静止状态下不存在——不允许脱离请求的常驻「假思考动画」；
/// 2. AI 开始实际处理时出现；
/// 3. 处理结束 / 失败后立即消失。
///
/// 说明（重要）：
/// 本地 0-Token 查询（营业额 / 商品 / 待办…）在设备上只需几次 actor 跳转、
/// 远快于一次屏幕刷新，`isProcessing` 的真值窗口短到无法被 UI 轮询观测——
/// 这本身正是「不做假动画」的体现。因此「出现 → 消失」的正向验证改为走
/// **真实的 URL 读取链路**（AICapabilityRouter → URLReadingCapability →
/// URLSession），由本机慢速站点把请求拉长到数秒。该链路不修改任何生产代码，
/// 也不依赖 API Key。
///
/// 前置条件：`outputs/thinking-orbs/slow_server.py` 已在 127.0.0.1:8765 运行；
/// 未运行时相关用例自动跳过（XCTSkip），不影响常规回归。
final class ThinkingIndicatorUITests: XCTestCase {
    private var app: XCUIApplication!

    /// 本机慢速验证站点（见 outputs/thinking-orbs/slow_server.py）
    private let slowURL = "http://127.0.0.1:8765/slow"
    private let failURL = "http://127.0.0.1:8765/fail"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
    }

    // MARK: - 1. 静止状态：绝不常驻

    /// 打开 AI 页后不应存在任何思考指示——直接证伪「永远转动的假思考动画」。
    func testThinkingIndicatorAbsentWhenIdle() {
        openAI()
        XCTAssertTrue(element("ai.input").waitForExistence(timeout: 8))
        for _ in 0..<4 {
            Thread.sleep(forTimeInterval: 1.0)
            XCTAssertFalse(element("ai.typing").exists, "静止状态下不应出现思考指示")
        }
        captureScreenshot(named: "thinking-idle-absent")
    }

    /// 本地 0-Token 查询同样不产生常驻指示：回复到达后指示必须不存在。
    func testThinkingIndicatorNotPersistentAfterLocalQuery() {
        openAI()
        sendMessage("今天营业额多少")
        XCTAssertTrue(element("ai.message.assistant").waitForExistence(timeout: 15),
                      "本地查询未返回助手回复")
        Thread.sleep(forTimeInterval: 2.0)
        XCTAssertFalse(element("ai.typing").exists, "本地查询结束后思考指示不应存在")
    }

    // MARK: - 2/3. 真实慢请求：出现 → 结束立即消失

    func testThinkingIndicatorAppearsDuringSlowRealRequestThenStops() throws {
        try XCTSkipUnless(harnessReachable(),
                          "本地慢速验证服务未启动：先运行 outputs/thinking-orbs/slow_server.py")

        openAI()
        sendMessage("帮我读一下 \(slowURL)")

        let typing = element("ai.typing")
        XCTAssertTrue(waitForAppearance(typing, timeout: 6), "真实请求进行期间未出现思考指示")
        let appearedAt = Date()

        // VoiceOver：整块合并为一个元素，朗读「小掌柜 + 当前处理文案」。
        // 元素能在无障碍树中被找到且带中文标签，即证明它可被读屏识别。
        XCTAssertTrue(typing.label.contains("小掌柜"),
                      "思考指示应暴露「小掌柜…」无障碍标签，实际为「\(typing.label)」")

        // 关键证据：在**请求仍在进行**时抓取真实截图
        XCTAssertTrue(typing.exists, "请求进行中指示应存在")
        captureScreenshot(named: "thinking-during-request")

        // 请求尚未结束时，指示必须保持可见（证明它跟随请求，而不是一闪而过）
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(typing.exists, "请求尚未结束，思考指示不应提前消失")
        captureScreenshot(named: "thinking-during-request-late")

        XCTAssertTrue(waitForDisappearance(typing, timeout: 40), "请求结束后思考指示未消失")
        let stoppedAt = Date()
        print("[ThinkingOrbs] 真实请求窗口 ≈ \(String(format: "%.2f", stoppedAt.timeIntervalSince(appearedAt)))s")

        // 结束后应出现助手回复，证明是「处理结束」而非「中途丢状态」
        XCTAssertTrue(element("ai.message.assistant").waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 2.0)
        XCTAssertFalse(element("ai.typing").exists, "请求结束后思考指示不应复现")
        captureScreenshot(named: "thinking-stopped-after-request")
    }

    /// 失败路径：上游返回 500 → 请求失败后指示同样必须立即停止。
    func testThinkingIndicatorStopsOnRequestFailure() throws {
        try XCTSkipUnless(harnessReachable(),
                          "本地慢速验证服务未启动：先运行 outputs/thinking-orbs/slow_server.py")

        openAI()
        sendMessage("帮我读一下 \(failURL)")

        let typing = element("ai.typing")
        XCTAssertTrue(waitForAppearance(typing, timeout: 6), "失败请求进行期间未出现思考指示")
        captureScreenshot(named: "thinking-during-failing-request")

        XCTAssertTrue(waitForDisappearance(typing, timeout: 40), "请求失败后思考指示未消失")

        // 失败必须给出可见回复（错误提示），且指示不复现
        XCTAssertTrue(element("ai.message.assistant").waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 2.0)
        XCTAssertFalse(element("ai.typing").exists, "失败结束后思考指示不应复现")
        captureScreenshot(named: "thinking-stopped-after-failure")
    }

    // MARK: - Helpers

    /// 抓取真实模拟器截图：既作为 XCTAttachment 保留在 xcresult，
    /// 也写入测试进程临时目录，便于宿主机直接取用为交付物。
    private func captureScreenshot(named name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(name).png")
        try? shot.pngRepresentation.write(to: url)
        print("[ThinkingOrbs] screenshot: \(url.path)")
    }

    /// 轮询等待元素出现。
    ///
    /// 不使用 `waitForExistence`：ThinkingOrb 由 TimelineView 持续驱动，
    /// app 永不进入 quiescent 状态，XCTest 的 expectation 式等待在该场景下不可靠。
    /// 直接轮询 `exists`（快照查询，不等待静默）在本场景下稳定可靠。
    @discardableResult
    private func waitForAppearance(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists { return true }
            usleep(40_000)
        }
        return element.exists
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
            usleep(50_000)
        }
        return !element.exists
    }

    /// 从测试进程探测本机慢速站点是否可达（UI 测试进程同样运行在模拟器内）。
    private func harnessReachable(timeout: TimeInterval = 3) -> Bool {
        guard let url = URL(string: "http://127.0.0.1:8765/") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "HEAD"
        let semaphore = DispatchSemaphore(value: 0)
        var ok = false
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) {
                ok = true
            }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + timeout + 2)
        return ok
    }

    private func sendMessage(_ text: String) {
        let input = element("ai.input")
        XCTAssertTrue(input.waitForExistence(timeout: 8), "ai.input 未找到")
        input.tap()
        let keyboardTutorial = app.buttons["Continue"]
        if keyboardTutorial.waitForExistence(timeout: 1) {
            keyboardTutorial.tap()
        }
        input.typeText(text)

        let sendButton = app.buttons["ai.send"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5), "ai.send 未找到")
        XCTAssertTrue(sendButton.isHittable, "ai.send 不可点击")
        sendButton.tap()
    }

    private func openAI() {
        if element("ai.input").exists { return }
        if !element("screen.home").exists {
            let homeTab = app.tabBars.buttons["首页"]
            if homeTab.waitForExistence(timeout: 5) { homeTab.tap() }
        }
        // V3.9.1 P1-5：AI 胶囊一次点击直接打开 Sheet（旧两步展开路径已废止，仅作兼容回退）。
        if element("v38.home.ai.openSheet").exists {
            element("v38.home.ai.openSheet").tap()
            return
        }
        if element("v38.home.ai.expand").exists {
            element("v38.home.ai.expand").tap()
            XCTAssertTrue(element("v38.home.ai.collapse").waitForExistence(timeout: 5))
            element("v38.home.ai.openSheet").tap()
        } else {
            let entry = element("home.ai")
            XCTAssertTrue(entry.waitForExistence(timeout: 5), "home.ai 入口未找到")
            entry.tap()
        }
        XCTAssertTrue(element("sheet.ai").waitForExistence(timeout: 5))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
