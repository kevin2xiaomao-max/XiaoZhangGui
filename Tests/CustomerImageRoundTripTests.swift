import XCTest
import SwiftData
@testable import XiaoZhangGui

/// B28 QA P0-4：配送图片 round-trip 单测
/// 覆盖完整链路的数据层：
///   新增（带图）→ 落库 → 重新 fetch → imageData 一致
///   更换图片 → 落库 → 重新 fetch → 是新图
///   删除图片 → 落库 → 重新 fetch → nil
/// 杀 App 重开在真机上走同一 SwiftData externalStorage 持久化路径；
/// in-memory container 验证的是同一套 ModelLayer 读写语义。
final class CustomerImageRoundTripTests: XCTestCase {

    // MARK: - 新增 → 保存 → 重新读取

    @MainActor
    func testAddWithImageDataSurvivesRefetch() throws {
        let container = try makeEmptyContainer()
        let context = container.mainContext

        let image = Data("fake-jpeg-bytes-AAA".utf8)
        context.insert(CustomerRequest(
            customer: CustomerDeliveryStorage.encode(existingValue: "", deliveryTime: nil, note: ""),
            roomOrAddress: "清泉八街24号",
            phone: "13800000000",
            content: "矿泉水2箱",
            imageData: image
        ))
        try context.save()

        // 重新 fetch 模拟「退出列表 → 再进入」
        let refetched = try context.fetch(FetchDescriptor<CustomerRequest>())
        XCTAssertEqual(refetched.count, 1)
        XCTAssertEqual(refetched.first?.imageData, image, "新增配送带图，重新读取后图片必须仍在")

        // 编辑页 initializeIfNeeded() 读取路径
        XCTAssertNotNil(refetched.first?.imageData)
    }

    // MARK: - 更换图片

    @MainActor
    func testReplaceImageSurvivesRefetch() throws {
        let container = try makeEmptyContainer()
        let context = container.mainContext

        let old = Data("fake-jpeg-old".utf8)
        let new = Data("fake-jpeg-new-BBB".utf8)
        let request = CustomerRequest(
            customer: "",
            roomOrAddress: "地址",
            phone: "",
            content: "测试",
            imageData: old
        )
        context.insert(request)
        try context.save()

        // 编辑页保存路径：request.imageData = 新图 → repo.update 语义（context.save）
        request.imageData = new
        try context.save()

        let refetched = try context.fetch(FetchDescriptor<CustomerRequest>())
        XCTAssertEqual(refetched.first?.imageData, new, "更换图片后重新读取必须得到新图")
        XCTAssertNotEqual(refetched.first?.imageData, old)
    }

    // MARK: - 删除图片

    @MainActor
    func testDeleteImageSurvivesRefetch() throws {
        let container = try makeEmptyContainer()
        let context = container.mainContext

        let request = CustomerRequest(
            customer: "",
            roomOrAddress: "地址",
            phone: "",
            content: "测试",
            imageData: Data("fake-jpeg-old".utf8)
        )
        context.insert(request)
        try context.save()

        // 编辑页删除图片路径：onChange(nil) → request.imageData = nil
        request.imageData = nil
        try context.save()

        let refetched = try context.fetch(FetchDescriptor<CustomerRequest>())
        XCTAssertNil(refetched.first?.imageData, "删除图片后重新读取必须为 nil")
    }

    // MARK: - Helpers

    /// 空的 in-memory container，不预填演示数据
    @MainActor
    private func makeEmptyContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: AppDatabase.schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: AppDatabase.schema, configurations: [config])
    }
}
