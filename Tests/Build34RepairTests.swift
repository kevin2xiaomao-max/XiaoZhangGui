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

    func testBusinessPeriodParserCoversBuild34Phrases() {
        let parser = BusinessPeriodParser()
        XCTAssertEqual(parser.parse("最近一周的生意怎么样"), .lastSevenDays)
        XCTAssertEqual(parser.parse("这个月业绩"), .thisMonth)
        XCTAssertEqual(parser.parse("三个月和这个月的对比"), .lastThreeMonthsComparedWithThisMonth)
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
