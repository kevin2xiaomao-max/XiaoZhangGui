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
        XCTAssertTrue(await journal.has(callID: "call_1"))
    }

    func testFingerprintUsedOnlyWhenExecuted() async {
        let journal = InMemoryExecutionJournal()
        await journal.append(entry("call_1", fingerprint: "fp-a", status: "pending"))
        XCTAssertFalse(await journal.isFingerprintUsed("fp-a"))
        await journal.append(entry("call_2", fingerprint: "fp-a", status: "executed"))
        XCTAssertTrue(await journal.isFingerprintUsed("fp-a"))
    }

    func testFileJournalPersistsAndRecoversFromCorruption() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-journal-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let journal = FileExecutionJournal(directory: dir)
        await journal.append(entry("call_1", fingerprint: "fp-a", status: "executed"))

        let reopened = FileExecutionJournal(directory: dir)
        XCTAssertTrue(await reopened.has(callID: "call_1"))
        XCTAssertTrue(await reopened.isFingerprintUsed("fp-a"))

        let url = dir.appendingPathComponent("execution-journal.json")
        try Data("broken".utf8).write(to: url)
        let recovered = FileExecutionJournal(directory: dir)
        XCTAssertTrue(await recovered.entries().isEmpty)
    }
}
