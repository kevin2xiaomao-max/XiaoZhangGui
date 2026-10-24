import XCTest

/// V3.9.2 PR-P · UI 性能与无障碍契约(源码审计,同 V392ScheduleContractTests 模式:
/// 纯 SwiftUI 视觉层不做渲染比对,#filePath 定位源文件后断言结构)。
///
/// 锁定六件事:
/// 1. 日历页当日聚合只算一次(scheduleDay 是计算属性,每引用一次就重跑两次全表 filter);
/// 2. 月网格/首页的日期标识复用静态 DateFormatter,不逐格新建;
/// 3. 经营页近期记录一次求值(isEmpty 与 prefix 不各算一遍);
/// 4. 首页金色 Hero 卡有触感反馈;
/// 5. 待办行无障碍合并标题与元信息;
/// 6. 保存键置灰时必须给出原因(待办编辑 + 随手记)。
final class V392UIPerformanceContractTests: XCTestCase {

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

    func testScheduleDayEvaluatedOncePerSection() throws {
        let schedule = try source("XiaoZhangGui/Features/Schedule/ScheduleView.swift")
        let captures = schedule.components(separatedBy: "let day = scheduleDay").count - 1
        XCTAssertEqual(captures, 2, "时间轴与全天两块各取一次当日聚合,其余引用一律走 day")
        XCTAssertFalse(
            schedule.contains("private var allDayTodos"),
            "全天分组不得再经 4 个计算属性各自重算一遍 scheduleDay"
        )
        XCTAssertTrue(
            schedule.contains("private func allDayCount(_ day: ScheduleDay) -> String"),
            "全天计数改为接收已聚合的 day"
        )
    }

    func testDateFormattersAreCached() throws {
        let schedule = try source("XiaoZhangGui/Features/Schedule/ScheduleView.swift")
        XCTAssertTrue(
            schedule.contains("private static let isoDateFormatter: DateFormatter"),
            "月网格每帧 30-42 格,日期标识必须复用静态 formatter"
        )
        XCTAssertTrue(schedule.contains("isoDateFormatter.string(from: date)"), "isoDateString 走缓存 formatter")

        let brief = try source("XiaoZhangGui/Features/Home/V39/MorningBrief.swift")
        XCTAssertTrue(
            brief.contains("private static let isoDayFormatter: DateFormatter"),
            "晨报已读键每帧调用,dayKey 必须复用静态 formatter"
        )
        XCTAssertTrue(brief.contains("isoDayFormatter.string(from: date)"), "dayKey 走缓存 formatter")
    }

    func testPerformanceRecordsResolvedOnce() throws {
        let performance = try source("XiaoZhangGui/Features/Performance/PerformanceView.swift")
        XCTAssertTrue(
            performance.contains("let items = records"),
            "records 内含两次 Date() 与全表合并,近期记录段必须一次求值"
        )
        XCTAssertTrue(performance.contains("items.prefix(12)"), "列表与空态判断共用同一次求值")
    }

    func testHeroCardHasHapticFeedback() throws {
        let sections = try source("XiaoZhangGui/Features/Home/V39/V39HomeSections.swift")
        XCTAssertTrue(sections.contains("Haptic.light()"), "首页最大点击区需要轻触觉反馈")
        XCTAssertTrue(
            sections.contains(".accessibilityIdentifier(\"v38.home.hero\")"),
            "Hero 卡的 UI 测试标识不得改动"
        )
    }

    func testTodoRowAccessibilityCombinesMetadata() throws {
        let todo = try source("XiaoZhangGui/Features/Todo/TodoView.swift")
        XCTAssertTrue(
            todo.contains(".accessibilityElement(children: .combine)"),
            "待办行需合并标题 + 优先级/时间,VoiceOver 不能只读标题"
        )
    }

    func testDisabledSaveExplainsWhy() throws {
        let editor = try source("XiaoZhangGui/Features/Todo/TodoEditorSheet.swift")
        XCTAssertTrue(editor.contains("填写标题后即可保存。"), "待办编辑置灰需给出原因")

        let todo = try source("XiaoZhangGui/Features/Todo/TodoView.swift")
        XCTAssertTrue(todo.contains("填写内容后即可保存"), "随手记置灰需给出原因")

        let home = try source("XiaoZhangGui/Features/Home/HomeView.swift")
        XCTAssertTrue(home.contains(".accessibilityIdentifier(\"v39.demo.banner\")"), "演示横幅标识保留")
        XCTAssertFalse(
            home.contains("可退出演示"),
            "整条横幅不得再覆盖 label,否则会吞掉「退出演示」按钮语义"
        )
    }

    func testSheetsAllowGrowingForDynamicType() throws {
        let profile = try source("XiaoZhangGui/Features/Profile/ProfileView.swift")
        XCTAssertFalse(
            profile.contains(".presentationDetents([.medium])"),
            "只给 medium 的弹层在大字号下会截断内容,必须允许展开到 large"
        )
    }
}
