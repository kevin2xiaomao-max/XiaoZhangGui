import Foundation
import SwiftData

// MARK: - 数据备份 / 恢复服务
//
// 设计原则（第二轮审计 P0-1）：
// 1. 导出是「真正的 .json 文件」（写入 Caches 后由系统分享面板以文件形式发出），
//    不再是 ShareLink 直接分享 JSON 纯文本。
// 2. 导出与恢复字段严格对称：Todo 完成态/completedAt、Expiry 退货态/returnedAt、
//    Customer 配送状态/时间字段、Performance incomeSource 等时间/状态字段全部往返保留。
// 3. Todo / Memo / Expiry / Customer / Goods 的 imageData 以 base64 进入 JSON（imageBase64），
//    不允许静默丢失；备份文件因此可能较大，由用户主动通过系统面板保存/发送。
// 4. 恢复直接构造 @Model 并一次性 context.save()，最后统一重建通知 + 刷新一次快照，
//    不经过逐条 Repository（避免状态被重置、避免逐行 save / Widget 刷新）。
// 5. 兼容 v1 备份：缺失的新字段按安全默认值恢复（旧备份本就不含图片，无法补回）。

enum BackupError: LocalizedError {
    case invalidFile
    case invalidRecords
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidFile: return "无法读取备份文件"
        case .invalidRecords: return "备份文件内容格式不正确（缺少 records）"
        case .writeFailed(let error): return "备份文件写入失败：\(error.localizedDescription)"
        }
    }
}

enum BackupService {
    static let appName = "xiao-zhang-gui"
    /// v2：字段对称（状态/时间/图片 base64/扫呗字段）；读取侧同时兼容 v1
    static let formatVersion = 2
    static let fileName = "xiao-zhang-gui-backup.json"

    // MARK: - 导出

    /// 从 context 全量读取并生成备份 JSON Data
    @MainActor
    static func exportData(context: ModelContext) throws -> Data {
        let todos = try context.fetch(FetchDescriptor<Todo>())
        let memos = try context.fetch(FetchDescriptor<Memo>())
        let performances = try context.fetch(FetchDescriptor<Performance>())
        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let expiryItems = try context.fetch(FetchDescriptor<ExpiryItem>())
        let customers = try context.fetch(FetchDescriptor<CustomerRequest>())
        let goods = try context.fetch(FetchDescriptor<Goods>())
        return try exportData(
            todos: todos,
            memos: memos,
            performances: performances,
            expenses: expenses,
            expiryItems: expiryItems,
            customers: customers,
            goods: goods
        )
    }

    /// 纯函数导出（无数据库访问，便于单元测试 round-trip）
    static func exportData(
        todos: [Todo],
        memos: [Memo],
        performances: [Performance],
        expenses: [Expense],
        expiryItems: [ExpiryItem],
        customers: [CustomerRequest],
        goods: [Goods],
        exportedAt: Date = Date()
    ) throws -> Data {
        var records: [[String: Any]] = []

        // 注意：记录字典必须是 [String: Any] 且逐个 if let 装入 Optional 字段。
        // 不能用 [String: Any?] 整体字面量——那会产生双层 Swift Optional，
        // JSONSerialization 无法可靠序列化，会静默丢字段。
        for todo in todos {
            var d: [String: Any] = [
                "type": "todo",
                "title": todo.title,
                "detail": todo.detail,
                "priority": todo.priority,
                "isCompleted": todo.isCompleted,
                "createdAt": millis(todo.createdAt),
            ]
            if let dueDate = todo.dueDate { d["dueDate"] = millis(dueDate) }
            if let completedAt = todo.completedAt { d["completedAt"] = millis(completedAt) }
            if let image = todo.imageData { d["imageBase64"] = image.base64EncodedString() }
            records.append(d)
        }
        for memo in memos {
            var d: [String: Any] = [
                "type": "memo",
                "title": memo.title,
                "content": memo.content,
                "createdAt": millis(memo.createdAt),
                "updatedAt": millis(memo.updatedAt),
            ]
            if let image = memo.imageData { d["imageBase64"] = image.base64EncodedString() }
            records.append(d)
        }
        for performance in performances {
            records.append([
                "type": "performance",
                "amount": performance.amount,
                "note": performance.note,
                "date": millis(performance.date),
                "fingerprint": performance.fingerprint,
                "paymentMethod": performance.paymentMethod,
                "orderNo": performance.orderNo,
                "importSource": performance.importSource,
                "incomeSource": performance.incomeSource,
            ])
        }
        for expense in expenses {
            records.append([
                "type": "expense",
                "amount": expense.amount,
                "category": expense.category,
                "note": expense.note,
                "date": millis(expense.date),
                "createdAt": millis(expense.createdAt),
            ])
        }
        for item in expiryItems {
            var d: [String: Any] = [
                "type": "expiry",
                "name": item.name,
                "category": item.category,
                "quantity": item.quantity,
                "expiryDate": millis(item.expiryDate),
                "remindDaysBefore": item.remindDaysBefore,
                "note": item.note,
                "returnStatus": item.returnStatus,
                "createdAt": millis(item.createdAt),
            ]
            if let productionDate = item.productionDate { d["productionDate"] = millis(productionDate) }
            if let returnedAt = item.returnedAt { d["returnedAt"] = millis(returnedAt) }
            if let image = item.imageData { d["imageBase64"] = image.base64EncodedString() }
            records.append(d)
        }
        for request in customers {
            var d: [String: Any] = [
                "type": "customer",
                // customer 字段内含 deliveryTime / note 的编码串（CustomerDeliveryStorage），
                // 必须随备份恢复，配送时间才能 round-trip
                "customer": request.customer,
                "roomOrAddress": request.roomOrAddress,
                "phone": request.phone,
                "content": request.content,
                "status": request.status,
                "createdAt": millis(request.createdAt),
                "updatedAt": millis(request.updatedAt),
            ]
            if let image = request.imageData { d["imageBase64"] = image.base64EncodedString() }
            records.append(d)
        }
        for item in goods {
            var d: [String: Any] = [
                "type": "goods",
                "name": item.name,
                "category": item.category,
                "barcode": item.barcode,
                "stock": item.stock,
                "minStock": item.minStock,
                "purchasePrice": item.purchasePrice,
                "salePrice": item.salePrice,
                "shelfLifeDays": item.shelfLifeDays,
                "note": item.note,
                "createdAt": millis(item.createdAt),
                "updatedAt": millis(item.updatedAt),
            ]
            if let productionDate = item.productionDate { d["productionDate"] = millis(productionDate) }
            if let expiryDate = item.expiryDate { d["expiryDate"] = millis(expiryDate) }
            if let image = item.imageData { d["imageBase64"] = image.base64EncodedString() }
            records.append(d)
        }

        let payload: [String: Any] = [
            "app": appName,
            "version": formatVersion,
            "exportedAt": millis(exportedAt),
            "records": records,
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    /// 生成真正的 .json 文件（固定文件名，每次覆盖），供系统分享面板以文件形式发送
    @MainActor
    static func exportFileURL(context: ModelContext) throws -> URL {
        let data = try exportData(context: context)
        let caches = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = caches.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName, isDirectory: false)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw BackupError.writeFailed(error)
        }
        return url
    }

    // MARK: - 恢复

    /// 解析备份并以「追加」方式恢复进当前 context（不清空现有数据，与旧版恢复语义一致）。
    /// - 直接构造模型、单次 save；完成后统一重建通知、刷新一次快照。
    @discardableResult
    @MainActor
    static func restore(context: ModelContext, from data: Data) throws -> Int {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BackupError.invalidFile
        }
        guard let records = payload["records"] as? [[String: Any]] else {
            throw BackupError.invalidRecords
        }
        let exportedAt = (payload["exportedAt"] as? NSNumber)
            .map { Date(timeIntervalSince1970: $0.doubleValue / 1000) } ?? Date()

        var count = 0
        for item in records {
            let reader = RecordReader(item, exportedAt: exportedAt)
            switch reader.string("type") {
            case "todo":
                context.insert(Todo(
                    title: reader.string("title"),
                    detail: reader.string("detail"),
                    dueDate: reader.date("dueDate"),
                    priority: reader.int("priority") ?? 0,
                    imageData: reader.image("imageBase64"),
                    isCompleted: reader.bool("isCompleted"),
                    createdAt: reader.date("createdAt") ?? exportedAt,
                    // v1 备份无 completedAt：已完成项用导出时间补齐，保证「今日已完成」语义可追踪
                    completedAt: reader.date("completedAt") ?? (reader.bool("isCompleted") ? exportedAt : nil)
                ))
            case "memo":
                context.insert(Memo(
                    title: reader.string("title"),
                    content: reader.string("content"),
                    imageData: reader.image("imageBase64"),
                    createdAt: reader.date("createdAt") ?? exportedAt,
                    updatedAt: reader.date("updatedAt") ?? reader.date("createdAt") ?? exportedAt
                ))
            case "performance":
                context.insert(Performance(
                    amount: reader.double("amount"),
                    note: reader.string("note"),
                    date: reader.date("date") ?? exportedAt,
                    fingerprint: reader.string("fingerprint"),
                    paymentMethod: reader.string("paymentMethod"),
                    orderNo: reader.string("orderNo"),
                    importSource: reader.string("importSource"),
                    // 空则派生 .store，兼容旧备份
                    incomeSource: IncomeSource(rawValue: reader.string("incomeSource"))?.rawValue ?? IncomeSource.store.rawValue
                ))
            case "expense":
                context.insert(Expense(
                    amount: reader.double("amount"),
                    category: reader.string("category").isEmpty ? "其他" : reader.string("category"),
                    note: reader.string("note"),
                    date: reader.date("date") ?? exportedAt,
                    createdAt: reader.date("createdAt") ?? exportedAt
                ))
            case "expiry":
                let returnStatus = reader.statusString("returnStatus", valid: [
                    ReturnStatus.pending.rawValue, ReturnStatus.returned.rawValue,
                ]) ?? ReturnStatus.pending.rawValue
                context.insert(ExpiryItem(
                    name: reader.string("name"),
                    category: reader.string("category"),
                    quantity: reader.int("quantity") ?? 1,
                    productionDate: reader.date("productionDate"),
                    expiryDate: reader.date("expiryDate") ?? exportedAt,
                    remindDaysBefore: reader.int("remindDaysBefore") ?? 7,
                    note: reader.string("note"),
                    imageData: reader.image("imageBase64"),
                    createdAt: reader.date("createdAt") ?? exportedAt,
                    returnStatus: returnStatus,
                    returnedAt: reader.date("returnedAt")
                        ?? (returnStatus == ReturnStatus.returned.rawValue ? exportedAt : nil)
                ))
            case "customer":
                let status = reader.statusString("status", valid: [
                    CustomerStatus.pending.rawValue,
                    CustomerStatus.delivering.rawValue,
                    CustomerStatus.done.rawValue,
                ]) ?? CustomerStatus.pending.rawValue
                let createdAt = reader.date("createdAt") ?? exportedAt
                context.insert(CustomerRequest(
                    customer: reader.string("customer"),
                    roomOrAddress: reader.string("roomOrAddress"),
                    phone: reader.string("phone"),
                    content: reader.string("content"),
                    status: status,
                    imageData: reader.image("imageBase64"),
                    createdAt: createdAt,
                    updatedAt: reader.date("updatedAt") ?? createdAt
                ))
            case "goods":
                context.insert(Goods(
                    name: reader.string("name"),
                    category: reader.string("category").isEmpty ? "其他" : reader.string("category"),
                    barcode: reader.string("barcode"),
                    stock: reader.int("stock") ?? 0,
                    minStock: reader.int("minStock") ?? 0,
                    purchasePrice: reader.double("purchasePrice"),
                    salePrice: reader.double("salePrice"),
                    productionDate: reader.date("productionDate"),
                    shelfLifeDays: reader.int("shelfLifeDays") ?? 0,
                    expiryDate: reader.date("expiryDate"),
                    note: reader.string("note"),
                    imageData: reader.image("imageBase64"),
                    createdAt: reader.date("createdAt") ?? exportedAt,
                    updatedAt: reader.date("updatedAt") ?? reader.date("createdAt") ?? exportedAt
                ))
            default:
                continue
            }
            count += 1
        }

        // 单次落库
        try context.save()

        // 统一重建本地通知（各调度器内部仅安排未来时间，幂等）
        let todos = try? context.fetch(FetchDescriptor<Todo>())
        todos?.forEach { NotificationManager.scheduleTodo($0) }
        let expiryItems = try? context.fetch(FetchDescriptor<ExpiryItem>())
        expiryItems?.forEach { NotificationManager.scheduleExpiry($0) }
        let customers = try? context.fetch(FetchDescriptor<CustomerRequest>())
        customers?.forEach { NotificationManager.rescheduleCustomer($0) }

        SnapshotSyncManager.refreshAll(context: context)
        return count
    }

    // MARK: - 私有工具

    private static func millis(_ date: Date) -> NSNumber {
        NSNumber(value: date.timeIntervalSince1970 * 1000)
    }
}

/// 单条备份记录读取器（容忍 v1 缺字段 / 类型差异）
private struct RecordReader {
    let item: [String: Any]
    let exportedAt: Date

    init(_ item: [String: Any], exportedAt: Date) {
        self.item = item
        self.exportedAt = exportedAt
    }

    func string(_ key: String) -> String {
        (item[key] as? String) ?? ""
    }

    func double(_ key: String) -> Double {
        (item[key] as? NSNumber)?.doubleValue ?? 0
    }

    func int(_ key: String) -> Int? {
        (item[key] as? NSNumber)?.intValue
    }

    func bool(_ key: String) -> Bool {
        if let value = item[key] as? Bool { return value }
        return (item[key] as? NSNumber)?.boolValue ?? false
    }

    func date(_ key: String) -> Date? {
        guard let number = item[key] as? NSNumber else { return nil }
        return Date(timeIntervalSince1970: number.doubleValue / 1000)
    }

    func image(_ key: String) -> Data? {
        guard let base64 = item[key] as? String, !base64.isEmpty else { return nil }
        return Data(base64Encoded: base64)
    }

    /// 读取状态字符串，非法/缺失返回 nil（由调用方落回安全默认）
    func statusString(_ key: String, valid: Set<String>) -> String? {
        guard let value = item[key] as? String, valid.contains(value) else { return nil }
        return value
    }
}
