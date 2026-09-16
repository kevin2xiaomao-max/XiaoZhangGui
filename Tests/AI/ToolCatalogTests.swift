import XCTest
@testable import XiaoZhangGui

final class ToolCatalogTests: XCTestCase {
    func testLiteRegistersExactlyFiveTools() {
        XCTAssertEqual(ToolCatalog.liteTools.count, 5)
        XCTAssertEqual(Set(ToolCatalog.liteTools),
                       Set([.searchRecords, .recordRevenue, .createTodo, .createMemo, .createDelivery]))
        // V3.3 Lite 不注册临期 / 更新 / 删除
        XCTAssertFalse(ToolCatalog.liteTools.map(\.rawValue).contains("addExpiry"))
        XCTAssertFalse(ToolCatalog.liteTools.map(\.rawValue).contains("update"))
        XCTAssertFalse(ToolCatalog.liteTools.map(\.rawValue).contains("delete"))
    }

    func testDefinitionsCountAndValidJSON() throws {
        let defs = ToolCatalog.definitions()
        XCTAssertEqual(defs.count, 5)
        for def in defs {
            let object = try JSONSerialization.jsonObject(with: def.jsonSchema) as? [String: Any]
            XCTAssertEqual(object?["type"] as? String, "object", "\(def.name) schema 必须是 JSON object")
            XCTAssertNotNil(object?["properties"], "\(def.name) 必须声明 properties")
        }
    }

    func testPermissions() {
        XCTAssertEqual(ToolName.searchRecords.permission, .read)
        for name in [ToolName.recordRevenue, .createTodo, .createMemo, .createDelivery] {
            XCTAssertEqual(name.permission, .create, "\(name) 必须是 CREATE（需确认卡）")
        }
    }

    func testRevenueRequiresAmount() throws {
        let def = try XCTUnwrap(ToolCatalog.definitions().first { $0.name == .recordRevenue })
        let object = try JSONSerialization.jsonObject(with: def.jsonSchema) as? [String: Any]
        XCTAssertEqual(object?["required"] as? [String], ["amount"])
    }
}
