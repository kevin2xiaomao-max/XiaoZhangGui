import XCTest
import SwiftData
@testable import XiaoZhangGui

/// P1-3：扫呗导入去重
/// - 同一 XLSX/CSV 文件内部完全相同的两行不得重复落库
/// - 数据库已有记录与文件内重复同时存在时 duplicates 计数准确
/// - 批量导入后 DB 状态正确（单次 save 由实现保证，刷新聚合只发生一次）
@MainActor
final class SaobeiImportTests: XCTestCase {

    private func makeEmptyContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: AppDatabase.schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: AppDatabase.schema, configurations: [config])
    }

    private func row(_ fingerprint: String, amount: Double = 10, method: String = "微信") -> SaobeiParsedRow {
        SaobeiParsedRow(
            date: Date(),
            amount: amount,
            status: "成功",
            orderNo: "O-\(fingerprint)",
            paymentMethod: method,
            fingerprint: fingerprint,
            isSuccess: true,
            rawLine: "\(fingerprint),\(amount)"
        )
    }

    func testDuplicateRowsInsideSameFileAreInsertedOnce() throws {
        let container = try makeEmptyContainer()
        let ctx = container.mainContext
        let repo = PerformanceRepository(context: ctx)

        // 同一文件两条完全相同记录
        let result = try repo.importSaobei([row("FP-A"), row("FP-A")], skippedFailed: 0)

        XCTAssertEqual(result.inserted, 1)
        XCTAssertEqual(result.duplicates, 1)
        let stored = try ctx.fetch(FetchDescriptor<Performance>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.fingerprint, "FP-A")
        XCTAssertEqual(stored.first?.importSource, "saobei")
    }

    func testDatabaseExistingAndInFileDuplicatesBothCounted() throws {
        let container = try makeEmptyContainer()
        let ctx = container.mainContext
        let repo = PerformanceRepository(context: ctx)

        // DB 已存在 FP-A
        try repo.importSaobei([row("FP-A")], skippedFailed: 0)

        // 文件：[DB 已有的 A, 新 B, 文件内孪生 B, 新 C, 又一条 A]
        let result = try repo.importSaobei(
            [row("FP-A"), row("FP-B"), row("FP-B"), row("FP-C"), row("FP-A")],
            skippedFailed: 0
        )

        XCTAssertEqual(result.inserted, 2, "B、C 各落库一次")
        XCTAssertEqual(result.duplicates, 3, "A×2（一条库内、一条再次出现）+ B 孪生一条")
        let stored = try ctx.fetch(FetchDescriptor<Performance>())
        XCTAssertEqual(Set(stored.map(\.fingerprint)), ["FP-A", "FP-B", "FP-C"])
        XCTAssertEqual(stored.count, 3)
    }

    func testAllDistinctRowsInsertedAndSkippedFailedPropagated() throws {
        let container = try makeEmptyContainer()
        let ctx = container.mainContext
        let repo = PerformanceRepository(context: ctx)

        let result = try repo.importSaobei(
            [row("FP-1", amount: 12.5, method: "美团"), row("FP-2", amount: 8, method: "现金")],
            skippedFailed: 2
        )
        XCTAssertEqual(result.inserted, 2)
        XCTAssertEqual(result.duplicates, 0)
        XCTAssertEqual(result.skippedFailed, 2)

        let stored = try ctx.fetch(FetchDescriptor<Performance>()).sorted { $0.amount < $1.amount }
        XCTAssertEqual(stored.count, 2)
        // paymentMethod 派生 incomeSource：美团 → meituan；现金/其它 → store
        let smallest = try XCTUnwrap(stored.first)
        XCTAssertEqual(smallest.amount, 8, accuracy: 0.001)
        let meituan = try XCTUnwrap(stored.first { $0.fingerprint == "FP-1" })
        XCTAssertEqual(meituan.incomeSource, IncomeSource.meituan.rawValue)
        XCTAssertEqual(meituan.paymentMethod, "美团")
    }

    func testAllDuplicatesNoSaveAndZeroInserted() throws {
        let container = try makeEmptyContainer()
        let ctx = container.mainContext
        let repo = PerformanceRepository(context: ctx)
        try repo.importSaobei([row("FP-X")], skippedFailed: 0)

        let result = try repo.importSaobei([row("FP-X"), row("FP-X"), row("FP-X")], skippedFailed: 0)
        XCTAssertEqual(result.inserted, 0)
        XCTAssertEqual(result.duplicates, 3)
        // 不应新增任何数据
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Performance>()).count, 1)
    }
}
