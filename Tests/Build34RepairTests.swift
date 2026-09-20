import XCTest
import SwiftData
@testable import XiaoZhangGui

final class Build34RepairTests: XCTestCase {
    func testScreenshotOCRParsesDateAndSafeAmount() throws {
        let result = SaobeiScreenshotOCR.candidates(from: "2026-09-20 交易金额 ¥2,680.50")
        XCTAssertEqual(result.count, 1)
        let candidate = try XCTUnwrap(result.first)
        XCTAssertEqual(candidate.amount, 2680.50, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(candidate.confidence, 0.9)
    }

    func testScreenshotOCRRejectsAmbiguousOversizedAmount() {
        XCTAssertTrue(SaobeiScreenshotOCR.candidates(from: "2026-09-20 26805").isEmpty)
    }

    func testScreenshotOCRSupportsDateAndAmountOnSeparateLines() {
        let result = SaobeiScreenshotOCR.candidates(from: "2026-09-20\n收款金额\n¥68.00")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(try XCTUnwrap(result.first?.amount), 68, accuracy: 0.001)
    }

    func testScreenshotOCRKeepsSameDaySameAmountTransactionsSeparate() {
        let result = SaobeiScreenshotOCR.candidates(from: "2026-09-20\n¥68.00\n¥68.00")
        XCTAssertEqual(result.count, 2)
        XCTAssertNotEqual(result[0].sourceKey, result[1].sourceKey)
    }

    func testBusinessPeriodParserCoversBuild34Phrases() {
        let parser = BusinessPeriodParser()
        XCTAssertEqual(parser.parse("最近一周的生意怎么样"), .lastSevenDays)
        XCTAssertEqual(parser.parse("这个月业绩"), .thisMonth)
        XCTAssertEqual(parser.parse("三个月和这个月的对比"), .lastThreeMonthsComparedWithThisMonth)
        XCTAssertEqual(parser.parse("最近6个月"), .lastSixMonths)
        XCTAssertEqual(parser.parse("近6个月"), .lastSixMonths)
        XCTAssertEqual(parser.parse("近半年"), .lastSixMonths)
    }

    func testLastSixMonthsIsActuallySixMonths() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let now = ISO8601DateFormatter().date(from: "2026-09-20T12:00:00Z")!
        let bounds = try XCTUnwrap(BusinessPeriodParser().bounds(for: .lastSixMonths, now: now, calendar: calendar))
        XCTAssertEqual(calendar.dateComponents([.month], from: bounds.start, to: bounds.end).month, 6)
    }

    func testSaobeiImportWorkerValidatesAndParsesOffUISeam() throws {
        let csv = "交易时间,收款金额,交易状态,订单号\n2026-09-20 10:00:00,12.50,支付成功,WORKER-1\n"
        let result = try SaobeiImportWorker.parse(data: Data(csv.utf8), fileName: "worker.csv")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(try XCTUnwrap(result.rows.first?.amount), 12.5, accuracy: 0.001)
    }

    @MainActor
    func testThreeMonthComparisonUsesCurrentMonthToDateAgainstCompleteMonths() async throws {
        let container = try AppDatabase.makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar.current
        let now = Date()
        let monthStart = try XCTUnwrap(calendar.dateInterval(of: .month, for: now)?.start)
        context.insert(Performance(amount: 100, note: "本月至今", date: monthStart.addingTimeInterval(3600)))
        for offset in 1...2 {
            let start = try XCTUnwrap(calendar.date(byAdding: .month, value: -offset, to: monthStart))
            context.insert(Performance(amount: 60, note: "完整月", date: start.addingTimeInterval(3600)))
        }
        try context.save()
        let pack = await RepositoryBusinessContextReader(context: context).groundingPack()
        let answer = BusinessAnswerComposer.answer(for: .period(.lastThreeMonthsComparedWithThisMonth), pack: pack)
        XCTAssertTrue(answer.contains("本月至今"))
        XCTAssertTrue(answer.contains("月均 ¥60"))
        XCTAssertTrue(answer.contains("实际比较了 2 个月"))
    }

    func testTimeWordAloneDoesNotCreateTodo() {
        let router = IntentRouter()
        XCTAssertEqual(router.classify("明天"), .worldChat)
        XCTAssertEqual(router.classify("下午3点"), .worldChat)
    }

    @MainActor
    func testBusinessPeriodReadsHistoricalPerformanceLocally() async throws {
        let container = try AppDatabase.makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.dateInterval(of: .month, for: now)!.start
        context.insert(Performance(amount: 120, note: "本月", date: start.addingTimeInterval(3600)))
        context.insert(Performance(amount: 80, note: "上月", date: calendar.date(byAdding: .month, value: -1, to: start)!.addingTimeInterval(3600)))
        try context.save()
        let reader = RepositoryBusinessContextReader(context: context)
        let pack = await reader.groundingPack()
        let result = BusinessAnswerComposer.answer(for: .period(.thisMonth), pack: pack)
        XCTAssertTrue(result.contains("¥120"))
    }
}
