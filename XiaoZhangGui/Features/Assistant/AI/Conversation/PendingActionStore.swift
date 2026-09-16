import Foundation

// MARK: - V3.3 Lite · 待确认动作存储（崩溃恢复 / 防重复落库）
//
// ActionProposal 在用户确认前持久化：App 被杀 / 崩溃后重开，待确认卡仍在，
// 不会因重复响应二次落库。仅存 AI 侧 JSON（Application Support/AI），不进 SwiftData。

protocol PendingActionStoring: Sendable {
    func pending() async -> [ActionProposal]
    func upsert(_ proposal: ActionProposal) async
    func remove(id: UUID) async
    func proposal(id: UUID) async -> ActionProposal?
}

actor InMemoryPendingActionStore: PendingActionStoring {
    private var items: [UUID: ActionProposal] = [:]

    init() {}

    func pending() async -> [ActionProposal] {
        items.values
            .filter { $0.status == .pending || $0.status == .failed }
            .sorted { $0.createdAt < $1.createdAt }
    }
    func upsert(_ proposal: ActionProposal) async { items[proposal.id] = proposal }
    func remove(id: UUID) async { items[id] = nil }
    func proposal(id: UUID) async -> ActionProposal? { items[id] }
}

actor FilePendingActionStore: PendingActionStoring {
    private let url: URL
    private var items: [UUID: ActionProposal] = [:]

    init(directory: URL? = nil) {
        let dir = directory ?? AIStorage.directory()
        let url = dir.appendingPathComponent("pending-actions.json")
        self.url = url
        self.items = Self.read(from: url)
    }

    /// nonisolated：仅在初始化期读盘，损坏文件隔离后以空集合启动
    nonisolated private static func read(from url: URL) -> [UUID: ActionProposal] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        do {
            let list = try JSONDecoder.ai.decode([ActionProposal].self, from: data)
            return Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        } catch {
            let bad = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: url, to: bad)
            return [:]
        }
    }

    func pending() async -> [ActionProposal] {
        items.values
            .filter { $0.status == .pending || $0.status == .failed }
            .sorted { $0.createdAt < $1.createdAt }
    }
    func upsert(_ proposal: ActionProposal) async {
        items[proposal.id] = proposal
        persist()
    }
    func remove(id: UUID) async {
        items[id] = nil
        persist()
    }
    func proposal(id: UUID) async -> ActionProposal? { items[id] }

    private func persist() {
        let list = items.values.sorted { $0.createdAt < $1.createdAt }
        guard let data = try? JSONEncoder.ai.encode(list) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
