import XCTest
@testable import XiaoZhangGui

/// V3.9 F1 源码回归钉：日历 masthead 层级倒挂 + 密度切换无障碍缺失。
///
/// masthead 日期曾固定 30pt，AX3 下被星期副标题（.subheadline 随动）反超；
/// 密度 chips 曾只在非无障碍分支渲染。本测试钉住修复形态，行为由
/// V39ScheduleAX3UITests 在 AX3 真机语义下验证。
final class V39ScheduleAXTests: XCTestCase {
    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    func testMastheadDateScalesWithDynamicType() throws {
        let schedule = try source("XiaoZhangGui/Features/Schedule/ScheduleView.swift")
        XCTAssertTrue(
            schedule.contains("@ScaledMetric(relativeTo: .largeTitle) private var mastheadDateSize"),
            "masthead 日期必须随动态字体缩放（F1 层级倒挂回归钉）"
        )
        XCTAssertTrue(
            schedule.contains("fixedSize: mastheadDateSize)"),
            "masthead 日期必须使用缩放后的字号构造"
        )
    }

    func testDensityToggleAvailableInAccessibilitySizes() throws {
        let schedule = try source("XiaoZhangGui/Features/Schedule/ScheduleView.swift")
        // 无障碍列表必须响应 density（周档只列选中周行），否则 chips 即使渲染也形同虚设。
        XCTAssertTrue(
            schedule.contains("accessibleListDates"),
            "无障碍列表必须按 density 过滤（周档只列选中周行）"
        )
        XCTAssertTrue(
            schedule.contains("densityChips"),
            "密度切换必须在月历 Section 内渲染"
        )
    }
}
