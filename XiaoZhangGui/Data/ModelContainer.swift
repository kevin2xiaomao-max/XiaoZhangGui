import Foundation
import SwiftData

/// SwiftData 容器（语义对齐 Android Room v7 的全部实体表）
/// 优先使用 App Group 容器；重签名后 App Group 不可用时，回退到 App sandbox。
enum AppDatabase {
    static let schema = Schema([
        Todo.self,
        Memo.self,
        Performance.self,
        Expense.self,
        ExpiryItem.self,
        CustomerRequest.self,
        Goods.self,
    ])

    static func makeContainer() throws -> ModelContainer {
        if let sharedStoreURL = sharedStoreURL() {
            do {
                return try makePersistentContainer(at: sharedStoreURL)
            } catch {
                // 共享 store 损坏、不可写或无法迁移时，不影响主 App 启动。
            }
        }

        do {
            return try makePersistentContainer(at: localStoreURL())
        } catch {
            // 极端情况下使用内存 store，避免数据库错误导致启动崩溃。
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        }
    }

    private static func sharedStoreURL() -> URL? {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: XZGShared.appGroupID
        ) else {
            return nil
        }
        return storeURL(in: groupURL)
    }

    private static func localStoreURL() throws -> URL {
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

    private static func makePersistentContainer(at storeURL: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let config = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
