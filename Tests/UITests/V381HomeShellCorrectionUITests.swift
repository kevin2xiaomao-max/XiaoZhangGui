import XCTest

/// V3.8.1 真机 UI 纠偏（线 A：Home + App 壳）UI 回归测试。
///
/// - P0-1 后续（2026-10-23 用户确认减法）：「快速记一笔 / 写备忘」快捷行
///   已整行删除。本测试负责真实渲染侧：Light/Dark 两 scheme 下被删
///   入口均不存在，并产出首页默认态 Light/Dark 真实截图供逐项对照。
///   Dark 走 App 生产主题路径（AppSettings.themeMode），禁用
///   XCUIDevice.appearance / 启动参数（前序实测均为假 Dark），
///   并以像素亮度断言自证 Dark 真生效。
/// - P0-2：四页滚动到底后，末尾标记必须位于浮动 Tab 栏上方且可命中，
///   且底部留白不过量（防过度预留）。frame 数值写进断言消息，
///   失败时可从 test.log 直接读到实测缺口。
/// - P0-4：保留的 AI 胶囊标题在默认与 AX 特大字号下保持单行（以文本
///   高度/宽度为口径），并断言 AX 字号确已生效（防启动参数静默失效）。
final class V381HomeShellCorrectionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 10), "Home 未出现")
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
    }

    // MARK: - Helpers（与 V38TodoRebuildUITests 同范式）

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// WorkRow 按钮 label 会拼尾值，用 BEGINSWITH 匹配（与 R2 已验证范式一致）。
    private func labeledElement(_ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }

    private func attachScreenshot(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 截图整体平均亮度（0–1）：16×16 缩绘 + Rec.709 加权（与 R2/R3/R4 同法）。
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

    /// 经生产 UI 设置显示模式：首页头像 → 我的 → 显示模式 → 选项 → 返回首页根部。
    private func setDisplayMode(_ optionLabel: String) {
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
        XCTAssertTrue(
            waitUntil(timeout: 5) { !self.labeledElement(optionLabel).exists },
            "显示模式 sheet 未关闭"
        )
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 5), "未返回首页")
    }

    private func tapLabeled(_ label: String) {
        let target = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5), "未找到元素：\(label)")
        target.tap()
    }

    // MARK: - 减法回归 + 截图交付：默认态 × Light/Dark（快捷行已删）

    func testHomeDefaultScreenshotsLightDarkWithoutQuickRow() {
        // —— Light 默认态 ——
        // 亮度阈值按 Home 实测校准：深绿 Hero 约占屏 1/4，全图均值 ≈0.68
        // （run 39906659467 实测 0.684；Todo 页无大色块故其基线 0.93 不适用）。
        // 与 Dark 实测 0.13–0.17 相比，0.55 阈值仍可决定性区分真 Light/假 Dark。
        XCTAssertTrue(element("v38.home.hero").waitForExistence(timeout: 10), "Light 下 Hero 未出现")
        assertQuickRowAbsent(schemeName: "Light")
        let lightDefault = app.screenshot()
        attachScreenshot(lightDefault, named: "v381-home-default-light")
        XCTAssertGreaterThan(meanLuminance(of: lightDefault), 0.55, "Light 默认截图亮度异常")

        // —— Dark（生产主题路径）默认态 ——
        setDisplayMode("深色模式")
        XCTAssertTrue(element("v38.home.hero").waitForExistence(timeout: 10), "Dark 下 Hero 未出现")
        assertQuickRowAbsent(schemeName: "Dark")
        let darkDefault = app.screenshot()
        attachScreenshot(darkDefault, named: "v381-home-default-dark")
        XCTAssertLessThan(meanLuminance(of: darkDefault), 0.45, "Dark 默认截图未真生效")

        // 恢复「跟随系统」，不污染后续测试（themeMode 持久化于 UserDefaults）。
        setDisplayMode("跟随系统")
    }

    /// 2026-10-23 减法回归：被删的快捷入口在任何 scheme 下都不得出现，
    /// 而保留区块（Hero / AI 胶囊 / 今日事项）必须在位。
    private func assertQuickRowAbsent(schemeName: String) {
        XCTAssertTrue(
            element("v38.home.ai.openSheet").waitForExistence(timeout: 5),
            "\(schemeName) 下 AI 胶囊（保留入口）未出现"
        )
        XCTAssertFalse(element("v38.home.quick.expand").exists, "\(schemeName) 下快捷菜单胶囊不得出现")
        XCTAssertFalse(element("v38.home.quick.collapse").exists, "\(schemeName) 下快捷菜单面板不得出现")
        XCTAssertFalse(element("home.quickRecord").exists, "\(schemeName) 下独立写备忘按钮不得出现")
        XCTAssertFalse(app.staticTexts["快速记一笔"].exists, "\(schemeName) 下「快速记一笔」标题不得出现")
        XCTAssertFalse(app.staticTexts["快速操作"].exists, "\(schemeName) 下「快速操作」面板不得出现")
    }

    // MARK: - P0-2 四页末尾内容不被浮动 Tab 栏遮挡

    func testScrollEndClearsFloatingTabBarOnAllTabs() {
        let tabs: [(tabLabel: String, marker: String)] = [
            ("首页", "scrollEnd.home"),
            ("待办", "scrollEnd.todo"),
            ("日历", "scrollEnd.calendar"),
            ("经营", "scrollEnd.business"),
        ]
        // 浮动栏胶囊顶边 ≈ Tab 按钮顶边 − 6pt（胶囊内边距）。
        let tabButtons = app.tabBars.buttons.allElementsBoundByIndex
        XCTAssertFalse(tabButtons.isEmpty, "Tab 栏按钮不存在")
        let capsuleTop = tabButtons.map(\.frame.minY).min()! - 6

        for (tabLabel, markerID) in tabs {
            app.tabBars.buttons[tabLabel].tap()
            let marker = element(markerID)
            XCTAssertTrue(marker.waitForExistence(timeout: 10), "\(tabLabel) 末尾标记不存在")
            // 内容是否溢出视口：未滚动时末尾已可命中 = 内容未溢出，其末尾
            // 停在内容自然高度、距栏较远属正常排版（run 39901163760 待办页
            // 实测 gap=375 即此情形）；「留白上限」只对溢出页生效——那类
            // 页面必须靠滚动才能够到末尾，静止间隙才反映预留是否过量。
            // 遮挡双断言（可命中 + frame 在栏上方）对所有页无条件执行。
            let overflowsViewport = !marker.isHittable
            // 滑到静止：连续两次 frame 不变且可命中视为到达最大滚动位。
            var lastFrame: CGRect = .null
            for _ in 0..<15 {
                app.swipeUp()
                Thread.sleep(forTimeInterval: 0.3)
                let frame = marker.frame
                if marker.isHittable && frame == lastFrame { break }
                lastFrame = frame
            }
            XCTAssertTrue(
                marker.isHittable,
                "\(tabLabel) 末尾标记在最大滚动时仍不可命中（疑被浮动栏遮挡）：frame=\(marker.frame)"
            )
            XCTAssertLessThanOrEqual(
                marker.frame.maxY, capsuleTop + 2,
                "\(tabLabel) 末尾被浮动 Tab 栏遮挡：marker.maxY=\(marker.frame.maxY) capsuleTop≈\(capsuleTop)"
            )
            if overflowsViewport {
                XCTAssertLessThanOrEqual(
                    capsuleTop - marker.frame.maxY, 90,
                    "\(tabLabel) 底部留白过量：gap=\(capsuleTop - marker.frame.maxY)"
                )
            }
        }
    }

    // MARK: - P0-4 保留胶囊（AI）标题单行（默认 + AX 特大字号）

    func testCapsuleTitlesStaySingleLineAtDefaultAndAccessibilitySizes() {
        // —— 默认字号：AI 胶囊标题单行 ——
        // （「快速记一笔 / 写备忘」胶囊已于 2026-10-23 整行删除，此处只验保留胶囊。）
        let aiTitle = app.staticTexts["问小掌柜…"].firstMatch
        XCTAssertTrue(aiTitle.waitForExistence(timeout: 10), "AI 胶囊标题不存在")
        XCTAssertLessThanOrEqual(
            aiTitle.frame.height, 30,
            "默认字号下 AI 胶囊标题应为单行，实际高度 \(aiTitle.frame.height)"
        )
        let defaultAITitleHeight = aiTitle.frame.height

        // —— AX 特大字号（启动参数设定首选内容尺寸类别）——
        let axApp = XCUIApplication()
        axApp.launchArguments = [
            "--ui-testing", "--ui-testing-id", UUID().uuidString,
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        axApp.launch()
        defer { axApp.terminate() }
        XCTAssertTrue(axApp.wait(for: .runningForeground, timeout: 20))
        let axHome = axApp.descendants(matching: .any).matching(identifier: "screen.home").firstMatch
        XCTAssertTrue(axHome.waitForExistence(timeout: 10), "AX 字号下 Home 未出现")

        // 先证明字号确已生效：AI 胶囊标题（.body 字体，随 Dynamic Type 缩放）显著变高。
        let axAITitle = axApp.staticTexts["问小掌柜…"].firstMatch
        XCTAssertTrue(axAITitle.waitForExistence(timeout: 10), "AX 字号下 AI 胶囊标题不存在")
        XCTAssertGreaterThan(
            axAITitle.frame.height, defaultAITitleHeight + 8,
            "AX 字号未生效：default=\(defaultAITitleHeight) ax=\(axAITitle.frame.height)"
        )

        // 标题保持单行且不溢出胶囊宽度（两行将 ≥ 约 100pt，64 上限可决定性区分）。
        let axAIButton = axApp.descendants(matching: .any).matching(identifier: "v38.home.ai.openSheet").firstMatch
        XCTAssertTrue(axAIButton.waitForExistence(timeout: 10), "AX 字号下 AI 胶囊不存在")
        XCTAssertLessThanOrEqual(
            axAITitle.frame.height, 64,
            "AX 字号下 AI 胶囊标题应保持单行，实际高度 \(axAITitle.frame.height)"
        )
        XCTAssertLessThanOrEqual(
            axAITitle.frame.width, axAIButton.frame.width + 1,
            "AX 字号下 AI 胶囊标题溢出胶囊宽度"
        )
        // 减法回归：AX 字号下被删入口同样不得出现（防大字号布局分支残留）。
        let axQuick = axApp.descendants(matching: .any).matching(identifier: "v38.home.quick.expand").firstMatch
        XCTAssertFalse(axQuick.exists, "AX 字号下快捷菜单胶囊不得出现")
        let axMemo = axApp.descendants(matching: .any).matching(identifier: "home.quickRecord").firstMatch
        XCTAssertFalse(axMemo.exists, "AX 字号下独立写备忘按钮不得出现")
        attachScreenshot(axApp.screenshot(), named: "v381-home-accessibility-xxxL")
    }
}
