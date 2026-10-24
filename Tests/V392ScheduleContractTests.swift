import XCTest

/// V3.9.2 PR-K · 日历页 V39 化契约(源码审计,同 HomeQuickEntryAuditTests 模式:
/// 纯 SwiftUI 视图不做渲染比对,xcodebuild test 在同一工作区,#filePath 定位源文件)。
///
/// 锁定三件事:
/// 1. 金语言落地:今日固定金圆(heroGold/heroInk)、选中金环、chips 金底、操作色金;
/// 2. 旧蓝绿 accent 退场:ScheduleView 内不得再出现 V38ScheduleStyle.accent;
/// 3. 业务链零改动:锚点布局/ghost 沉降/两段式勾选/标识符全部保持。
final class V392ScheduleContractTests: XCTestCase {

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/
            .appendingPathComponent("..")
            .standardized
    }

    private func source(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot().appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    func testGoldLanguageApplied() throws {
        let schedule = try source("XiaoZhangGui/Features/Schedule/ScheduleView.swift")
        XCTAssertTrue(schedule.contains("V39Palette.heroGold"), "今日圆必须用固定香槟金(深浅系统同色)")
        XCTAssertTrue(schedule.contains("V39Palette.heroInk"), "金底必须配深墨字(白字对比不足)")
        XCTAssertTrue(schedule.contains("V39Style.gold.opacity(0.14)"), "选中淡底为金")
        XCTAssertTrue(schedule.contains("fill(V39Style.gold)"), "密度 chip 激活底为金")
        // 操作色:今天按钮 + 新增待办 = 金(至少两处 gold 前景)。
        let foregroundGolds = schedule.components(separatedBy: ".foregroundStyle(V39Style.gold)").count - 1
        XCTAssertGreaterThanOrEqual(foregroundGolds, 2, "「今天」与「+」操作色须为金")
    }

    func testLegacyAccentFullyRetired() throws {
        let schedule = try source("XiaoZhangGui/Features/Schedule/ScheduleView.swift")
        XCTAssertFalse(
            schedule.contains("V38ScheduleStyle.accent"),
            "V3.8 深绿 accent 已被 V39 金语言整体替代,不得混用"
        )
    }

    func testBusinessChainUntouched() throws {
        let schedule = try source("XiaoZhangGui/Features/Schedule/ScheduleView.swift")
        // V3.8 R3 锚点布局与 ghost 沉降(P1-B1)必须原样保留。
        XCTAssertTrue(schedule.contains("V38ScheduleLayout.rows"))
        XCTAssertTrue(schedule.contains("settledPresentation"))
        XCTAssertTrue(schedule.contains("settleWeekGhosts"))
        XCTAssertTrue(schedule.contains("weekGhostSettled"))
        // 两段式勾选持久化(G5:持久化前不宣告成功)必须原样保留。
        XCTAssertTrue(schedule.contains("V38TodoToggleFlow.begin"))
        XCTAssertTrue(schedule.contains("V38TodoToggleFlow.resolve"))
        // 既有无障碍/UI 测试标识符不得丢失。
        XCTAssertTrue(schedule.contains("v38.schedule.day."))
        XCTAssertTrue(schedule.contains("V371AccessibilityID.todoAdd"))
        XCTAssertTrue(schedule.contains("V371AccessibilityID.scrollEndCalendar"))
        // 状态色语义:收入绿点/待办蓝点仍在(金只接管「今日/选中/操作」,不碰状态色)。
        XCTAssertTrue(schedule.contains("ScheduleEventDot(color: V371.Colors.green)"))
        XCTAssertTrue(schedule.contains("ScheduleEventDot(color: V371.Colors.blue)"))
        XCTAssertTrue(schedule.contains("ScheduleEventDot(color: V371.Colors.orange)"))
    }

    func testTodayMarkerUsesFixedPairForContrast() throws {
        let schedule = try source("XiaoZhangGui/Features/Schedule/ScheduleView.swift")
        // 今日数字必须用 heroInk(金底深墨 ≈9:1),不得回退白字。
        XCTAssertFalse(
            schedule.contains("isToday ? Color.white"),
            "金底白字对比不足(P0-2 教训),今日数字必须深墨"
        )
        XCTAssertTrue(schedule.contains("isToday ? V39Palette.heroInk"))
    }
}
