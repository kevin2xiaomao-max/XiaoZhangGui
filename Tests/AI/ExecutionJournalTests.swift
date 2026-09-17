import XCTest
@testable import XiaoZhangGui

final class ExecutionJournalTests: XCTestCase {
    private func entry(_ id: String, fingerprint: String, status: String = "pending") -> JournalEntry {
        JournalEntry(toolCallID: id, fingerprint: fingerprint, toolName: "createTodo",
                     status: status, recordID: nil, createdAt: .now)
    }

    func testDuplicateCallIDIgnored() async {
        let journal = InMemoryExecutionJournal()
        await journal.append(entry("call_1", fingerprint: "fp-a"))
        await journal.append(entry("call_1", fingerprint: "fp-changed"))
        let entries = await journal.entries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.fingerprint, "fp-a")
        let hasCall = await journal.has(callID: "call_1")
        XCTAssertTrue(hasCall)
    }

    /// 真实执行后 pending → executed 必须能推进（同一 toolCallID 替换，而非被首条 pending 挡住）
    func testMarkExecutedTransitionsPendingEntry() async {
        let journal = InMemoryExecutionJournal()
        await journal.append(entry("call_1", fingerprint: "fp-a", status: "pending"))
        await journal.markExecuted(entry("call_1", fingerprint: "fp-a", status: "executed"))
        let entries = await journal.entries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.status, "executed")
        let used = await journal.isFingerprintUsed("fp-a")
        XCTAssertTrue(used)
    }

    func testFingerprintUsedOnlyWhenExecuted() async {
        let journal = InMemoryExecutionJournal()
        await journal.append(entry("call_1", fingerprint: "fp-a", status: "pending"))
        let usedBefore = await journal.isFingerprintUsed("fp-a")
        XCTAssertFalse(usedBefore)
        await journal.append(entry("call_2", fingerprint: "fp-a", status: "executed"))
        let usedAfter = await journal.isFingerprintUsed("fp-a")
        XCTAssertTrue(usedAfter)
    }

    func testFileJournalPersistsAndRecoversFromCorruption() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-journal-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let journal = FileExecutionJournal(directory: dir)
        await journal.append(entry("call_1", fingerprint: "fp-a", status: "executed"))

        let reopened = FileExecutionJournal(directory: dir)
        let reopenedHas = await reopened.has(callID: "call_1")
        XCTAssertTrue(reopenedHas)
        let reopenedUsed = await reopened.isFingerprintUsed("fp-a")
        XCTAssertTrue(reopenedUsed)

        let url = dir.appendingPathComponent("execution-journal.json")
        try Data("broken".utf8).write(to: url)
        let recovered = FileExecutionJournal(directory: dir)
        let recoveredEntries = await recovered.entries()
        XCTAssertTrue(recoveredEntries.isEmpty)
    }
}
