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
    /// v3：新增每条记录稳定 id（内容指纹，见 fingerprint）；读取侧同时兼容 v1/v2。
    /// v1/v2 备份无 id 时，恢复侧按同一指纹算法从字段现算（保守去重，见下）。
    static let formatVersion = 3
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
                "id": fingerprint(todo: todo),
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
                "id": fingerprint(memo: memo),
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
                "id": fingerprint(performance: performance),
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
                "id": fingerprint(expense: expense),
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
                "id": fingerprint(expiryItem: item),
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
                "id": fingerprint(customer: request),
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
                "id": fingerprint(goods: item),
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


    // MARK: - V3.9.1 P0-3 · 稳定记录身份(内容指纹,无 Schema 变更)
    //
    // 原理:指纹 = 该记录全部导出字段的连接串(类型 + 关键字段 + 状态/时间(秒级) + 图片 base64)。
    // - 新备份(v3)导出时写入 id;恢复时优先认 id,无 id 的旧备份现算同一指纹。
    // - 保守性:只认「全部字段一致」才算重复;同额不同备注/日期/标题的合法交易指纹不同,
    //   绝不只凭金额或粗糙时间+备注去重。代价:同一秒内、全部字段逐字相同的两条记录
    //   会被视为同一条(与恢复重复在导出字段上不可区分,这是保守去重的既定取舍)。
    // - 时间取秒级截断:毫秒 Double 经 JSON 往返有亚毫秒浮点误差,秒级可保证导出/恢复指纹一致;
    //   归一化默认值与 restore 构造完全一致(v1 无 completedAt 的已完成待办补 exportedAt 等),
    //   否则旧备份第二次恢复仍会因默认值漂移而重复。
    // - 图片参与指纹:同名同字段但图片不同的记录不算重复。

    struct RestoreResult {
        let inserted: Int
        let skipped: Int
        let failed: Int
        let insertedByType: [String: Int]
        let skippedByType: [String: Int]
    }

    struct RestorePreview {
        let toInsert: Int
        let skipped: Int
        let failed: Int
        let toInsertByType: [String: Int]
        let skippedByType: [String: Int]
    }

    private static func fpSec(_ date: Date) -> String { "\(Int64(date.timeIntervalSince1970))" }
    private static func fpSecOpt(_ date: Date?) -> String { date.map(fpSec) ?? "-" }
    private static func fpNum(_ value: Double) -> String { "\(value)" }
    private static func fpImage(_ data: Data?) -> String { data?.base64EncodedString() ?? "" }
    private static func fp(_ parts: [String]) -> String { parts.joined(separator: "\u{1F}") }

    static func fingerprint(todo: Todo) -> String {
        fp(["todo", todo.title, todo.detail, "\(todo.priority)", todo.isCompleted ? "1" : "0",
            fpSec(todo.createdAt), fpSecOpt(todo.dueDate), fpSecOpt(todo.completedAt), fpImage(todo.imageData)])
    }
    static func fingerprint(memo: Memo) -> String {
        fp(["memo", memo.title, memo.content, fpSec(memo.createdAt), fpSec(memo.updatedAt), fpImage(memo.imageData)])
    }
    static func fingerprint(performance: Performance) -> String {
        fp(["performance", fpNum(performance.amount), performance.note, fpSec(performance.date),
            performance.fingerprint, performance.paymentMethod, performance.orderNo,
            performance.importSource, performance.incomeSource])
    }
    static func fingerprint(expense: Expense) -> String {
        fp(["expense", fpNum(expense.amount), expense.category, expense.note, fpSec(expense.date), fpSec(expense.createdAt)])
    }
    static func fingerprint(expiryItem: ExpiryItem) -> String {
        fp(["expiry", expiryItem.name, expiryItem.category, "\(expiryItem.quantity)",
            fpSecOpt(expiryItem.productionDate), fpSec(expiryItem.expiryDate), "\(expiryItem.remindDaysBefore)",
            expiryItem.note, expiryItem.returnStatus, fpSecOpt(expiryItem.returnedAt), fpImage(expiryItem.imageData)])
    }
    static func fingerprint(customer: CustomerRequest) -> String {
        fp(["customer", customer.customer, customer.roomOrAddress, customer.phone, customer.content,
            customer.status, fpSec(customer.createdAt), fpSec(customer.updatedAt), fpImage(customer.imageData)])
    }
    static func fingerprint(goods: Goods) -> String {
        fp(["goods", goods.name, goods.category, goods.barcode, "\(goods.stock)", "\(goods.minStock)",
            fpNum(goods.purchasePrice), fpNum(goods.salePrice), fpSecOpt(goods.productionDate),
            "\(goods.shelfLifeDays)", fpSecOpt(goods.expiryDate), goods.note,
            fpSec(goods.createdAt), fpSec(goods.updatedAt), fpImage(goods.imageData)])
    }

    /// 备份记录指纹:优先用 v3 的 id;旧备份按与 restore 构造一致的归一化字段现算。
    /// 返回 nil = 类型未知或无法识别(调用方计 failed,不落库)。
    static func fingerprintForRecord(_ item: [String: Any], exportedAt: Date) -> (type: String, fingerprint: String)? {
        let reader = RecordReader(item, exportedAt: exportedAt)
        switch reader.string("type") {
        case "todo":
            let completedAt = reader.date("completedAt") ?? (reader.bool("isCompleted") ? exportedAt : nil)
            return ("todo", fp(["todo", reader.string("title"), reader.string("detail"),
                "\(reader.int("priority") ?? 0)", reader.bool("isCompleted") ? "1" : "0",
                fpSec(reader.date("createdAt") ?? exportedAt), fpSecOpt(reader.date("dueDate")),
                fpSecOpt(completedAt), reader.string("imageBase64")]))
        case "memo":
            return ("memo", fp(["memo", reader.string("title"), reader.string("content"),
                fpSec(reader.date("createdAt") ?? exportedAt),
                fpSec(reader.date("updatedAt") ?? reader.date("createdAt") ?? exportedAt),
                reader.string("imageBase64")]))
        case "performance":
            let income = IncomeSource(rawValue: reader.string("incomeSource"))?.rawValue ?? IncomeSource.store.rawValue
            return ("performance", fp(["performance", fpNum(reader.double("amount")), reader.string("note"),
                fpSec(reader.date("date") ?? exportedAt), reader.string("fingerprint"),
                reader.string("paymentMethod"), reader.string("orderNo"), reader.string("importSource"), income]))
        case "expense":
            let category = reader.string("category").isEmpty ? "其他" : reader.string("category")
            return ("expense", fp(["expense", fpNum(reader.double("amount")), category, reader.string("note"),
                fpSec(reader.date("date") ?? exportedAt), fpSec(reader.date("createdAt") ?? exportedAt)]))
        case "expiry":
            let status = reader.statusString("returnStatus", valid: [ReturnStatus.pending.rawValue, ReturnStatus.returned.rawValue])
                ?? ReturnStatus.pending.rawValue
            let returnedAt = reader.date("returnedAt") ?? (status == ReturnStatus.returned.rawValue ? exportedAt : nil)
            return ("expiry", fp(["expiry", reader.string("name"), reader.string("category"),
                "\(reader.int("quantity") ?? 1)", fpSecOpt(reader.date("productionDate")),
                fpSec(reader.date("expiryDate") ?? exportedAt), "\(reader.int("remindDaysBefore") ?? 7)",
                reader.string("note"), status, fpSecOpt(returnedAt), reader.string("imageBase64")]))
        case "customer":
            let status = reader.statusString("status", valid: [CustomerStatus.pending.rawValue,
                CustomerStatus.delivering.rawValue, CustomerStatus.done.rawValue]) ?? CustomerStatus.pending.rawValue
            let createdAt = reader.date("createdAt") ?? exportedAt
            return ("customer", fp(["customer", reader.string("customer"), reader.string("roomOrAddress"),
                reader.string("phone"), reader.string("content"), status, fpSec(createdAt),
                fpSec(reader.date("updatedAt") ?? createdAt), reader.string("imageBase64")]))
        case "goods":
            let category = reader.string("category").isEmpty ? "其他" : reader.string("category")
            return ("goods", fp(["goods", reader.string("name"), category, reader.string("barcode"),
                "\(reader.int("stock") ?? 0)", "\(reader.int("minStock") ?? 0)",
                fpNum(reader.double("purchasePrice")), fpNum(reader.double("salePrice")),
                fpSecOpt(reader.date("productionDate")), "\(reader.int("shelfLifeDays") ?? 0)",
                fpSecOpt(reader.date("expiryDate")), reader.string("note"),
                fpSec(reader.date("createdAt") ?? exportedAt),
                fpSec(reader.date("updatedAt") ?? reader.date("createdAt") ?? exportedAt),
                reader.string("imageBase64")]))
        default:
            return nil
        }
    }

    /// 当前库全部记录的指纹集(恢复/预览共用)。
    @MainActor
    static func existingFingerprints(context: ModelContext) throws -> Set<String> {
        var set = Set<String>()
        for todo in try context.fetch(FetchDescriptor<Todo>()) { set.insert(fingerprint(todo: todo)) }
        for memo in try context.fetch(FetchDescriptor<Memo>()) { set.insert(fingerprint(memo: memo)) }
        for performance in try context.fetch(FetchDescriptor<Performance>()) { set.insert(fingerprint(performance: performance)) }
        for expense in try context.fetch(FetchDescriptor<Expense>()) { set.insert(fingerprint(expense: expense)) }
        for item in try context.fetch(FetchDescriptor<ExpiryItem>()) { set.insert(fingerprint(expiryItem: item)) }
        for request in try context.fetch(FetchDescriptor<CustomerRequest>()) { set.insert(fingerprint(customer: request)) }
        for item in try context.fetch(FetchDescriptor<Goods>()) { set.insert(fingerprint(goods: item)) }
        return set
    }

    /// 只解析不落库的恢复预览:预计新增 / 已存在跳过 / 无法识别失败,按类型分列。
    @MainActor
    static func previewRestore(context: ModelContext, from data: Data) throws -> RestorePreview {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BackupError.invalidFile
        }
        guard let records = payload["records"] as? [[String: Any]] else {
            throw BackupError.invalidRecords
        }
        let exportedAt = (payload["exportedAt"] as? NSNumber)
            .map { Date(timeIntervalSince1970: $0.doubleValue / 1000) } ?? Date()
        let existing = try existingFingerprints(context: context)
        var seen = Set<String>()
        var toInsert = 0, skipped = 0, failed = 0
        var toInsertByType: [String: Int] = [:], skippedByType: [String: Int] = [:]
        for item in records {
            // v3 id 优先:若记录自带 id 且库中/文件内已见,直接跳过(不依赖现算指纹)。
            if let id = item["id"] as? String, !id.isEmpty, (existing.contains(id) || seen.contains(id)) {
                skipped += 1; skippedByType[item["type"] as? String ?? "unknown", default: 0] += 1; continue
            }
            guard let (type, fingerprint) = fingerprintForRecord(item, exportedAt: exportedAt) else {
                failed += 1; continue
            }
            if existing.contains(fingerprint) || seen.contains(fingerprint) {
                skipped += 1; skippedByType[type, default: 0] += 1
            } else {
                seen.insert(fingerprint)
                toInsert += 1; toInsertByType[type, default: 0] += 1
            }
        }
        return RestorePreview(toInsert: toInsert, skipped: skipped, failed: failed,
                              toInsertByType: toInsertByType, skippedByType: skippedByType)
    }

    // MARK: - 恢复

    /// 解析备份并以「追加」方式恢复进当前 context（不清空现有数据，与旧版恢复语义一致）。
    /// V3.9.1 P0-3 语义：
    /// - 幂等：同一文件连续恢复两次，第二次新增为 0（文件内重复同样只插一次）。
    /// - 校验先行：JSON/ records 结构非法时在插入任何记录前抛错，库 untouched；
    ///   单条未知类型只计 failed 跳过，不中断其余记录。
    /// - 保存失败回滚：save() 抛错时删除本轮新插对象并再次 save（尽力回滚），再原样抛错，
    ///   避免「部分数据留下造成混乱」；通知/快照只在 save 成功后统一刷新一次。
    @discardableResult
    @MainActor
    static func restore(context: ModelContext, from data: Data) throws -> Int {
        try restoreDetailed(context: context, from: data).inserted
    }

    @MainActor
    static func restoreDetailed(context: ModelContext, from data: Data) throws -> RestoreResult {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BackupError.invalidFile
        }
        guard let records = payload["records"] as? [[String: Any]] else {
            throw BackupError.invalidRecords
        }
        let exportedAt = (payload["exportedAt"] as? NSNumber)
            .map { Date(timeIntervalSince1970: $0.doubleValue / 1000) } ?? Date()
        let existing = try existingFingerprints(context: context)
        var seen = Set<String>()
        var insertedObjects: [any PersistentModel] = []
        var inserted = 0, skipped = 0, failed = 0
        var insertedByType: [String: Int] = [:], skippedByType: [String: Int] = [:]

        for item in records {
            if let id = item["id"] as? String, !id.isEmpty, (existing.contains(id) || seen.contains(id)) {
                skipped += 1; skippedByType[item["type"] as? String ?? "unknown", default: 0] += 1; continue
            }
            guard let (type, fingerprint) = fingerprintForRecord(item, exportedAt: exportedAt) else {
                failed += 1; continue
            }
            if existing.contains(fingerprint) || seen.contains(fingerprint) {
                skipped += 1; skippedByType[type, default: 0] += 1; continue
            }
            seen.insert(fingerprint)
            let reader = RecordReader(item, exportedAt: exportedAt)
            let object: any PersistentModel
            switch type {
            case "todo":
                object = Todo(
                    title: reader.string("title"),
                    detail: reader.string("detail"),
                    dueDate: reader.date("dueDate"),
                    priority: reader.int("priority") ?? 0,
                    imageData: reader.image("imageBase64"),
                    isCompleted: reader.bool("isCompleted"),
                    createdAt: reader.date("createdAt") ?? exportedAt,
                    completedAt: reader.date("completedAt") ?? (reader.bool("isCompleted") ? exportedAt : nil)
                )
            case "memo":
                object = Memo(
                    title: reader.string("title"),
                    content: reader.string("content"),
                    imageData: reader.image("imageBase64"),
                    createdAt: reader.date("createdAt") ?? exportedAt,
                    updatedAt: reader.date("updatedAt") ?? reader.date("createdAt") ?? exportedAt
                )
            case "performance":
                object = Performance(
                    amount: reader.double("amount"),
                    note: reader.string("note"),
                    date: reader.date("date") ?? exportedAt,
                    fingerprint: reader.string("fingerprint"),
                    paymentMethod: reader.string("paymentMethod"),
                    orderNo: reader.string("orderNo"),
                    importSource: reader.string("importSource"),
                    incomeSource: IncomeSource(rawValue: reader.string("incomeSource"))?.rawValue ?? IncomeSource.store.rawValue
                )
            case "expense":
                object = Expense(
                    amount: reader.double("amount"),
                    category: reader.string("category").isEmpty ? "其他" : reader.string("category"),
                    note: reader.string("note"),
                    date: reader.date("date") ?? exportedAt,
                    createdAt: reader.date("createdAt") ?? exportedAt
                )
            case "expiry":
                let returnStatus = reader.statusString("returnStatus", valid: [
                    ReturnStatus.pending.rawValue, ReturnStatus.returned.rawValue,
                ]) ?? ReturnStatus.pending.rawValue
                object = ExpiryItem(
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
                )
            case "customer":
                let status = reader.statusString("status", valid: [
                    CustomerStatus.pending.rawValue,
                    CustomerStatus.delivering.rawValue,
                    CustomerStatus.done.rawValue,
                ]) ?? CustomerStatus.pending.rawValue
                let createdAt = reader.date("createdAt") ?? exportedAt
                object = CustomerRequest(
                    customer: reader.string("customer"),
                    roomOrAddress: reader.string("roomOrAddress"),
                    phone: reader.string("phone"),
                    content: reader.string("content"),
                    status: status,
                    imageData: reader.image("imageBase64"),
                    createdAt: createdAt,
                    updatedAt: reader.date("updatedAt") ?? createdAt
                )
            case "goods":
                object = Goods(
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
                )
            default:
                failed += 1; continue
            }
            context.insert(object)
            insertedObjects.append(object)
            inserted += 1; insertedByType[type, default: 0] += 1
        }

        // 单次落库；失败则尽力回滚本轮新插对象，再原样抛错。
        do {
            try context.save()
        } catch {
            for object in insertedObjects { context.delete(object) }
            try? context.save()
            throw error
        }

        // 统一重建本地通知（各调度器内部仅安排未来时间，幂等）
        let todos = try? context.fetch(FetchDescriptor<Todo>())
        todos?.forEach { NotificationManager.scheduleTodo($0) }
        let expiryItems = try? context.fetch(FetchDescriptor<ExpiryItem>())
        expiryItems?.forEach { NotificationManager.scheduleExpiry($0) }
        let customers = try? context.fetch(FetchDescriptor<CustomerRequest>())
        customers?.forEach { NotificationManager.rescheduleCustomer($0) }

        SnapshotSyncManager.refreshAll(context: context)
        return RestoreResult(inserted: inserted, skipped: skipped, failed: failed,
                             insertedByType: insertedByType, skippedByType: skippedByType)
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
