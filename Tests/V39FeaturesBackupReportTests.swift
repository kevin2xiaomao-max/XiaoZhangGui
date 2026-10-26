import XCTest
import SwiftData
import SwiftUI
@testable import XiaoZhangGui

/// V3.9 PR-G/H:备份 2.0(预览/周提醒)与月度报表的真实业务测试。
final class V39FeaturesBackupReportTests: XCTestCase {

    // MARK: - G:恢复预览(真实 JSON 往返)

    @MainActor
    func testPreviewRoundTripsCountsFromRealBackupJSON() throws {
        let now = Date()
        let todos = [
            Todo(title: "进货", detail: "", dueDate: now, priority: 0),
            Todo(title: "对账", detail: "", dueDate: nil, priority: 1, isCompleted: true, completedAt: now),
        ]
        let performances = [
            Performance(amount: 680, note: "美团", date: now, incomeSource: "美团"),
            Performance(amount: 320, note: "门店", date: now, incomeSource: "门店"),
        ]
        let data = try BackupService.exportData(
            todos: todos, memos: [], performances: performances, expenses: [],
            expiryItems: [], customers: [], goods: [], exportedAt: now
        )
        let preview = try BackupPreviewService.parse(data: data)
        XCTAssertEqual(preview.backupCounts["todo"], 2)
        XCTAssertEqual(preview.backupCounts["performance"], 2)
        XCTAssertEqual(preview.backupTotal, 4)
        XCTAssertEqual(preview.exportedAt.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1.0)
    }

    @MainActor
    func testPreviewInvalidDataThrows() {
        XCTAssertThrowsError(try BackupPreviewService.parse(data: Data("not json".utf8)))
        XCTAssertThrowsError(try BackupPreviewService.parse(data: Data(#"{"app":"x"}"#.utf8)),
                             "缺 records 必须报 invalidRecords")
    }

    @MainActor
    func testCurrentSnapshotMatchesEmptyContainer() throws {
        let schema = Schema([Todo.self, Memo.self, Performance.self, Expense.self,
                             ExpiryItem.self, CustomerRequest.self, Goods.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let counts = BackupPreviewService.currentSnapshot(context: container.mainContext)
        XCTAssertTrue(counts.values.allSatisfy { $0 == 0 }, "空库各类型计数应为 0")
        XCTAssertEqual(Set(counts.keys), Set(BackupPreview.displayNames.keys), "七类计数键齐全")
    }

    func testRestorePreviewMessageMentionsMergeSemantics() {
        let preview = BackupPreview(
            exportedAt: Date(timeIntervalSince1970: 1_760_000_000),
            backupCounts: ["todo": 3, "performance": 10],
            currentCounts: ["todo": 1, "performance": 5]
        )
        let message = ProfileView.restorePreviewMessage(preview)
        XCTAssertTrue(message.contains("待办 3 条"), "应列出备份内条数:\(message)")
        XCTAssertTrue(message.contains("营业额 10 条"), "应列出营业额条数")
        XCTAssertTrue(message.contains("当前库共 6 条"), "应给出当前库总数")
        XCTAssertTrue(message.contains("不会删除现有数据"), "必须声明追加合并语义(数据安全)")
    }

    // MARK: - G:备份提醒状态(纯逻辑)

    func testBackupReminderOverdueLogic() throws {
        let defaults = UserDefaults(suiteName: "test.xzg.backupreminder")!
        defaults.removePersistentDomain(forName: "test.xzg.backupreminder")
        // 通过注入 now 驱动,不污染真实 defaults:直接测纯判断需 lastBackupDate——
        // 该属性读 standard,这里改为测状态文案函数的公开行为(超期提示)。
        let overdueText = BackupReminder.statusText(now: Date().addingTimeInterval(8 * 24 * 3600))
        XCTAssertTrue(overdueText.contains("该备份了") || overdueText.contains("还没备份过"),
                      "超 7 天必须提示该备份(或从未备份):\(overdueText)")
        let freshText = BackupReminder.statusText(now: Date())
        XCTAssertFalse(freshText.contains("该备份了"), "未超期不提示(若无历史备份除外)")
        _ = defaults
    }

    // MARK: - H:月度报表(纯函数,真实样本)

    /// 固定日期构造：不用 Date() 与月份算术拼日期，避免 Mar 31 → Feb 28 +14 天
    /// 漂回本月之类的跨月漂移；本月/上月日期全部显式指定。正午构造，避开 DST 与午夜边界。
    private func fixedDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        return Calendar.current.date(from: comps)!
    }

    @MainActor
    func testMonthlyReportComputesFromSampleData() throws {
        // 固定 now：2026-06-15，本月 6 月、上月 5 月，数值口径与旧样本一致。
        let now = fixedDate(2026, 6, 15)
        let thisMonth10th = fixedDate(2026, 6, 10)
        let lastMonth15th = fixedDate(2026, 5, 15)

        let performances = [
            Performance(amount: 800, note: "本月", date: thisMonth10th, incomeSource: "门店"),
            Performance(amount: 200, note: "本月美团", date: thisMonth10th, incomeSource: "美团"),
            Performance(amount: 500, note: "上月", date: lastMonth15th, incomeSource: "门店"),
        ]
        let expenses = [Expense(amount: 100, category: "进货", note: "", date: thisMonth10th)]
        let todos = [
            Todo(title: "a", detail: "", isCompleted: true, completedAt: now),
            Todo(title: "b", detail: ""),
            Todo(title: "c", detail: ""),
        ]

        let report = MonthlyReportBuilder.build(performances: performances, expenses: expenses, todos: todos, now: now)
        XCTAssertEqual(report.monthLabel, "2026年6月")
        XCTAssertEqual(report.revenue, 1000, accuracy: 0.001, "本月 = 800 + 200")
        XCTAssertEqual(report.expense, 100, accuracy: 0.001)
        XCTAssertEqual(report.net, 900, accuracy: 0.001)
        XCTAssertEqual(report.revenueChangePercent ?? 0, 100, accuracy: 0.01, "较上月 +100%(1000 vs 500)")
        XCTAssertEqual(report.todoCompleted, 1)
        XCTAssertEqual(report.todoTotalTracked, 3)
        XCTAssertEqual(report.todoCompletionPercent, 33, "1/3 四舍五入 33%")
        XCTAssertEqual(report.trendPoints.count, 7, "近7日趋势 7 点")
        XCTAssertTrue(report.sourceSplit.contains { $0.source == .meituan && $0.amount == 200 })
    }

    @MainActor
    func testMonthlyReportYearBoundary() throws {
        // 年初边界：now = 2026-01-15，上月必须是 2025 年 12 月（跨年）。
        let now = fixedDate(2026, 1, 15)
        let performances = [
            Performance(amount: 800, note: "本月", date: fixedDate(2026, 1, 10), incomeSource: "门店"),
            // V3.9.1 P0-1 口径重定:now=1月15日,上期同期为上年12月1–15日,样本须落入同期内
            Performance(amount: 400, note: "上年12月", date: fixedDate(2025, 12, 10), incomeSource: "门店"),
        ]
        let report = MonthlyReportBuilder.build(performances: performances, expenses: [], todos: [], now: now)
        XCTAssertEqual(report.monthLabel, "2026年1月")
        XCTAssertEqual(report.revenue, 800, accuracy: 0.001)
        XCTAssertEqual(report.revenueChangePercent ?? 0, 100, accuracy: 0.01, "较上月 +100%(800 vs 400)")
    }

    @MainActor
    func testMonthlyReportShortMonthBoundary() throws {
        // 短月边界：now = 2026-03-15，上月是 28 天的 2026 年 2 月。
        let now = fixedDate(2026, 3, 15)
        let performances = [
            Performance(amount: 600, note: "本月", date: fixedDate(2026, 3, 10), incomeSource: "门店"),
            // V3.9.1 P0-1 口径重定:now=3月15日,上期同期为2月1–15日,样本须落入同期内
            Performance(amount: 300, note: "上月2月", date: fixedDate(2026, 2, 10), incomeSource: "门店"),
        ]
        let report = MonthlyReportBuilder.build(performances: performances, expenses: [], todos: [], now: now)
        XCTAssertEqual(report.monthLabel, "2026年3月")
        XCTAssertEqual(report.revenue, 600, accuracy: 0.001)
        XCTAssertEqual(report.revenueChangePercent ?? 0, 100, accuracy: 0.01, "较上月 +100%(600 vs 300)")
    }

    @MainActor
    func testMonthlyReportEmptyDataIsSafe() {
        let report = MonthlyReportBuilder.build(performances: [], expenses: [], todos: [])
        XCTAssertEqual(report.revenue, 0)
        XCTAssertNil(report.revenueChangePercent, "上月无收入则无对比(口径同首页)")
        XCTAssertEqual(report.todoCompletionPercent, 0)
        XCTAssertTrue(report.sourceSplit.isEmpty)
        XCTAssertEqual(report.trendPoints.count, 7, "空数据仍有 7 个零点(形态稳定)")
    }
    @MainActor
    func testFusionMonthlyReportRenders390PointShareImageInBothAppearances() throws {
        let report = MonthlyReportBuilder.build(
            performances: [Performance(amount: 63420, note: "导出宽度回归", date: .now, incomeSource: "美团")],
            expenses: [], todos: [])
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: MonthlyReportCard(report: report)
                .environment(\.colorScheme, scheme).dynamicTypeSize(.large))
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.uiImage, "真实 SwiftUI 月报应可导出")
            XCTAssertEqual(image.size.width, 390, accuracy: 0.01)
            XCTAssertGreaterThan(image.size.height, 200)
            let attachment = XCTAttachment(image: image)
            attachment.name = "v400-monthly-report-390-\(scheme)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

}
