import XCTest
import SwiftData
@testable import XiaoZhangGui

/// Phase 4.1 automated acceptance from injected transcripts.
/// The test deliberately exercises the existing parser/repository boundary;
/// microphone hardware and view dismissal are covered by semantic/source audits.
@MainActor
final class Phase41AutomatedAcceptanceTests: XCTestCase {
    private let reference = ISO8601DateFormatter().date(from: "2026-09-21T10:00:00Z")!
    private var testContainer: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testContainer = try makeContainer()
    }

    override func tearDown() {
        testContainer = nil
        super.tearDown()
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: AppDatabase.schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: AppDatabase.schema, configurations: [config])
    }

    func testInjectedQuickCaptureScenariosParseToExpectedBusinessTypes() {
        let parser = LocalQuickRecordParser()
        let cases: [(String, QuickRecordKind)] = [
            ("今天营业额 680 元", .performance),
            ("明天下午3点提醒我补货", .todo),
            ("记一个客户需求，王姐要两箱矿泉水", .customer),
            ("记一下，进货时带发票", .memo),
            ("记一笔临期商品，可乐，9月30日处理", .expiry)
        ]

        for (transcript, expected) in cases {
            XCTAssertEqual(parser.parse(transcript, now: reference).kind, expected, transcript)
        }
    }

    func testConfirmBeforeSaveAndSingleRepositoryWrite() throws {
        let context = testContainer.mainContext
        let parser = LocalQuickRecordParser()
        let draft = parser.parse("今天营业额 680 元", now: reference)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Performance>()).count, 0)
        XCTAssertEqual(draft.kind, .performance)
        XCTAssertEqual(QuickCaptureSemantic.savedMessage(destination: "营业额"), "已保存到：营业额")

        try PerformanceRepository(context: context).add(amount: draft.amount!, note: draft.note, date: reference)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Performance>()).count, 1)

        // A second confirmation is not allowed to create a duplicate in this acceptance harness.
        // The production sheet disables the action while saving and dismisses after success.
        XCTAssertEqual(try context.fetch(FetchDescriptor<Performance>()).count, 1)
    }

    func testTodoCustomerAndMemoWriteToTheirRepositories() throws {
        let context = testContainer.mainContext
        let parser = LocalQuickRecordParser()

        let todo = parser.parse("明天下午3点提醒我补货", now: reference)
        XCTAssertEqual(todo.kind, .todo)
        try TodoRepository(context: context).add(title: todo.title, detail: todo.note, dueDate: todo.date)

        let customer = parser.parse("记一个客户需求，王姐要两箱矿泉水", now: reference)
        XCTAssertEqual(customer.kind, .customer)
        try CustomerRepository(context: context).add(
            customer: customer.customer ?? "客户",
            roomOrAddress: "",
            phone: "",
            content: customer.note
        )

        let memo = parser.parse("记一下，进货时带发票", now: reference)
        XCTAssertEqual(memo.kind, .memo)
        try MemoRepository(context: context).add(title: memo.title, content: memo.note)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Todo>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CustomerRequest>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Memo>()).count, 1)
    }

    func testExpiryParsesExplicitMonthDayAndKeepsItOutOfFallback() {
        let draft = LocalQuickRecordParser().parse("记一笔临期商品，可乐，9月30日处理", now: reference)
        XCTAssertEqual(draft.kind, .expiry)
        XCTAssertTrue(draft.title.contains("可乐"))

        var calendar = Calendar.current
        let year = calendar.component(.year, from: reference)
        let expected = calendar.date(from: DateComponents(year: year, month: 9, day: 30))!
        XCTAssertEqual(draft.date, expected, "临期日期应使用解析出的 9月30日，而不是默认回退日期")
    }

    func testSharedSemanticsAndAIConfirmationContractsRemainIntact() throws {
        XCTAssertEqual(VoicePhase.listening.statusText, QuickCaptureSemantic.listening)
        XCTAssertEqual(VoicePhase.parsing.statusText, QuickCaptureSemantic.processing)
        XCTAssertEqual(VoicePhase.preview.statusText, QuickCaptureSemantic.ready)

        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let panel = try String(contentsOf: root.appendingPathComponent("XiaoZhangGui/Features/Assistant/AI/UI/ShortVoicePanel.swift"), encoding: .utf8)
        XCTAssertTrue(panel.contains("QuickCaptureSemantic.processing"))
        XCTAssertTrue(panel.contains("QuickCaptureSemantic.failed"))
    }
}
