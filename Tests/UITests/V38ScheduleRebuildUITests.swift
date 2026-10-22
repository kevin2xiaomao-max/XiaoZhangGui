import UIKit
import XCTest

/// V3.8 重建 R3 · 日历生产级 UI 测试。
///
/// 在真实生产 App（`--ui-testing`）验证 Spec §3 的核心承诺：
/// - 月/周密度切换 20 次后 `selectedDate` 不漂移（选中格始终为同一天）
/// - 选中格相对网格容器的像素位置不变（锚点位移 ≤1pt，实测 frame）
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

    /// 网格内相对坐标（选中格中心 − 网格原点）：布局锚点的直接度量，
    /// 不受 ScrollView 偏移影响。
    private func relativeCenter(of cell: XCUIElement, in grid: XCUIElement) -> CGPoint {
        let f = cell.frame
        let g = grid.frame
        return CGPoint(x: f.midX - g.minX, y: f.midY - g.minY)
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
        let grid = element("v38.schedule.grid")
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "今日日期格未找到")
        XCTAssertTrue(cell.isSelected, "今日应为选中日期")

        let before = relativeCenter(of: cell, in: grid)
        let windowBefore = cell.frame

        // 20 次切换（周→月 交替，偶数次回到月密度）
        for i in 1...20 {
            let target = i % 2 == 1 ? "v38.schedule.density.week" : "v38.schedule.density.month"
            element(target).tap()
            Thread.sleep(forTimeInterval: 0.6) // 等待 contentChange 动画（0.28s）收敛

            XCTAssertTrue(cell.isSelected, "第 \(i) 次切换后选中日期漂移（不再是今日）")
            if i == 1 {
                // 周密度下锚点实测：选中格相对网格容器的位置必须与月密度一致（≤1pt）
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
        XCTAssertTrue(targetCell.isSelected, "点按后选中未移动到目标日期")
        XCTAssertFalse(dayCell(today).isSelected, "原今日格仍显示为选中")
    }

    // MARK: - Light/Dark 真实截图（像素亮度断言 + 附件）

    func testScheduleLightDarkScreenshots() {
        // Light（系统默认浅色，UITest 种子环境）
        launch()
        scrollToGrid()
        let lightShot = app.screenshot()
        attach(lightShot, name: "v38-schedule-rebuild-month-light")
        if let b = averageBrightness(of: lightShot) {
            XCTAssertGreaterThan(b, 0.7, "Light 截图亮度异常（疑似非浅色渲染）：\(b)")
        }
        // 周密度截图（Light）
        element("v38.schedule.density.week").tap()
        Thread.sleep(forTimeInterval: 0.6)
        attach(app.screenshot(), name: "v38-schedule-rebuild-week-light")
        app.terminate()

        // Dark（启动参数指定深色外观）
        launch(extraArguments: ["-AppleInterfaceStyle", "Dark"])
        scrollToGrid()
        let darkShot = app.screenshot()
        attach(darkShot, name: "v38-schedule-rebuild-month-dark")
        if let b = averageBrightness(of: darkShot) {
            XCTAssertLessThan(b, 0.35, "Dark 截图亮度异常（疑似未渲染深色）：\(b)")
        }
    }

    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 采样截图左侧页边距区域多点亮度均值（画布色，避开文字与控件）。
    private func averageBrightness(of screenshot: XCUIScreenshot) -> Double? {
        let data = screenshot.pngRepresentation
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            return nil
        }
        let points = [(30, 200), (30, 320), (30, 440)]
        var values: [Double] = []
        for (x, y) in points {
            if let v = pixelBrightness(image, x: x, y: y) { values.append(v) }
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func pixelBrightness(_ image: CGImage, x: Int, y: Int) -> Double? {
        guard x < image.width, y < image.height else { return nil }
        var pixel: [UInt8] = [0, 0, 0, 0]
        guard let ctx = CGContext(
            data: &pixel, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // CGContext 原点在左下：把目标像素（左上原点坐标）平移到 (0, 0)
        ctx.translateBy(x: CGFloat(-x), y: CGFloat(-(image.height - 1 - y)))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return (0.299 * Double(pixel[0]) + 0.587 * Double(pixel[1]) + 0.114 * Double(pixel[2])) / 255.0
    }
}

/// 测试内对生产 identifier 的引用（避免在测试 target 里重复硬编码主串）。
private enum V371AccessibilityIDCompat {
    static let screenCalendar = "screen.calendar"
}
