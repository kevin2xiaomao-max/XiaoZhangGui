import UIKit
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
        // 注意：XCUIDevice.appearance 不可设 .unspecified（iOS 27 报
        // "Requested appearance value (0) is not valid" 并使测试失败）；
        // 外观复位由截图测试自身以 .light 显式完成。
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
        // 用 App 级绝对坐标点按：行完成移出后元素消失，元素派生坐标再点按会
        // 报 "Failed to get matching snapshot"；绝对坐标不依赖元素存续，
        // 行移出后点在空白列表区无副作用。
        let toggleFrame = toggle.frame
        let anchor = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: toggleFrame.midX, dy: toggleFrame.midY))
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
        // 外观切换走 App 生产路径（我的 → 显示模式 → 浅色/深色模式）：
        // XCUIDevice.appearance 在本 harness 下不传导到本 App 渲染——
        // run 39815551862 实测其 Dark 截图亮度 0.9346 ≈ Light 0.933（假 Dark），
        // 故改用 App 自带 themeMode（settings.colorScheme），切换立即生效。
        // 每相位截图都做像素亮度断言，未真生效会明确失败，不产出假图。
        setDisplayMode("浅色模式")
        openTodoTab()
        XCTAssertTrue(app.staticTexts[seedTitle].waitForExistence(timeout: 5))
        let lightShot = app.screenshot()
        attachScreenshot(lightShot, named: "v38-todo-rebuild-light")
        // 像素级自证：Light 渲染整体高亮（实测基线 ≈0.93），断言 >0.7 留足余量。
        let lightLuminance = meanLuminance(of: lightShot)
        XCTAssertGreaterThan(lightLuminance, 0.7, "Light 截图亮度异常：\(lightLuminance)")

        setDisplayMode("深色模式")
        openTodoTab()
        XCTAssertTrue(app.staticTexts[seedTitle].waitForExistence(timeout: 5))
        let darkShot = app.screenshot()
        attachScreenshot(darkShot, named: "v38-todo-rebuild-dark")
        // 像素级自证：Dark 必须真生效（墨绿黑底，整体低亮）。
        let darkLuminance = meanLuminance(of: darkShot)
        XCTAssertLessThan(darkLuminance, 0.45, "Dark 截图未真生效，亮度：\(darkLuminance)")

        // themeMode 持久化在 UserDefaults：恢复「跟随系统」，不污染后续测试。
        setDisplayMode("跟随系统")
    }

    /// 经生产 UI 设置显示模式：首页头像 → 我的 → 显示模式 sheet → 选项（选后自动关闭）→ 返回。
    private func setDisplayMode(_ optionLabel: String) {
        // 先回到首页根部：在待办 tab 时切回首页；若「我的」还压在首页栈上，先点返回弹出。
        let homeTab = app.tabBars.buttons["首页"]
        if homeTab.exists { homeTab.tap() }
        if element("screen.profile").exists {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.exists { back.tap() }
        }
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 5), "未回到首页")
        element("home.profile").tap()
        XCTAssertTrue(element("screen.profile").waitForExistence(timeout: 5), "我的页未出现")
        tapLabeled("显示模式")
        tapLabeled(optionLabel)
        // 选项点击后 sheet 自动 dismiss：等选项元素消失，再返回首页根部。
        XCTAssertTrue(
            waitUntil(timeout: 5) { !self.labeledElement(optionLabel).exists },
            "显示模式 sheet 未关闭"
        )
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 5), "未返回首页")
    }

    /// WorkRow 的按钮 label 会拼上 trailing 值（如「显示模式 跟随系统」），用 BEGINSWITH 匹配。
    private func labeledElement(_ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    /// 按 label 前缀点按按钮（WorkRow 等无 identifier 的行）。
    private func tapLabeled(_ label: String) {
        let target = labeledElement(label)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "未找到元素：\(label)")
        target.tap()
    }

    private func attachScreenshot(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 截图整体平均亮度（0–1）：把截图缩绘到 16×16 位图后按 Rec.709 加权。
    private func meanLuminance(of screenshot: XCUIScreenshot) -> Double {
        guard let cgImage = screenshot.image.cgImage else { return -1 }
        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return -1 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        var sum = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            sum += 0.2126 * Double(pixels[index])
                + 0.7152 * Double(pixels[index + 1])
                + 0.0722 * Double(pixels[index + 2])
        }
        return sum / Double(side * side) / 255.0
    }
}
