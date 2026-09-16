import Foundation

// MARK: - V3.3 Lite · 会话存储（精简版）
//
// Lite 只要求：当前 / 最近会话可恢复、消息持久化、文件损坏不崩。
// 不做 50 篇 / 30 天 / 全文索引 / 高级历史管理（降为 P2，V3.4+）。
// 用户原始文字 / transcript 必须在调用 Provider 前先持久化，失败也不丢。

struct Conversation: Codable, Sendable {
    var id: UUID
    var messages: [AIMessage]
    var updatedAt: Date

    init(id: UUID = UUID(), messages: [AIMessage] = [], updatedAt: Date = .now) {
        self.id = id
        self.messages = messages
        self.updatedAt = updatedAt
    }
}

protocol ConversationStoring: Sendable {
    func load() async -> Conversation
    func save(_ conversation: Conversation) async
    /// 追加一条消息并返回最新会话
    @discardableResult
    func append(_ message: AIMessage) async -> Conversation
}

actor InMemoryConversationStore: ConversationStoring {
    private var conversation = Conversation()

    init(_ conversation: Conversation = Conversation()) {
        self.conversation = conversation
    }

    func load() async -> Conversation { conversation }

    func save(_ conversation: Conversation) async {
        self.conversation = conversation
    }

    func append(_ message: AIMessage) async -> Conversation {
        conversation.messages.append(message)
        conversation.updatedAt = .now
        return conversation
    }
}

/// JSON 文件会话存储；损坏文件隔离后以新会话启动，绝不崩溃。
actor FileConversationStore: ConversationStoring {
    private let url: URL
    private var conversation: Conversation

    init(directory: URL? = nil) {
        let dir = directory ?? AIStorage.directory()
        self.url = dir.appendingPathComponent("conversation.json")
        self.conversation = Conversation()
        load()
    }

    func load() async -> Conversation { conversation }

    func save(_ conversation: Conversation) async {
        self.conversation = conversation
        persist()
    }

    func append(_ message: AIMessage) async -> Conversation {
        conversation.messages.append(message)
        conversation.updatedAt = .now
        persist()
        return conversation
    }

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        do {
            conversation = try JSONDecoder.ai.decode(Conversation.self, from: data)
        } catch {
            let bad = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: url, to: bad)
            conversation = Conversation()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder.ai.encode(conversation) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
