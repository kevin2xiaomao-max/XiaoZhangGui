import XCTest
import SwiftData
@testable import XiaoZhangGui

/// P0-2：数据库安全启动
/// - 生产入口 makeContainer() 持久化失败必须 throw，绝不静默回退 in-memory
/// - 测试/Preview 通过显式 makeInMemoryContainer() 使用内存库
final class DatabaseSafetyTests: XCTestCase {

    @MainActor
    func testExplicitInMemoryContainerIsWritable() throws {
        let container = try AppDatabase.makeInMemoryContainer()
        let context = container.mainContext
        context.insert(Todo(title: "内存库写入测试"))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Todo>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "内存库写入测试")
    }

    /// 父路径是一个普通文件时，持久 store 必须创建失败并抛错
    /// （makeContainer 的最外层承诺：此类错误必须向上抛出，不得吞掉后回退内存库）
    func testPersistentContainerThrowsWhenURLUnwritable() throws {
        let blocker = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("xzg-db-blocker-\(UUID().uuidString)")
        try Data().write(to: blocker)
        let invalidStoreURL = blocker.appendingPathComponent("default.store")

        XCTAssertThrowsError(
            try AppDatabase.makePersistentContainer(at: invalidStoreURL)
        ) { error in
            // 任何错误都可接受，关键是必须 throw（而不是静默降级）
            _ = error
        }
    }

    /// 健康标记读写：fallback / 失败原因必须「可检测」
    func testDatabaseHealthFlagsAreRecordable() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: DatabaseHealth.usedLocalFallbackKey)
        XCTAssertFalse(DatabaseHealth.usedLocalFallback)

        DatabaseHealth.localFallbackUsed()
        XCTAssertTrue(DatabaseHealth.usedLocalFallback)

        DatabaseHealth.sharedStoreSucceeded()
        XCTAssertFalse(DatabaseHealth.usedLocalFallback)
        XCTAssertNil(DatabaseHealth.lastSharedFailure)

        DatabaseHealth.recordPersistentFailure(
            NSError(domain: "test", code: 7, userInfo: [NSLocalizedDescriptionKey: "disk full"])
        )
        XCTAssertNotNil(DatabaseHealth.lastPersistentFailure)
        defaults.removeObject(forKey: DatabaseHealth.persistentFailureKey)
    }
}
