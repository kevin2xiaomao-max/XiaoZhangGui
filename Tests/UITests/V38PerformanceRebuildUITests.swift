import XCTest

/// V3.8 重建 R4 · Performance 经营页生产级 UI 测试。
///
/// 在真实生产 App（`--ui-testing`）验证：
/// - Editorial Hero 渲染且金额为真实种子数据（美团 ¥680.00），非占位
/// - 收入分类 chip 切换 → 汇总数字随分类变化（全部 680 / 门店 0 / 美团 680）
/// - 图表周期 chip 切换（日/周/月）→ 图表保持渲染
/// - Light/Dark 截图（CI 产物）
final class V38PerformanceRebuildUITests: XCTestCase {
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

    /// 使用 `.any` 类型匹配（Worker B 实证：玻璃/形变容器上的 identifier
    /// 可能不暴露为特定类型，用 descendants(.any) 最可靠）。
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

    /// 原生 TabView 在 iOS 27 以真实标签定位（对齐 smoke 测试的 P0-A 结论）。
    private func openBusinessTab() {
        let tab = app.tabBars.buttons["经营"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "经营 Tab 不存在")
        tab.tap()
        XCTAssertTrue(
            element("screen.business").waitForExistence(timeout: 10),
            "经营页未出现"
        )
    }

    /// chip 可能在折叠线以下：先滚动到可点再点。
    private func tapChip(_ identifier: String) {
        let chip = element(identifier)
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "chip 不存在：\(identifier)")
        for _ in 0..<6 where !chip.isHittable { app.swipeUp() }
        XCTAssertTrue(chip.isHittable, "chip 不可点击：\(identifier)")
        chip.tap()
    }

    /// 轮询等待金额文本变为期望值（numericText 动画期间 AX 标签可能滞后）。
    private func waitForAmount(_ identifier: String, equals expected: String, timeout: TimeInterval = 8) -> Bool {
        let el = element(identifier)
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if el.exists && el.label == expected { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return el.exists && el.label == expected
    }

    // MARK: - Hero：Editorial 大数字 + 真实金额

    func testHeroShowsRealSeedRevenue() {
        XCTAssertTrue(waitForElement("v38.performance.hero", timeout: 10), "Hero 未渲染")
        let hero = element("v38.performance.hero")
        // UITestSeed：今日一条美团营业额 680 → 本月营业额 ¥680.00（真实数据）。
        XCTAssertTrue(hero.label.contains("本月营业额"), "Hero 标签缺少标题：\(hero.label)")
        XCTAssertTrue(hero.label.contains("¥680.00"), "Hero 必须显示真实金额 ¥680.00：\(hero.label)")
        XCTAssertFalse(hero.label.contains("¥ —"), "Hero 不得显示占位金额：\(hero.label)")
    }

    // MARK: - 收入分类 chip：切换后汇总数字随分类变化

    func testSourceChipSwitchingUpdatesSummaryAmount() {
        // 初始「全部」：¥680.00
        XCTAssertTrue(
            waitForAmount("v38.performance.sourceAmount", equals: "¥680.00"),
            "全部口径汇总应为 ¥680.00，实际：\(element("v38.performance.sourceAmount").label)"
        )
        // 切到「门店」：种子无门店收入 → ¥0.00
        tapChip("v38.performance.source.store")
        XCTAssertTrue(
            waitForAmount("v38.performance.sourceAmount", equals: "¥0.00"),
            "门店汇总应为 ¥0.00，实际：\(element("v38.performance.sourceAmount").label)"
        )
        // 切到「美团」：¥680.00
        tapChip("v38.performance.source.meituan")
        XCTAssertTrue(
            waitForAmount("v38.performance.sourceAmount", equals: "¥680.00"),
            "美团汇总应为 ¥680.00，实际：\(element("v38.performance.sourceAmount").label)"
        )
        // 切回「全部」：¥680.00（口径闭环）
        tapChip("v38.performance.source.all")
        XCTAssertTrue(
            waitForAmount("v38.performance.sourceAmount", equals: "¥680.00"),
            "切回全部应为 ¥680.00，实际：\(element("v38.performance.sourceAmount").label)"
        )
    }

    // MARK: - 图表周期 chip：日/周/月切换后图表保持渲染

    func testPeriodChipSwitchingKeepsChart() {
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 10), "趋势图未渲染")
        tapChip("v38.performance.period.month")
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 5), "切到月后趋势图消失")
        tapChip("v38.performance.period.day")
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 5), "切到日后趋势图消失")
        tapChip("v38.performance.period.week")
        XCTAssertTrue(waitForElement("v38.performance.chart", timeout: 5), "切回周后趋势图消失")
    }

    // MARK: - 截图（CI 产物，Light / Dark，生产主题路径 + 像素亮度自证）

    func testPerformanceLightDarkScreenshots() {
        // 外观切换走 App 生产路径（我的 → 显示模式 → 浅色/深色模式）：
        // XCUIDevice.appearance 在本 harness 下不传导到本 App 渲染
        // （R2 实测其 Dark 截图亮度 0.9346 ≈ Light 0.933，假 Dark）；
        // -AppleInterfaceStyle 启动参数同样无效（R4 run 39794230701
        // 的 Light/Dark 附件逐字节相同、被 xcresult 内容哈希去重）。
        // 改用 App 自带 AppSettings.themeMode（settings.colorScheme，
        // 立即生效，与 R2 同一解法）。每相位截图做像素亮度断言，
        // 未真生效会明确失败，不产出假图。
        setDisplayMode("浅色模式")
        openBusinessTab()
        XCTAssertTrue(waitForElement("v38.performance.hero", timeout: 10))
        let lightShot = app.screenshot()
        attachScreenshot(lightShot, named: "v38-performance-rebuild-light")
        // 像素级自证：Light 渲染整体高亮（实测基线 ≈0.92），断言 >0.7 留足余量。
        let lightLuminance = meanLuminance(of: lightShot)
        XCTAssertGreaterThan(lightLuminance, 0.7, "Light 截图亮度异常：\(lightLuminance)")

        setDisplayMode("深色模式")
        openBusinessTab()
        XCTAssertTrue(waitForElement("v38.performance.hero", timeout: 10))
        let darkShot = app.screenshot()
        attachScreenshot(darkShot, named: "v38-performance-rebuild-dark")
        // 像素级自证：Dark 必须真生效（墨绿黑底，整体低亮）。
        let darkLuminance = meanLuminance(of: darkShot)
        XCTAssertLessThan(darkLuminance, 0.45, "Dark 截图未真生效，亮度：\(darkLuminance)")

        // themeMode 持久化在 UserDefaults：恢复「跟随系统」，不污染后续测试。
        setDisplayMode("跟随系统")
    }

    /// 经生产 UI 设置显示模式：首页头像 → 我的 → 显示模式 sheet → 选项（选后自动关闭）→ 返回。
    private func setDisplayMode(_ optionLabel: String) {
        // 先回到首页根部：在经营 tab 时切回首页；若「我的」还压在首页栈上，先点返回弹出。
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
        // 选项点击后 sheet 自动 dismiss：用谓词期望等选项元素消失
        // （不用 Thread.sleep 轮询，避免饿死 AX runloop）。
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
