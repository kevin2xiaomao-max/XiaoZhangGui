import XCTest

/// V3.8.1 真机纠偏 · 线 B（Performance 图表）UI 测试。
///
/// - **P0-3**：月趋势截图 —— 30 个数据点全在，X 轴标签抽稀后不再重叠
///   （附件供目检）；周趋势 7 个日期标签完整。
/// - **P1-7**：在图表上拖动选中某日 → 读数行显示该日日期与金额。
/// - **P0-4（经营页落点）**：大字号下周期/分类 chip 同行等高（不折行错乱）、均存在。
/// - Light/Dark 截图走 App 生产主题路径 + 像素亮度自证
///   （禁用 XCUIDevice.appearance / 启动参数法 —— 前序实测均为假 Dark）。
final class V38PerformanceChartCorrectionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-id", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        XCTAssertTrue(
            app.otherElements["screen.home"].waitForExistence(timeout: 10),
            "Home 未出现"
        )
        openBusinessTab()
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
    }

    // MARK: - Helpers（与 R4 UI 测试同一套已验证口径）

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waitForElement(_ identifier: String, timeout: TimeInterval = 10) -> Bool {
        let el = element(identifier)
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if el.exists { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return el.exists
    }

    private func openBusinessTab() {
        let tab = app.tabBars.buttons["经营"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "经营 Tab 不存在")
        tab.tap()
        XCTAssertTrue(
            element("screen.business").waitForExistence(timeout: 10),
            "经营页未出现"
        )
    }

    private func tapChip(_ identifier: String) {
        let chip = element(identifier)
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "chip 不存在：\(identifier)")
        for _ in 0..<6 where !chip.isHittable { app.swipeUp() }
        XCTAssertTrue(chip.isHittable, "chip 不可点击：\(identifier)")
        chip.tap()
    }

    private func attachScreenshot(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 截图整体平均亮度（0–1）：缩绘到 16×16 后按 Rec.709 加权（同 R2/R4 口径）。
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

    // MARK: - P1-7：拖动选中某日 → 读数行显示日期与金额

    func testChartDragSelectionShowsDateAndAmount() {
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 10), "趋势图未渲染")
        tapChip("v38.performance.period.month")
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 5), "切到月后趋势图消失")

        let readout = element("v38.performance.chartSelection")
        XCTAssertTrue(readout.waitForExistence(timeout: 5), "选中读数行不存在")
        XCTAssertFalse(readout.label.contains("¥"), "未选中时读数行应为提示文案：\(readout.label)")

        // 在图表上横向拖动（chartXSelection 原生手势），选中某日。
        let chart = element("v38.performance.chart")
        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.6))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.6))
        start.press(forDuration: 0.1, thenDragTo: end)

        // 轮询等待读数行变为「已选日期 M/d · ¥金额」。
        let deadline = Date().addingTimeInterval(8)
        var label = readout.label
        while Date() < deadline {
            label = readout.label
            if label.contains("¥") && label.contains("已选") { break }
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertTrue(label.contains("已选"), "拖动后读数行应进入已选态：\(label)")
        XCTAssertTrue(label.contains("¥"), "读数行必须显示该日真实金额：\(label)")
        attachScreenshot(app.screenshot(), named: "v38-performance-chart-month-selected-light")
    }

    // MARK: - P0-3 截图：周/月趋势 × Light/Dark（月标签抽稀目检）

    func testChartWeekMonthLightDarkScreenshots() {
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 10), "趋势图未渲染")

        // Light（默认外观）：周视图（默认周期）→ 月视图。
        let weekLight = app.screenshot()
        attachScreenshot(weekLight, named: "v38-performance-chart-week-light")
        XCTAssertGreaterThan(meanLuminance(of: weekLight), 0.7, "周图 Light 亮度异常")

        tapChip("v38.performance.period.month")
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 5), "切到月后趋势图消失")
        let monthLight = app.screenshot()
        attachScreenshot(monthLight, named: "v38-performance-chart-month-light")
        XCTAssertGreaterThan(meanLuminance(of: monthLight), 0.7, "月图 Light 亮度异常")

        // Dark：走 App 生产主题路径（AppSettings.themeMode），测后恢复跟随系统。
        setDisplayMode("深色模式")
        openBusinessTab()
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 10), "Dark 下趋势图未渲染")
        // 显式再点月 chip，保证截图周期确定（不依赖页面状态在切 Tab 后是否保留）。
        tapChip("v38.performance.period.month")
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 5), "Dark 下切到月后趋势图消失")
        let monthDark = app.screenshot()
        attachScreenshot(monthDark, named: "v38-performance-chart-month-dark")
        XCTAssertLessThan(meanLuminance(of: monthDark), 0.45, "月图 Dark 未真生效")

        tapChip("v38.performance.period.week")
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 5), "Dark 下切回周后趋势图消失")
        let weekDark = app.screenshot()
        attachScreenshot(weekDark, named: "v38-performance-chart-week-dark")
        XCTAssertLessThan(meanLuminance(of: weekDark), 0.45, "周图 Dark 未真生效")

        setDisplayMode("跟随系统")
    }

    // MARK: - P0-4（经营页落点）：大字号下 chip 不折行错乱

    func testChipsStaySingleLineAtAccessibilityTextSize() throws {
        // 以无障碍大字号重启（-UIPreferredContentSizeCategoryName 为系统
        // 认可的启动参数；即便个别 harness 不生效，下面的等高断言在
        // 默认字号下同样成立，仍可守住「折行导致高度不一致」的回归）。
        app.terminate()
        let bigApp = XCUIApplication()
        bigApp.launchArguments = [
            "--ui-testing", "--ui-testing-id", UUID().uuidString,
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        bigApp.launch()
        app = bigApp
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        XCTAssertTrue(app.otherElements["screen.home"].waitForExistence(timeout: 10), "Home 未出现")
        openBusinessTab()

        let periodIDs = [
            "v38.performance.period.day",
            "v38.performance.period.week",
            "v38.performance.period.month",
        ]
        let sourceIDs = [
            "v38.performance.source.all",
            "v38.performance.source.store",
            "v38.performance.source.meituan",
            "v38.performance.source.other",
        ]
        for id in periodIDs + sourceIDs {
            XCTAssertTrue(waitForElement(id, timeout: 8), "大字号下 chip 缺失：\(id)")
        }
        // 同行 chip 必须等高：文案折行成两行会让该 chip 明显更高。
        func assertUniformHeights(_ ids: [String], _ name: String) {
            let heights = ids.map { element($0).frame.height }
            guard let minH = heights.min(), let maxH = heights.max() else {
                return XCTFail("\(name) chip 高度读取失败")
            }
            XCTAssertLessThanOrEqual(
                maxH - minH, 1.5,
                "\(name) chip 高度不一致（疑似文案折行）：\(heights)"
            )
            XCTAssertGreaterThanOrEqual(minH, 44, "\(name) chip 触点高度不得小于 44：\(heights)")
        }
        // 周期行在首屏；分类行先滚入视图再量（frame 在屏外时不可靠）。
        assertUniformHeights(periodIDs, "周期")
        for _ in 0..<6 where !element(sourceIDs[0]).isHittable { app.swipeUp() }
        assertUniformHeights(sourceIDs, "分类")
    }

    // MARK: - 显示模式（生产路径，同 R4 口径）

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
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: labeledElement(optionLabel)
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [gone], timeout: 5), .completed,
            "显示模式 sheet 未关闭"
        )
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 5), "未返回首页")
    }

    private func labeledElement(_ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    private func tapLabeled(_ label: String) {
        let target = labeledElement(label)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "未找到元素：\(label)")
        target.tap()
    }
}
