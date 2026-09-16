import Foundation

// MARK: - V3.3 Lite · 执行日志 / 幂等账本（AI 侧状态，非业务数据）
//
// 记录每个 toolCallID / 业务指纹的处理状态，用于防重复落库与崩溃恢复。
// 存 Application Support/AI（JSON），不进 SwiftData、不改 7 个 @Model。
// 文件损坏：隔离损坏文件并以空账本启动，绝不崩溃。

struct JournalEntry: Codable, Sendable, Equatable {
    let toolCallID: String
    let fingerprint: String
    let toolName: String
    /// pending / executed / failed / duplicate / cancelled
    let status: String
    let recordID: String?
    let createdAt: Date
}

protocol ExecutionJournaling: Sendable {
    func append(_ entry: JournalEntry) async
    func has(callID: String) async -> Bool
    func isFingerprintUsed(_ fingerprint: String) async -> Bool
    func entries() async -> [JournalEntry]
}

/// 测试与预览用内存账本
actor InMemoryExecutionJournal: ExecutionJournaling {
    private var storage: [JournalEntry] = []

    init() {}

    func append(_ entry: JournalEntry) async {
        guard !storage.contains(where: { $0.toolCallID == entry.toolCallID }) else { return }
        storage.append(entry)
    }
    func has(callID: String) async -> Bool {
        storage.contains { $0.toolCallID == callID }
    }
    func isFingerprintUsed(_ fingerprint: String) async -> Bool {
        storage.contains { $0.fingerprint == fingerprint && $0.status == "executed" }
    }
    func entries() async -> [JournalEntry] { storage }
}

/// JSON 文件账本（损坏隔离、失败不崩）
actor FileExecutionJournal: ExecutionJournaling {
    private let url: URL
    private var storage: [JournalEntry] = []

    init(directory: URL? = nil) {
        let dir = directory ?? AIStorage.directory()
        self.url = dir.appendingPathComponent("execution-journal.json")
        load()
    }

    func append(_ entry: JournalEntry) async {
        guard !storage.contains(where: { $0.toolCallID == entry.toolCallID }) else { return }
        storage.append(entry)
        persist()
    }
    func has(callID: String) async -> Bool {
        storage.contains { $0.toolCallID == callID }
    }
    func isFingerprintUsed(_ fingerprint: String) async -> Bool {
        storage.contains { $0.fingerprint == fingerprint && $0.status == "executed" }
    }
    func entries() async -> [JournalEntry] { storage }

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        do {
            storage = try JSONDecoder.ai.decode([JournalEntry].self, from: data)
        } catch {
            // 隔离损坏文件，空账本启动（不崩溃、不阻断）
            let bad = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: url, to: bad)
            storage = []
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder.ai.encode(storage) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - AI 存储目录与编解码

enum AIStorage {
    static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("AI", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}

extension JSONEncoder {
    static var ai: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var ai: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
