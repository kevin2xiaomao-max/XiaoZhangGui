import Foundation
import SwiftData

// MARK: - 数据仓库层
// View → ViewModel/Observable → Repository → SwiftData
// 写操作统一走 Repository；列表读取在 View 层用 @Query 保持实时刷新
//
// P1-4 变更：每次成功增/改/删/完成/状态推进后，调用
// SnapshotSyncManager.refreshAll(context:)
// 同步 BusinessSnapshot / Widget Timeline / Live Activity，
// 避免必须切换前后台才刷新。

struct TodoRepository {
    let context: ModelContext

    func add(title: String, detail: String = "", dueDate: Date? = nil, priority: Int = 0, imageData: Data? = nil) throws {
        let todo = Todo(title: title, detail: detail, dueDate: dueDate, priority: priority, imageData: imageData)
        context.insert(todo)
        try context.save()
        NotificationManager.scheduleTodo(todo)
        SnapshotSyncManager.refreshAll(context: context)
    }

    /// P0-1 修复：删除原本不存在的 todo.updated() 调用（Todo 模型 Android 语义
    /// 不含 updatedAt 字段，保持字段与 Android 对齐，不凭空新增）
    func update(_ todo: Todo) throws {
        try context.save()
        NotificationManager.cancelTodo(todo)
        NotificationManager.scheduleTodo(todo)
        SnapshotSyncManager.refreshAll(context: context)
    }

    func toggleComplete(_ todo: Todo) throws {
        todo.isCompleted.toggle()
        todo.completedAt = todo.isCompleted ? Date() : nil
        try context.save()
        if todo.isCompleted {
            NotificationManager.cancelTodo(todo)
        } else {
            NotificationManager.scheduleTodo(todo)
        }
        SnapshotSyncManager.refreshAll(context: context)
    }

    func delete(_ todo: Todo) throws {
        NotificationManager.cancelTodo(todo)
        context.delete(todo)
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }
}

struct MemoRepository {
    let context: ModelContext

    func add(title: String, content: String, imageData: Data? = nil) throws {
        context.insert(Memo(title: title, content: content, imageData: imageData))
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }

    func update(_ memo: Memo) throws {
        memo.updatedAt = Date()
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }

    func delete(_ memo: Memo) throws {
        context.delete(memo)
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }
}

struct PerformanceRepository {
    let context: ModelContext

    /// P0-3：新增 incomeSource 参数，默认 .store（兼容旧调用方语义）
    func add(amount: Double, note: String, date: Date = Date(), incomeSource: IncomeSource = .store) throws {
        context.insert(Performance(
            amount: amount,
            note: note,
            date: date,
            incomeSource: incomeSource.rawValue
        ))
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }

    func addImported(_ row: SaobeiParsedRow) throws {
        // P0-3：扫呗导入时按 paymentMethod 派生 incomeSource
        let source = IncomeSource.from(note: row.paymentMethod)
        context.insert(Performance(
            amount: row.amount,
            note: row.paymentMethod.isEmpty ? "扫呗" : "扫呗 · \(row.paymentMethod)",
            date: row.date,
            fingerprint: row.fingerprint,
            paymentMethod: row.paymentMethod,
            orderNo: row.orderNo,
            importSource: "saobei",
            incomeSource: source.rawValue
        ))
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }

    /// 批量导入扫呗记录。
    /// P1-3：
    /// - 同时防「数据库已有重复」与「同一文件内部重复」——每接受一条立即把 fingerprint
    ///   回写本轮 seen Set，后续相同行（含文件内孪生行）只计 duplicates 不落库。
    /// - 批量 insert → 一次 context.save() → 一次 Snapshot/Widget/Live Activity 刷新，
    ///   不再逐行 save / 逐行刷新。
    func importSaobei(_ rows: [SaobeiParsedRow], skippedFailed: Int) throws -> SaobeiImportCommitResult {
        var inserted = 0
        var duplicates = 0
        var seen = Set(
            (try context.fetch(FetchDescriptor<Performance>()))
                .map(\.fingerprint)
                .filter { !$0.isEmpty }
        )
        var accepted: [Performance] = []
        accepted.reserveCapacity(rows.count)

        for row in rows {
            if !row.fingerprint.isEmpty, seen.contains(row.fingerprint) {
                duplicates += 1
                continue
            }
            // P0-3：扫呗导入按 paymentMethod 派生 incomeSource
            let source = IncomeSource.from(note: row.paymentMethod)
            accepted.append(Performance(
                amount: row.amount,
                note: row.paymentMethod.isEmpty ? "扫呗" : "扫呗 · \(row.paymentMethod)",
                date: row.date,
                fingerprint: row.fingerprint,
                paymentMethod: row.paymentMethod,
                orderNo: row.orderNo,
                importSource: "saobei",
                incomeSource: source.rawValue
            ))
            seen.insert(row.fingerprint)
            inserted += 1
        }

        guard !accepted.isEmpty else {
            return SaobeiImportCommitResult(inserted: 0, duplicates: duplicates, skippedFailed: skippedFailed)
        }
        accepted.forEach { context.insert($0) }
        try context.save() // 单次落库
        SnapshotSyncManager.refreshAll(context: context) // 单次 Snapshot / Widget / Live Activity
        return SaobeiImportCommitResult(inserted: inserted, duplicates: duplicates, skippedFailed: skippedFailed)
    }

    func update(_ performance: Performance) throws {
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }

    func delete(_ performance: Performance) throws {
        context.delete(performance)
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }
}

struct ExpenseRepository {
    let context: ModelContext

    func add(amount: Double, category: String = "其他", note: String = "", date: Date = Date()) throws {
        context.insert(Expense(amount: amount, category: category, note: note, date: date))
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }

    func update(_ expense: Expense) throws {
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }

    func delete(_ expense: Expense) throws {
        context.delete(expense)
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }
}

struct ExpiryRepository {
    let context: ModelContext

    func add(
        name: String,
        category: String = "",
        quantity: Int = 1,
        productionDate: Date? = nil,
        expiryDate: Date,
        remindDaysBefore: Int = 7,
        note: String = "",
        imageData: Data? = nil
    ) throws {
        let item = ExpiryItem(
            name: name,
            category: category,
            quantity: quantity,
            productionDate: productionDate,
            expiryDate: expiryDate,
            remindDaysBefore: remindDaysBefore,
            note: note,
            imageData: imageData
        )
        context.insert(item)
        try context.save()
        NotificationManager.scheduleExpiry(item)
        SnapshotSyncManager.refreshAll(context: context)
    }

    func update(_ item: ExpiryItem) throws {
        try context.save()
        NotificationManager.cancelExpiry(item)
        NotificationManager.scheduleExpiry(item)
        SnapshotSyncManager.refreshAll(context: context)
    }

    /// 标记退货 / 恢复
    func toggleReturn(_ item: ExpiryItem) throws {
        item.status = item.status == .returned ? .pending : .returned
        try context.save()
        if item.status == .returned {
            NotificationManager.cancelExpiry(item)
        } else {
            NotificationManager.scheduleExpiry(item)
        }
        SnapshotSyncManager.refreshAll(context: context)
    }

    func delete(_ item: ExpiryItem) throws {
        NotificationManager.cancelExpiry(item)
        context.delete(item)
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }
}

struct CustomerRepository {
    let context: ModelContext

    func add(customer: String, roomOrAddress: String, phone: String, content: String, imageData: Data? = nil) throws {
        let request = CustomerRequest(
            customer: customer,
            roomOrAddress: roomOrAddress,
            phone: phone,
            content: content,
            imageData: imageData
        )
        context.insert(request)
        try context.save()
        NotificationManager.rescheduleCustomer(request)
        SnapshotSyncManager.refreshAll(context: context)
    }

    /// P1-5 修复：编辑后统一重排跟进通知（状态/内容变化都生效）。
    /// 新的 rescheduleCustomer 已考虑离开 pending 时立即取消。
    func update(_ request: CustomerRequest) throws {
        request.updatedAt = Date()
        try context.save()
        NotificationManager.rescheduleCustomer(request)
        SnapshotSyncManager.refreshAll(context: context)
    }

    /// 状态推进：待处理 → 配送中 → 已完成
    /// P1-5：离开 pending（pending→delivering）时立即取消原跟进通知。
    func advanceStatus(_ request: CustomerRequest) throws {
        let prev = request.statusEnum
        request.status = request.statusEnum.next.rawValue
        request.updatedAt = Date()
        try context.save()
        // 只要不是从 pending→pending（理论上不会），先取消再按需重排。
        if prev == .pending {
            NotificationManager.cancelCustomer(request)
        }
        // 对于 done，保持取消；对于 delivering / pending（异常）保持一致。
        if request.statusEnum == .done {
            // 已完成状态，不安排任何通知
        } else {
            // delivering 暂不重新安排，保留 pending 时已存在的跟进逻辑。
        }
        SnapshotSyncManager.refreshAll(context: context)
    }

    func delete(_ request: CustomerRequest) throws {
        NotificationManager.cancelCustomer(request)
        context.delete(request)
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }
}

struct GoodsRepository {
    let context: ModelContext

    func add(_ goods: Goods) throws {
        context.insert(goods)
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }

    func update(_ goods: Goods) throws {
        goods.updatedAt = Date()
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }

    func delete(_ goods: Goods) throws {
        context.delete(goods)
        try context.save()
        SnapshotSyncManager.refreshAll(context: context)
    }
}
