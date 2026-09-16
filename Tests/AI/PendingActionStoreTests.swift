import XCTest
@testable import XiaoZhangGui

final class PendingActionStoreTests: XCTestCase {
    private func proposal(_ status: ProposalStatus = .pending) -> ActionProposal {
        ActionProposal(
            call: AITestFactory.makeToolCall(.createTodo(
                TodoArguments(title: "测试待办", detail: nil, dueDate: nil, priority: 0))),
            status: status,
            isPreviewOnly: true
        )
    }

    func testPendingListsOnlyActionable() async {
        let store = InMemoryPendingActionStore()
        let active = proposal(.pending)
        let failed = proposal(.failed)
        let cancelled = proposal(.cancelled)
        let executed = proposal(.executed)
        await store.upsert(active)
        await store.upsert(failed)
        await store.upsert(cancelled)
        await store.upsert(executed)

        let pending = await store.pending()
        XCTAssertEqual(Set(pending.map(\.id)), [active.id, failed.id])
    }

    func testUpsertAndLookupAndRemove() async {
        let store = InMemoryPendingActionStore()
        let p = proposal()
        await store.upsert(p)
        let fetchedID = await store.proposal(id: p.id)?.id
        XCTAssertEqual(fetchedID, p.id)
        await store.remove(id: p.id)
        let afterRemove = await store.proposal(id: p.id)
        XCTAssertNil(afterRemove)
    }

    func testFileStoreSurvivesRecreationAndCorruption() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-pending-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let store = FilePendingActionStore(directory: dir)
        let p = proposal()
        await store.upsert(p)

        let reopened = FilePendingActionStore(directory: dir)
        let reopenedID = await reopened.proposal(id: p.id)?.id
        XCTAssertEqual(reopenedID, p.id)

        // 损坏文件 → 空集合，不崩
        let url = dir.appendingPathComponent("pending-actions.json")
        try Data("@@@".utf8).write(to: url)
        let recovered = FilePendingActionStore(directory: dir)
        let recoveredPending = await recovered.pending()
        XCTAssertTrue(recoveredPending.isEmpty)
    }
}
