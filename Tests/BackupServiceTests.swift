import XCTest
import SwiftData
@testable import XiaoZhangGui

/// P0-1：备份 / 恢复 round-trip
/// 原数据 → 导出 JSON → 清空测试库 → 恢复 → 数据语义完全一致
/// 覆盖：Todo 完成态/completedAt/图片、Expiry 退货态/returnedAt、Customer 配送状态/
/// deliveryTime 编码串/图片、Performance incomeSource/扫呗字段、Memo/Goods 图片与时间字段。
@MainActor
final class BackupServiceTests: XCTestCase {

    /// 1x1 PNG（带真实二进制差异，用于验证图片 data 往返）
    private let pngData = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
    )!

    private func makeEmptyContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: AppDatabase.schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: AppDatabase.schema, configurations: [config])
    }

    func testFullRoundTripPreservesStatusDatesImagesAndIncomeSource() throws {
        // MARK: 原始库
        let source = try makeEmptyContainer()
        let ctx = source.mainContext

        let now = Date()
        let todayThreeThirty = Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: now)!
        let completedAt = Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: now)!
        let deliveryTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: now)!
        let expiryDate = Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.startOfDay(for: now))!
        let returnedAt = Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: now)!

        // Todo：已完成（带 completedAt + 图片）/ 未完成（无日期）
        ctx.insert(Todo(title: "进货", detail: "可乐两箱", dueDate: todayThreeThirty, priority: 2,
                        imageData: pngData, isCompleted: true, createdAt: now, completedAt: completedAt))
        ctx.insert(Todo(title: "随手事项", detail: "", dueDate: nil, priority: 0))

        // Memo（图片 + 时间）
        ctx.insert(Memo(title: "客人偏好", content: "少冰", imageData: pngData, createdAt: now, updatedAt: completedAt))

        // Performance（美团 + 扫呗去重字段）
        ctx.insert(Performance(amount: 52.5, note: "扫呗 · 美团", date: now,
                               fingerprint: "fp-001", paymentMethod: "美团", orderNo: "S001",
                               importSource: "saobei", incomeSource: IncomeSource.meituan.rawValue))
        // Expense
        ctx.insert(Expense(amount: 20, category: "其他", note: "杂费", date: now, createdAt: now))

        // Expiry：已退货（returnedAt + 图片）/ 待处理
        ctx.insert(ExpiryItem(name: "鲜牛奶", category: "乳品", quantity: 3, productionDate: nil,
                              expiryDate: expiryDate, remindDaysBefore: 2, note: "",
                              imageData: pngData, createdAt: now,
                              returnStatus: ReturnStatus.returned.rawValue, returnedAt: returnedAt))
        ctx.insert(ExpiryItem(name: "面包", category: "烘焙", quantity: 1, expiryDate: expiryDate))

        // Customer：已完成（deliveryTime 编码进 customer 串 + 图片）/ 配送中
        let encodedCustomer = CustomerDeliveryStorage.encode(
            existingValue: "王姐", deliveryTime: deliveryTime, note: "放前台"
        )
        ctx.insert(CustomerRequest(customer: encodedCustomer, roomOrAddress: "3 栋 502", phone: "13800000000",
                                   content: "矿泉水", status: CustomerStatus.done.rawValue,
                                   imageData: pngData, createdAt: now, updatedAt: completedAt))
        ctx.insert(CustomerRequest(customer: "李先生", roomOrAddress: "", phone: "",
                                   content: "大米", status: CustomerStatus.delivering.rawValue))

        // Goods（全字段 + 图片）
        ctx.insert(Goods(name: "收银纸", category: "耗材", barcode: "6901234", stock: 5, minStock: 2,
                         purchasePrice: 3.5, salePrice: 5, productionDate: nil, shelfLifeDays: 0,
                         expiryDate: nil, note: "热敏", imageData: pngData,
                         createdAt: now, updatedAt: completedAt))
        try ctx.save()

        // MARK: 导出
        let data = try BackupService.exportData(context: ctx)
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(payload?["version"] as? Int, BackupService.formatVersion)
        let records = payload?["records"] as? [[String: Any]]
        XCTAssertEqual(records?.count, 10)
        let todoRecord = records?.first {
            $0["type"] as? String == "todo" && $0["title"] as? String == "进货"
        }
        XCTAssertEqual(todoRecord?["isCompleted"] as? Bool, true)
        XCTAssertNotNil(todoRecord?["completedAt"])
        XCTAssertNotNil(todoRecord?["imageBase64"])

        // MARK: 恢复进空库
        let restored = try makeEmptyContainer()
        let rctx = restored.mainContext
        let count = try BackupService.restore(context: rctx, from: data)
        XCTAssertEqual(count, 10)

        // MARK: 语义一致性断言
        let todos = try rctx.fetch(FetchDescriptor<Todo>())
        XCTAssertEqual(todos.count, 2)
        let doneTodo = try XCTUnwrap(todos.first { $0.title == "进货" })
        XCTAssertTrue(doneTodo.isCompleted)
        XCTAssertEqual(doneTodo.priority, 2)
        XCTAssertEqual(doneTodo.detail, "可乐两箱")
        XCTAssertEqual(doneTodo.imageData, pngData)
        assertClose(doneTodo.dueDate, todayThreeThirty)
        assertClose(try XCTUnwrap(doneTodo.completedAt), completedAt)
        let openTodo = try XCTUnwrap(todos.first { $0.title == "随手事项" })
        XCTAssertFalse(openTodo.isCompleted)
        XCTAssertNil(openTodo.completedAt)
        XCTAssertNil(openTodo.dueDate)

        let memos = try rctx.fetch(FetchDescriptor<Memo>())
        let memo = try XCTUnwrap(memos.first)
        XCTAssertEqual(memo.content, "少冰")
        XCTAssertEqual(memo.imageData, pngData)
        assertClose(memo.updatedAt, completedAt)

        let performances = try rctx.fetch(FetchDescriptor<Performance>())
        let perf = try XCTUnwrap(performances.first)
        XCTAssertEqual(perf.amount, 52.5, accuracy: 0.001)
        XCTAssertEqual(perf.incomeSource, IncomeSource.meituan.rawValue)
        XCTAssertEqual(perf.fingerprint, "fp-001")
        XCTAssertEqual(perf.paymentMethod, "美团")
        XCTAssertEqual(perf.importSource, "saobei")

        let expenses = try rctx.fetch(FetchDescriptor<Expense>())
        let expense = try XCTUnwrap(expenses.first)
        XCTAssertEqual(expense.category, "其他")
        XCTAssertEqual(expense.amount, 20, accuracy: 0.001)

        let items = try rctx.fetch(FetchDescriptor<ExpiryItem>())
        XCTAssertEqual(items.count, 2)
        let milk = try XCTUnwrap(items.first { $0.name == "鲜牛奶" })
        XCTAssertEqual(milk.returnStatus, ReturnStatus.returned.rawValue)
        XCTAssertEqual(milk.status, .returned)
        XCTAssertEqual(milk.imageData, pngData)
        XCTAssertEqual(milk.remindDaysBefore, 2)
        assertClose(try XCTUnwrap(milk.returnedAt), returnedAt)
        let bread = try XCTUnwrap(items.first { $0.name == "面包" })
        XCTAssertEqual(bread.status, .pending)
        XCTAssertNil(bread.returnedAt)

        let customers = try rctx.fetch(FetchDescriptor<CustomerRequest>())
        XCTAssertEqual(customers.count, 2)
        let wang = try XCTUnwrap(customers.first { $0.content == "矿泉水" })
        XCTAssertEqual(wang.statusEnum, .done)
        XCTAssertEqual(wang.imageData, pngData)
        XCTAssertEqual(wang.roomOrAddress, "3 栋 502")
        let info = CustomerDeliveryStorage.decode(wang.customer)
        XCTAssertEqual(info.legacyCustomer, "王姐")
        XCTAssertEqual(info.note, "放前台")
        assertClose(try XCTUnwrap(info.deliveryTime), deliveryTime)
        let li = try XCTUnwrap(customers.first { $0.content == "大米" })
        XCTAssertEqual(li.statusEnum, .delivering)

        let goods = try rctx.fetch(FetchDescriptor<Goods>())
        let goodsItem = try XCTUnwrap(goods.first)
        XCTAssertEqual(goodsItem.stock, 5)
        XCTAssertEqual(goodsItem.minStock, 2)
        XCTAssertEqual(goodsItem.salePrice, 5, accuracy: 0.001)
        XCTAssertEqual(goodsItem.imageData, pngData)
    }

    /// v1 旧备份（无图片 / 无 completedAt / 无 returnedAt，但含状态字段）必须可恢复，
    /// 状态不能丢；缺失的时间戳按导出时间补齐
    func testLegacyV1BackupRemainsCompatible() throws {
        let payload: [String: Any] = [
            "app": "xiao-zhang-gui",
            "version": 1,
            "exportedAt": Date().timeIntervalSince1970 * 1000,
            "records": [
                ["type": "todo", "title": "旧已完成", "detail": "", "priority": 1, "isCompleted": true],
                ["type": "expiry", "name": "旧退货", "category": "", "quantity": 2,
                 "expiryDate": Date().timeIntervalSince1970 * 1000, "returnStatus": "已退货"],
                ["type": "customer", "customer": "旧客户", "roomOrAddress": "", "phone": "",
                 "content": "配送", "status": "配送中"],
                ["type": "performance", "amount": 10, "note": "现金",
                 "date": Date().timeIntervalSince1970 * 1000],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)

        let container = try makeEmptyContainer()
        let ctx = container.mainContext
        let count = try BackupService.restore(context: ctx, from: data)
        XCTAssertEqual(count, 4)

        let todo = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Todo>()).first)
        XCTAssertTrue(todo.isCompleted)
        XCTAssertNotNil(todo.completedAt, "v1 已完成项缺 completedAt 时应按导出时间补齐")

        let expiry = try XCTUnwrap(try ctx.fetch(FetchDescriptor<ExpiryItem>()).first)
        XCTAssertEqual(expiry.status, .returned)
        XCTAssertNotNil(expiry.returnedAt)

        let customer = try XCTUnwrap(try ctx.fetch(FetchDescriptor<CustomerRequest>()).first)
        XCTAssertEqual(customer.statusEnum, .delivering)

        // v1 performance 无 incomeSource → 安全落回 .store
        let perf = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Performance>()).first)
        XCTAssertEqual(perf.incomeSource, IncomeSource.store.rawValue)
    }

    func testInvalidInputThrows() throws {
        let container = try makeEmptyContainer()
        let ctx = container.mainContext

        XCTAssertThrowsError(
            try BackupService.restore(context: ctx, from: Data("not-json".utf8))
        ) { error in
            XCTAssertEqual((error as? BackupError)?.errorDescription,
                           BackupError.invalidFile.errorDescription)
        }

        let noRecords = try JSONSerialization.data(withJSONObject: ["app": "x"])
        XCTAssertThrowsError(
            try BackupService.restore(context: ctx, from: noRecords)
        ) { error in
            XCTAssertEqual((error as? BackupError)?.errorDescription,
                           BackupError.invalidRecords.errorDescription)
        }
    }

    // MARK: - Helpers

    private func assertClose(_ actual: Date?, _ expected: Date,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotNil(actual, file: file, line: line)
        XCTAssertEqual(actual!.timeIntervalSince1970, expected.timeIntervalSince1970,
                       accuracy: 0.001, file: file, line: line)
    }
}
