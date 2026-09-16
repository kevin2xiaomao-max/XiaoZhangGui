import Foundation
import SwiftData
import OSLog

/// SwiftData 容器（语义对齐 Android Room v7 的全部实体表）
/// 优先使用 App Group 容器；重签名后 App Group 不可用时，安全回退到 App sandbox 持久 store。
enum AppDatabase {
    private static let logger = Logger(subsystem: "com.xiaozhanggui.ios", category: "Database")

    static let schema = Schema([
        Todo.self,
        Memo.self,
        Performance.self,
        Expense.self,
        ExpiryItem.self,
        CustomerRequest.self,
        Goods.self,
    ])

    /// 生产入口：只允许返回「可持久化」的容器。
    /// - App Group store 失败：安全 fallback 到 App sandbox 持久 store，并留下可检测标记。
    /// - 两个持久 store 都失败：抛出错误，由 UI 明确告知「数据存储暂不可用」。
    /// - 绝不静默进入 in-memory store——否则用户可以继续记账但重启后数据全部消失。
    static func makeContainer() throws -> ModelContainer {
        // 1. 优先 App Group 共享 store
        if let sharedStoreURL = sharedStoreURL() {
            do {
                let container = try makePersistentContainer(at: sharedStoreURL)
                DatabaseHealth.sharedStoreSucceeded()
                logger.info("SwiftData 使用 App Group 共享 store")
                return container
            } catch {
                // 共享 store 损坏、不可写或无法迁移时，不影响主 App 启动：转本地持久 store。
                logger.error("App Group store 打开失败，回退本地持久 store：\(String(describing: error), privacy: .public)")
                DatabaseHealth.recordSharedFailure(error)
            }
        }

        // 2. App sandbox 本地持久 store
        do {
            let container = try makePersistentContainer(at: localStoreURL())
            DatabaseHealth.localFallbackUsed()
            logger.info("SwiftData 使用 App sandbox 本地持久 store（App Group 不可用）")
            return container
        } catch {
            // 3. 持久化彻底不可用：显式失败，绝不伪装成正常 App / 绝不使用内存库
            logger.fault("本地持久 store 也无法打开：\(String(describing: error), privacy: .public)")
            DatabaseHealth.recordPersistentFailure(error)
            throw DatabaseError.persistentStoreUnavailable
        }
    }

    /// 显式 in-memory 容器：仅允许单元测试 / SwiftUI Preview 使用。
    /// 生产代码（App / App Intents / Widget）禁止调用，避免制造「数据已保存」的假象。
    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    static func sharedStoreURL() -> URL? {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: XZGShared.appGroupID
        ) else {
            return nil
        }
        return storeURL(in: groupURL)
    }

    static func localStoreURL() throws -> URL {
        let appSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupportURL.appendingPathComponent("default.store", isDirectory: false)
    }

    private static func storeURL(in containerURL: URL) -> URL {
        containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("default.store", isDirectory: false)
    }

    /// internal（非 private）：单元测试可传入非法 URL 验证「失败必须抛错、不得回退内存库」。
    static func makePersistentContainer(at storeURL: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let config = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

/// 持久化彻底不可用时抛出的用户可见错误
enum DatabaseError: LocalizedError {
    case persistentStoreUnavailable

    var errorDescription: String? {
        "数据存储暂不可用，请重启 App；若持续出现，请检查设备存储空间后联系支持"
    }
}

/// 数据库健康状态标记（可检测、可记录；写入标准 UserDefaults，不依赖 App Group）
enum DatabaseHealth {
    /// 本次/最近一次启动是否被迫使用本地持久 store（App Group 不可用）
    static let usedLocalFallbackKey = "xzg.db.usedLocalFallback.v1"
    /// 最近一次 App Group store 失败描述
    static let sharedFailureKey = "xzg.db.sharedFailure.v1"
    /// 最近一次持久化彻底失败描述
    static let persistentFailureKey = "xzg.db.persistentFailure.v1"

    static var usedLocalFallback: Bool {
        UserDefaults.standard.bool(forKey: usedLocalFallbackKey)
    }

    static var lastSharedFailure: String? {
        UserDefaults.standard.string(forKey: sharedFailureKey)
    }

    static var lastPersistentFailure: String? {
        UserDefaults.standard.string(forKey: persistentFailureKey)
    }

    static func sharedStoreSucceeded() {
        // 共享 store 恢复健康：清除回退标记与共享失败记录
        UserDefaults.standard.removeObject(forKey: usedLocalFallbackKey)
        UserDefaults.standard.removeObject(forKey: sharedFailureKey)
    }

    static func recordSharedFailure(_ error: Error) {
        UserDefaults.standard.set(String(describing: error), forKey: sharedFailureKey)
    }

    static func localFallbackUsed() {
        UserDefaults.standard.set(true, forKey: usedLocalFallbackKey)
    }

    static func recordPersistentFailure(_ error: Error) {
        UserDefaults.standard.set(String(describing: error), forKey: persistentFailureKey)
    }
}
