import XCTest
@testable import XiaoZhangGui

final class ConversationStoreTests: XCTestCase {
    func testInMemoryAppendKeepsOrderAndUserTextFirst() async {
        let store = InMemoryConversationStore()
        await store.append(AIMessage(role: .user, content: "今天美团680"))
        await store.append(AIMessage(role: .assistant, content: "准备记录"))
        let conversation = await store.load()
        XCTAssertEqual(conversation.messages.map(\.role), [.user, .assistant])
        XCTAssertEqual(conversation.messages.first?.content, "今天美团680")
    }

    func testFileStorePersistsAcrossInstances() async throws {
        let dir = try makeTempDir()
        let store = FileConversationStore(directory: dir)
        await store.append(AIMessage(role: .user, content: "今晚8点给302送两箱怡宝"))

        let reopened = FileConversationStore(directory: dir)
        let conversation = await reopened.load()
        XCTAssertEqual(conversation.messages.count, 1)
        XCTAssertEqual(conversation.messages.first?.content, "今晚8点给302送两箱怡宝")
    }

    /// 文件损坏：隔离损坏文件并以空会话启动，绝不崩溃
    func testCorruptedFileRecoversToEmpty() async throws {
        let dir = try makeTempDir()
        let url = dir.appendingPathComponent("conversation.json")
        try Data("not-json".utf8).write(to: url)

        let store = FileConversationStore(directory: dir)
        let conversation = await store.load()
        XCTAssertTrue(conversation.messages.isEmpty)

        // 损坏文件已被改名隔离
        let quarantined = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(quarantined.contains { $0.contains("corrupt-") })
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-conv-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
