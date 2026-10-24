import XCTest

/// V3.9 F1 回归：日历页 AX3 下密度切换可达。
///
/// F1 根因：密度 chips 只在非无障碍字号分支渲染，无障碍字号下整段缺失
///（AX3 下原位 + 上滑一屏都找不到）。修复后两档均渲染，且周档列表同步响应 density。
/// 字号注入沿用字体截图任务验证过的 -UIPreferredContentSizeCategoryName 方式。
final class V39ScheduleAX3UITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--ui-testing-id", UUID().uuidString,
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        app.tabBars.buttons["日历"].tap()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func scrollToDensityChips() {
        let chip = element("v38.schedule.density.week")
        let scroll = app.scrollViews.firstMatch
        var tries = 0
        while !chip.isHittable && tries < 10 {
            scroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
            tries += 1
        }
        XCTAssertTrue(chip.isHittable, "AX3 下密度切换 chips 未能滚动到可见")
    }

    func testAX3DensityToggleExistsAndSwitches() {
        scrollToDensityChips()
        let month = element("v38.schedule.density.month")
        let week = element("v38.schedule.density.week")
        XCTAssertTrue(month.isHittable, "AX3 下月密度切换必须可命中")
        XCTAssertTrue(week.isHittable, "AX3 下周密度切换必须可命中")
        week.tap()
        XCTAssertTrue(week.isSelected, "切换后周 chip 必须为选中态")
        month.tap()
        XCTAssertTrue(month.isSelected, "切回后月 chip 必须为选中态")
    }
}
