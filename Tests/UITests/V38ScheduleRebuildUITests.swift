import UIKit
import XCTest

/// V3.8 重建 R3 · 日历生产级 UI 测试。
///
/// 在真实生产 App（`--ui-testing`）验证 Spec §3 的核心承诺：
/// - 月/周密度切换 20 次后 `selectedDate` 不漂移（选中格始终为同一天）
/// - 选中格相对地标（密度 chip）的像素位置不变（锚点位移 ≤1pt，实测 frame）
/// - 周密度下非选中周的日期不可达（ghost/collapsed 行不拦截、不播报）
/// - 点按其他日期可正常移动选中（原有选择路由不变）
/// - Light/Dark 截图为真实渲染（像素亮度断言 + keepAlways 附件）
final class V38ScheduleRebuildUITests: XCTestCase {
    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
    }

    private func launch(extraArguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-id", UUID().uuidString] + extraArguments
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        openCalendarTab()
    }

    private func openCalendarTab() {
        app.tabBars.buttons["日历"].tap()
        XCTAssertTrue(
            element(V371AccessibilityIDCompat.screenCalendar).waitForExistence(timeout: 10),
            "日历页未出现"
        )
    }

    // MARK: - Helpers

    /// 与 R1 一致：用 `.any` 匹配 identifier，避免容器类型差异。
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func isoString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func dayCell(_ date: Date) -> XCUIElement {
        element("v38.schedule.day.\(isoString(date))")
    }

    /// 滚动到月历网格可见（密度 chips 可点）。
    private func scrollToGrid() {
        let chip = element("v38.schedule.density.week")
        let scroll = app.scrollViews.firstMatch
        var tries = 0
        while !chip.isHittable && tries < 8 {
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
            tries += 1
        }
        XCTAssertTrue(chip.isHittable, "密度切换 chips 未能滚动到可见")
    }

    /// 相对地标坐标（选中格中心 − 地标原点）：布局锚点的直接度量。
    /// 地标与网格同处一个滚动内容、相对位置不随密度变化，故该度量
    /// 不受 ScrollView 偏移/钳制影响。
    private func relativeCenter(of cell: XCUIElement, in landmark: XCUIElement) -> CGPoint {
        let f = cell.frame
        let g = landmark.frame
        return CGPoint(x: f.midX - g.minX, y: f.midY - g.minY)
    }

    /// masthead 大日期文本（如「10月22日」）：`selectedDate` 的生产 UI 直接信号，
    /// 作为选中日期未漂移的行为级共证（不单独依赖 isSelected trait 反射）。
    private func mastheadShows(_ date: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        let text = "\(cal.component(.month, from: date))月\(cal.component(.day, from: date))日"
        return app.staticTexts[text].exists
    }

    // MARK: - 核心：20 次密度切换后 selectedDate 与锚点均不漂移

    func testDensityToggle20TimesKeepsSelectedDateAndAnchor() {
        launch()
        // 归一化选中为今天（masthead「回到今天」，页面初始在顶部可见）
        let todayButton = app.buttons["回到今天"]
        XCTAssertTrue(todayButton.waitForExistence(timeout: 10))
        todayButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        scrollToGrid()

        let today = Date()
        let cell = dayCell(today)
        // 几何地标：密度 chip（月）按钮。不用网格容器作地标——容器挂
        // identifier 会遮蔽日期格按钮的 identifier（R1 实证），生产代码
        // 已移除 `v38.schedule.grid`（见 ScheduleView.monthGrid 注释）。
        let grid = element("v38.schedule.density.month")
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "今日日期格未找到")
        XCTAssertTrue(cell.isSelected, "今日应为选中日期")
        XCTAssertTrue(mastheadShows(today), "masthead 未显示今日为选中日期")

        let before = relativeCenter(of: cell, in: grid)
        let windowBefore = cell.frame

        // 20 次切换（周→月 交替，偶数次回到月密度）
        for i in 1...20 {
            let target = i % 2 == 1 ? "v38.schedule.density.week" : "v38.schedule.density.month"
            element(target).tap()
            Thread.sleep(forTimeInterval: 0.6) // 等待 contentChange 动画（0.28s）收敛

            XCTAssertTrue(cell.isSelected, "第 \(i) 次切换后选中日期漂移（不再是今日）")
            XCTAssertTrue(mastheadShows(today), "第 \(i) 次切换后 masthead 选中日期漂移")
            if i == 1 {
                // 周密度下锚点实测：选中格相对地标的位置必须与月密度一致（≤1pt）
                let weekCenter = relativeCenter(of: cell, in: grid)
                XCTAssertLessThanOrEqual(abs(weekCenter.x - before.x), 1.0, "周密度锚点 X 位移超限：\(before.x) → \(weekCenter.x)")
                XCTAssertLessThanOrEqual(abs(weekCenter.y - before.y), 1.0, "周密度锚点 Y 位移超限：\(before.y) → \(weekCenter.y)")
                // 周密度下：非选中周的日期格不可达（ghost/collapsed 不拦截点按）
                if let other = otherWeekDayCell(excludingWeekOf: today) {
                    XCTAssertFalse(other.isHittable, "周密度下非选中周日期不应可达")
                }
            }
        }

        let after = relativeCenter(of: cell, in: grid)
        XCTAssertLessThanOrEqual(abs(after.x - before.x), 1.0, "锚点 X 位移超限：\(before.x) → \(after.x)")
        XCTAssertLessThanOrEqual(abs(after.y - before.y), 1.0, "锚点 Y 位移超限：\(before.y) → \(after.y)")
        // 窗口坐标同样应稳定（ScrollView 未发生钳制偏移时）
        XCTAssertLessThanOrEqual(abs(cell.frame.midX - windowBefore.midX), 1.0, "窗口 X 位移超限")
        XCTAssertLessThanOrEqual(abs(cell.frame.midY - windowBefore.midY), 1.0, "窗口 Y 位移超限")
    }

    /// 找一个与 today 不同周的当月日期格（用于周密度不可达断言）。
    private func otherWeekDayCell(excludingWeekOf date: Date) -> XCUIElement? {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        let comps = cal.dateComponents([.year, .month], from: date)
        guard let first = cal.date(from: comps),
              let days = cal.range(of: .day, in: .month, for: first)?.count else { return nil }
        let offset = cal.component(.weekday, from: first) - 1
        let todayRow = (offset + cal.component(.day, from: date) - 1) / 7
        for day in 1...days {
            let row = (offset + day - 1) / 7
            if row != todayRow, let d = cal.date(byAdding: .day, value: day - 1, to: first) {
                return dayCell(d)
            }
        }
        return nil
    }

    // MARK: - 选择路由不变：点按其他日期移动选中

    func testSelectingAnotherDayMovesSelection() {
        launch()
        scrollToGrid()

        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        let today = Date()
        // 目标：本月 15 日（若今日即 15 日则改选 16 日），与今日同屏可见于月网格
        var targetDay = 15
        if cal.component(.day, from: today) == 15 { targetDay = 16 }
        let first = cal.date(from: cal.dateComponents([.year, .month], from: today))!
        let target = cal.date(byAdding: .day, value: targetDay - 1, to: first)!

        let targetCell = dayCell(target)
        XCTAssertTrue(targetCell.waitForExistence(timeout: 10), "目标日期格未找到")
        if !targetCell.isHittable {
            app.scrollViews.firstMatch.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }
        targetCell.tap()
        Thread.sleep(forTimeInterval: 0.6)
        // 行为共证先于 trait 断言：masthead 大日期应已切换为目标日期
        // （selectedDate 的生产 UI 直接信号）。
        XCTAssertTrue(mastheadShows(target), "点按后 masthead 未切换到目标日期")
        XCTAssertTrue(targetCell.isSelected, "点按后选中未移动到目标日期")
        XCTAssertFalse(dayCell(today).isSelected, "原今日格仍显示为选中")
    }

    // MARK: - Light/Dark 真实截图（像素亮度断言 + 附件）

    func testScheduleLightDarkScreenshots() {
        // Light（默认外观：跟随系统，CI 模拟器为浅色）
        launch()
        scrollToGrid()
        let lightShot = app.screenshot()
        attach(lightShot, name: "v38-schedule-rebuild-month-light")
        let lightLuminance = meanLuminance(of: lightShot)
        XCTAssertGreaterThan(lightLuminance, 0.7, "Light 截图亮度异常（疑似非浅色渲染）：\(lightLuminance)")
        // 周密度截图（Light）
        element("v38.schedule.density.week").tap()
        Thread.sleep(forTimeInterval: 0.6)
        attach(app.screenshot(), name: "v38-schedule-rebuild-week-light")
        element("v38.schedule.density.month").tap()
        Thread.sleep(forTimeInterval: 0.6)

        // Dark：走 App 生产路径切外观（我的 → 显示模式 → 深色模式，
        // 即 AppSettings.themeMode，切换立即生效）。启动参数
        // `-AppleInterfaceStyle` / XCUIDevice.appearance 在本 harness 下
        // 不传导到本 App 渲染——run 39794952408 实测其 Dark 截图亮度
        // 0.9446 ≈ Light（假 Dark），与 R2 run 39815551862 实测一致。
        setDisplayMode("深色模式")
        openCalendarTab()
        scrollToGrid()
        let darkShot = app.screenshot()
        attach(darkShot, name: "v38-schedule-rebuild-month-dark")
        let darkLuminance = meanLuminance(of: darkShot)
        XCTAssertLessThan(darkLuminance, 0.45, "Dark 截图未真生效（疑似未渲染深色）：\(darkLuminance)")

        // themeMode 持久化在 UserDefaults：恢复「跟随系统」，不污染后续测试。
        setDisplayMode("跟随系统")
    }

    /// 经生产 UI 设置显示模式：首页头像 → 我的 → 显示模式 sheet → 选项
    /// （选后自动关闭）→ 返回首页根部。与 R2 已验证实现同构。
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

    private func waitUntil(timeout: TimeInterval = 8, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }

    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 截图整体平均亮度（0–1）：把截图缩绘到 16×16 位图后按 Rec.709 加权。
    /// 与 R2 已验证实现相同（全图均值，避免采样点落在控件/文字上失真）。
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

/// 测试内对生产 identifier 的引用（避免在测试 target 里重复硬编码主串）。
private enum V371AccessibilityIDCompat {
    static let screenCalendar = "screen.calendar"
}
