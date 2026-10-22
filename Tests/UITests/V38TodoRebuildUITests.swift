import XCTest

/// V3.8 重建 R2 · Todo 生产级交互 UI 测试。
///
/// 在真实生产 App（`--ui-testing`，种子内存库）验证规格 §2 / G4 / G5：
/// - V3.8 Editorial Todo 渲染（进度头 + 平面列表 + 种子待办）
/// - 勾选成功：回执后完成态出现，行移出今日并进入「已完成」
/// - 勾选失败（注入）：**无成功态闪现**——行仍在今日、开关值="保存失败，可重试"、
///   行内重试出现；行内重试成功后才完成
/// - 20 次快速连点：只完成一次，「已完成」里恰好一条，无状态错乱
/// - Light/Dark 截图（CI 产物）
final class V38TodoRebuildUITests: XCTestCase {
    private var app: XCUIApplication!
    private let seedTitle = "UI Test 保留待办"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        launchApp()
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        XCUIDevice.shared.appearance = .unspecified
    }

    private func launchApp(failingOnce operation: String? = nil) {
        if app.state != .notRunning { app.terminate() }
        var args = ["--ui-testing", "--ui-testing-id", UUID().uuidString]
        if let operation {
            args += ["--ui-testing-fail-once", operation]
        }
        app.launchArguments = args
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 10), "Home 未出现")
    }

    /// 使用 `.any` 类型匹配（玻璃/形变容器上的 identifier 可能不暴露为特定类型）。
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func openTodoTab() {
        let tab = app.tabBars.buttons["待办"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "待办 Tab 不存在")
        tab.tap()
        XCTAssertTrue(element("screen.todo").waitForExistence(timeout: 5), "Todo 页未出现")
    }

    private func waitUntil(timeout: TimeInterval = 8, _ condition: () -> Bool) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }

    // MARK: - 结构渲染

    func testTodoScreenRendersV38ProgressAndSeedRow() {
        openTodoTab()
        XCTAssertTrue(element("v38.todo.progress").waitForExistence(timeout: 5), "进度头未渲染")
        XCTAssertTrue(app.staticTexts[seedTitle].waitForExistence(timeout: 5), "种子待办未渲染")
        XCTAssertTrue(element("todo.toggle").exists, "复选框未渲染")
        XCTAssertEqual(element("todo.toggle").value as? String, "未完成", "初始状态应为未完成")
    }

    // MARK: - 勾选成功：回执后完成，移入「已完成」

    func testToggleCompletesAndMovesToDoneTab() {
        openTodoTab()
        element("todo.toggle").tap()
        XCTAssertTrue(
            waitUntil(timeout: 8) { !self.element("todo.toggle").exists },
            "完成后行应移出今日列表"
        )
        let doneSegment = app.buttons["已完成"]
        XCTAssertTrue(doneSegment.waitForExistence(timeout: 5))
        doneSegment.tap()
        XCTAssertTrue(
            app.staticTexts[seedTitle].waitForExistence(timeout: 5),
            "已完成 tab 应出现该待办"
        )
    }

    // MARK: - 勾选失败：无成功闪现 + 行内重试（关键用例）

    func testToggleFailureShowsNoSuccessFlashAndInlineRetrySucceeds() {
        launchApp(failingOnce: "todo.toggle")
        openTodoTab()
        element("todo.toggle").tap()

        // 既有契约：失败 alert 出现；行与开关仍在（未完成、未移出）。
        let alert = app.alerts["操作失败"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "失败 alert 未出现")
        XCTAssertTrue(element("todo.toggle").exists, "失败后开关必须保留（未宣告成功）")
        XCTAssertTrue(app.staticTexts[seedTitle].exists, "失败后待办必须仍在今日列表")

        // 关掉 alert（取消），行内失败条应保留：开关值播报"保存失败，可重试" + 行内重试按钮。
        alert.buttons["取消"].tap()
        XCTAssertTrue(
            element("v38.todo.retry").waitForExistence(timeout: 5),
            "行内重试未出现"
        )
        XCTAssertEqual(
            element("todo.toggle").value as? String, "保存失败，可重试",
            "开关无障碍值应为保存失败可重试，而非已完成"
        )
        XCTAssertTrue(app.staticTexts[seedTitle].exists, "行内失败态下待办仍应在今日列表")

        // 行内重试（注入为一次性，第二次保存成功）→ 这时才完成并移出今日。
        element("v38.todo.retry").tap()
        XCTAssertTrue(
            waitUntil(timeout: 8) { !self.element("todo.toggle").exists },
            "行内重试成功后行应移出今日列表"
        )
        XCTAssertFalse(app.alerts["操作失败"].exists, "重试成功不应再弹失败 alert")
    }

    // MARK: - 20 次快速连点鲁棒性（G4）

    func testRapidToggleTwentyTimesCompletesExactlyOnce() {
        openTodoTab()
        let toggle = element("todo.toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let anchor = toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // 快速连点 20 次：保存中/停留期的点按被状态机与在途守卫忽略。
        for _ in 0..<20 {
            anchor.tap()
            Thread.sleep(forTimeInterval: 0.03)
        }
        XCTAssertTrue(
            waitUntil(timeout: 8) { !self.element("todo.toggle").exists },
            "连点后行应完成并移出今日列表"
        )
        let doneSegment = app.buttons["已完成"]
        XCTAssertTrue(doneSegment.waitForExistence(timeout: 5))
        doneSegment.tap()
        XCTAssertTrue(app.staticTexts[seedTitle].waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label == %@", seedTitle)).count, 1,
            "已完成中应恰好一条（无重复完成/状态错乱）"
        )
    }

    // MARK: - Light/Dark 截图（CI 产物）

    func testTodoLightDarkScreenshots() {
        openTodoTab()
        XCTAssertTrue(app.staticTexts[seedTitle].waitForExistence(timeout: 5))
        attachScreenshot(named: "v38-todo-rebuild-light")

        XCUIDevice.shared.appearance = .dark
        launchApp()
        openTodoTab()
        XCTAssertTrue(app.staticTexts[seedTitle].waitForExistence(timeout: 5))
        attachScreenshot(named: "v38-todo-rebuild-dark")
        XCUIDevice.shared.appearance = .unspecified
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
