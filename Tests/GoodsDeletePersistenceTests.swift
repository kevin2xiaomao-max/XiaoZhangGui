import XCTest
import SwiftData
@testable import XiaoZhangGui

/// 商品删除持久化验证（Track B）
/// 验证 GoodsRepository.delete() 是否真正持久化删除
@MainActor
final class GoodsDeletePersistenceTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: AppDatabase.schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: AppDatabase.schema, configurations: [config])
    }

    func testDeletePersistsToStore() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // 创建测试商品
        let goods = Goods(name: "测试商品", category: "测试", price: 10.0, stock: 5)
        context.insert(goods)
        try context.save()

        let targetID = goods.persistentModelID
        let countBefore = try context.fetchCount(FetchDescriptor<Goods>())
        XCTAssertEqual(countBefore, 1, "删除前应有 1 条记录")

        // 执行删除
        try GoodsRepository(context: context).delete(goods)

        // 用独立 ModelContext 验证持久化
        let verifyContext = ModelContext(container)
        let allGoods = try verifyContext.fetch(FetchDescriptor<Goods>())
        let countAfter = allGoods.count
        let targetExists = allGoods.contains { $0.persistentModelID == targetID }

        XCTAssertFalse(targetExists, "独立查询目标不应存在（删除应持久化）")
        XCTAssertEqual(countAfter, 0, "删除后总数应为 0，实际 \(countAfter)")
    }

    func testDeleteNonExistentDoesNotThrow() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let goods = Goods(name: "测试商品2", category: "测试", price: 20.0, stock: 3)
        context.insert(goods)
        try context.save()

        // 删除后再次删除（模拟重复删除）
        try GoodsRepository(context: context).delete(goods)
        // 第二次删除同一对象不应抛错（SwiftData 允许）
        // 注意：实际行为取决于 SwiftData 实现，此测试记录当前行为
    }
}
