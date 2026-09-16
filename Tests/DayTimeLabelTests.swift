import XCTest
@testable import XiaoZhangGui

/// B28 QA P1-3：全天 / 时间统一语义单测
/// 规则来源与 ScheduleAgenda.hasClock 保持一致（nil / 当天 00:00 = 全天）。
/// 验收：全天事项在任何页面都不出现 00:00。
final class DayTimeLabelTests: XCTestCase {

    @MainActor
    private func todayAt(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    @MainActor
    private func yesterdayAt(hour: Int, minute: Int) -> Date {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: yesterday)!
    }

    // MARK: hasClock 与 ScheduleAgenda 同一规则

    @MainActor
    func testHasClockMatchesScheduleAgendaRule() {
        XCTAssertFalse(DayTimeLabel.hasClock(nil), "nil = 全天")
        XCTAssertFalse(DayTimeLabel.hasClock(todayAt(hour: 0, minute: 0)), "日期级 00:00 = 全天")
        XCTAssertTrue(DayTimeLabel.hasClock(todayAt(hour: 9, minute: 30)), "真实钟点才算定时")
        XCTAssertEqual(DayTimeLabel.hasClock(todayAt(hour: 0, minute: 0)), ScheduleAgenda.hasClock(todayAt(hour: 0, minute: 0)))
    }

    // MARK: label 输出

    @MainActor
    func testLabelNilUsesUnscheduledText() {
        XCTAssertEqual(DayTimeLabel.label(nil, unscheduledText: "待安排"), "待安排")
        XCTAssertEqual(DayTimeLabel.label(nil, unscheduledText: "全天"), "全天")
    }

    @MainActor
    func testLabelTodayMidnightIsAllDayNot0000() {
        let label = DayTimeLabel.label(todayAt(hour: 0, minute: 0), unscheduledText: "待安排")
        XCTAssertEqual(label, "全天")
        XCTAssertFalse(label.contains("00:00"), "全天事项不允许出现 00:00")
        XCTAssertFalse(label.contains("0:00"))
    }

    @MainActor
    func testLabelTodayWithClockShowsTime() {
        let date = todayAt(hour: 9, minute: 30)
        let label = DayTimeLabel.label(date, unscheduledText: "待安排")
        XCTAssertEqual(label, Fmt.time(date))
        XCTAssertNotEqual(label, "全天")
    }

    @MainActor
    func testLabelOtherDayMidnightHasNoClock() {
        let date = yesterdayAt(hour: 0, minute: 0)
        let label = DayTimeLabel.label(date, unscheduledText: "待安排")
        XCTAssertEqual(label, Fmt.monthDay(date))
        XCTAssertFalse(label.contains("00:00"), "非当天的日期级 00:00 同样不能出现钟点")
    }

    @MainActor
    func testLabelOtherDayWithClockShowsMonthDayTime() {
        let date = yesterdayAt(hour: 15, minute: 5)
        XCTAssertEqual(DayTimeLabel.label(date, unscheduledText: "待安排"), Fmt.monthDayTime(date))
    }
}
