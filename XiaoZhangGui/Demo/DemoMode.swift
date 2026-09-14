import Foundation
import Observation
import SwiftData

/// 演示模式开关。数据走独立内存容器，关闭后立刻回到真实 SwiftData。
@Observable
final class DemoMode {
    static let shared = DemoMode()
    static let userDefaultsKey = "xzg_demo_mode_enabled"

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.userDefaultsKey)
            sessionID = UUID()
        }
    }

    var sessionID: UUID = UUID()

    private init() {
        if UserDefaults.standard.object(forKey: Self.userDefaultsKey) == nil {
            isEnabled = true
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: Self.userDefaultsKey)
        }
    }

    func resetDemoData() {
        DemoCatalog.reset()
        sessionID = UUID()
    }
}

enum DemoCatalog {
    private static let lock = NSLock()
    private static var boxed: ModelContainer?

    static var container: ModelContainer {
        lock.lock()
        defer { lock.unlock() }
        if let boxed { return boxed }
        let created = makeContainer()
        boxed = created
        return created
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        boxed = makeContainer()
    }

    static func makeContainer(now: Date = Date()) -> ModelContainer {
        let config = ModelConfiguration(schema: AppDatabase.schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: AppDatabase.schema, configurations: [config])
        seed(container.mainContext, now: now)
        return container
    }

    static func seed(_ context: ModelContext, now: Date = Date()) {
        seedPerformances(context, now: now)
        seedTodos(context, now: now)
        seedDeliveries(context, now: now)
        seedExpiry(context, now: now)
        seedMemos(context, now: now)
        try? context.save()
    }

    private static func day(_ offset: Int, hour: Int, minute: Int, from now: Date) -> Date {
        let cal = Calendar.current
        let base = cal.startOfDay(for: now)
        let date = cal.date(byAdding: .day, value: offset, to: base) ?? base
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    private static func seedPerformances(_ context: ModelContext, now: Date) {
        let last7: [(Int, Double)] = [
            (-6, 2180), (-5, 2460), (-4, 2320), (-3, 2790), (-2, 3180), (-1, 2381.20)
        ]
        for (offset, amount) in last7 {
            context.insert(Performance(
                amount: amount,
                note: "扫呗",
                date: day(offset, hour: 22, minute: 10, from: now),
                fingerprint: "demo-day-\(offset)",
                paymentMethod: "扫呗",
                importSource: "扫呗"
            ))
        }

        let todayRows: [(Int, Int, Double, String)] = [
            (9, 35, 128.50, "扫呗"), (10, 18, 56.00, "扫呗"), (11, 42, 236.80, "扫呗"),
            (12, 6, 89.90, "扫呗"), (13, 28, 318.00, "扫呗"), (14, 16, 42.50, "扫呗"),
            (15, 38, 168.00, "扫呗"), (16, 12, 96.00, "扫呗"), (17, 45, 288.80, "扫呗"),
            (18, 36, 428.00, "扫呗"), (19, 20, 198.00, "扫呗"), (20, 14, 368.00, "扫呗"),
            (21, 8, 262.00, "手动")
        ]
        for (h, m, amount, source) in todayRows {
            context.insert(Performance(
                amount: amount,
                note: source,
                date: day(0, hour: h, minute: m, from: now),
                fingerprint: source == "扫呗" ? "demo-today-\(h)\(m)" : "",
                paymentMethod: source,
                importSource: source
            ))
        }

        let extra: [Int: Double] = [
            -29: 1980, -28: 2110, -27: 1860, -26: 3420, -25: 4010, -24: 4280, -23: 1760,
            -22: 2050, -21: 2190, -20: 1940, -19: 3680, -18: 4120, -17: 3890, -16: 1720,
            -15: 2210, -14: 2380, -13: 2090, -12: 2560, -11: 3710, -10: 4450, -9: 3180,
            -8: 1880, -7: 2240
        ]
        for (offset, amount) in extra {
            context.insert(Performance(
                amount: amount,
                note: "扫呗",
                date: day(offset, hour: 21, minute: 40, from: now),
                fingerprint: "demo-hist-\(offset)",
                paymentMethod: "扫呗",
                importSource: "扫呗"
            ))
        }
    }

    private static func seedTodos(_ context: ModelContext, now: Date) {
        func add(_ title: String, dayOffset: Int, hour: Int, minute: Int, priority: Int, done: Bool, completedOffset: Int? = nil) {
            let due = day(dayOffset, hour: hour, minute: minute, from: now)
            context.insert(Todo(
                title: title,
                detail: "",
                dueDate: due,
                priority: priority,
                isCompleted: done,
                createdAt: day(min(dayOffset, -1), hour: 8, minute: 0, from: now),
                completedAt: done ? day(completedOffset ?? dayOffset, hour: hour + 1, minute: 0, from: now) : nil
            ))
        }
        add("确0认饮料供应商送货", dayOffset: 0, hour: 9, minute: 30, priority: 2, done: true)
        add("整理冰柜临期饮料", dayOffset: 0, hour: 11, minute: 0, priority: 1, done: true)
        add("联系可口可乐供应商", dayOffset: 0, hour: 15, minute: 0, priority: 2, done: false)
        add("核对今天配送订单", dayOffset: 0, hour: 18, minute: 30, priority: 1, done: false)
        add("记录今日营业额", dayOffset: 0, hour: 22, minute: 30, priority: 0, done: false)
        add("补充早餐饮料", dayOffset: 1, hour: 9, minute: 0, priority: 1, done: false)
        add("联系泳衣供应商", dayOffset: 1, hour: 10, minute: 30, priority: 2, done: false)
        add("整理退货商品", dayOffset: 1, hour: 14, minute: 0, priority: 1, done: false)
        add("确认周末备货", dayOffset: 1, hour: 18, minute: 0, priority: 0, done: false)
        add("确认纸巾补货", dayOffset: -1, hour: 16, minute: 0, priority: 2, done: false)
        add("整理供应商欠货记录", dayOffset: -2, hour: 20, minute: 0, priority: 1, done: false)
        add("清点矿泉水", dayOffset: -1, hour: 9, minute: 0, priority: 0, done: true, completedOffset: -1)
        add("联系雪糕供应商", dayOffset: -1, hour: 11, minute: 0, priority: 1, done: true, completedOffset: -1)
        add("确认客户配送", dayOffset: -1, hour: 13, minute: 0, priority: 1, done: true, completedOffset: -1)
        add("整理收银台", dayOffset: -2, hour: 10, minute: 0, priority: 0, done: true, completedOffset: -2)
        add("记录昨日营业额", dayOffset: -1, hour: 22, minute: 0, priority: 0, done: true, completedOffset: -1)
        add("确认泳衣库存", dayOffset: -3, hour: 15, minute: 0, priority: 1, done: true, completedOffset: -3)
        add("检查冰柜", dayOffset: -2, hour: 8, minute: 30, priority: 2, done: true, completedOffset: -2)
        add("回复供应商微信", dayOffset: -3, hour: 19, minute: 0, priority: 0, done: true, completedOffset: -3)
        add("整理周末备货", dayOffset: 4, hour: 10, minute: 0, priority: 1, done: false)
        add("月中经营复盘", dayOffset: 6, hour: 20, minute: 0, priority: 1, done: false)
    }

    private static func seedDeliveries(_ context: ModelContext, now: Date) {
        func insert(name: String, content: String, address: String, status: CustomerStatus, dayOffset: Int, hour: Int, minute: Int) {
            let when = day(dayOffset, hour: hour, minute: minute, from: now)
            let encoded = CustomerDeliveryStorage.encode(existingValue: name, deliveryTime: when, note: "")
            context.insert(CustomerRequest(
                customer: encoded,
                roomOrAddress: address,
                phone: "",
                content: content,
                status: status.rawValue,
                createdAt: when
            ))
        }
        insert(name: "张老板", content: "矿泉水 × 3箱，饮料 × 2箱", address: "温泉路 18 号", status: .pending, dayOffset: 0, hour: 17, minute: 30)
        insert(name: "陈姐", content: "零食礼包 × 2", address: "小区 3 栋", status: .pending, dayOffset: 0, hour: 19, minute: 0)
        insert(name: "王先生", content: "饮料 × 4箱", address: "镇政府对面", status: .done, dayOffset: 0, hour: 11, minute: 30)
        insert(name: "李阿姨", content: "纯牛奶 × 2箱", address: "市场西门", status: .delivering, dayOffset: 0, hour: 16, minute: 0)
        insert(name: "周哥", content: "矿泉水 × 5箱", address: "工业园门口", status: .done, dayOffset: -1, hour: 18, minute: 20)
        insert(name: "吴姐", content: "雪糕 × 1箱", address: "小学旁", status: .done, dayOffset: -2, hour: 15, minute: 10)
        insert(name: "赵老板", content: "饮料礼盒 × 3", address: "酒店后街", status: .done, dayOffset: -3, hour: 19, minute: 40)
        insert(name: "供应商送货", content: "可口可乐补货", address: "店门口", status: .pending, dayOffset: 1, hour: 14, minute: 0)
        insert(name: "周末备货", content: "饮料与水整托", address: "仓库", status: .pending, dayOffset: 4, hour: 9, minute: 0)
    }

    private static func seedExpiry(_ context: ModelContext, now: Date) {
        func insert(name: String, qty: Int, days: Int, status: ReturnStatus) {
            let expiry = Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: now)) ?? now
            context.insert(ExpiryItem(
                name: name,
                category: "临期",
                quantity: qty,
                expiryDate: expiry,
                returnStatus: status.rawValue,
                returnedAt: status == .returned ? day(-2, hour: 12, minute: 0, from: now) : nil
            ))
        }
        insert(name: "纯牛奶", qty: 2, days: 3, status: .pending)
        insert(name: "椰汁", qty: 1, days: 1, status: .pending)
        insert(name: "儿童泳衣", qty: 6, days: 7, status: .pending)
        insert(name: "矿泉水", qty: 3, days: 0, status: .pending)
        insert(name: "面包", qty: 8, days: 2, status: .pending)
        insert(name: "酸奶", qty: 12, days: 4, status: .pending)
        insert(name: "雪糕", qty: 1, days: -3, status: .returned)
        insert(name: "火腿肠", qty: 2, days: -1, status: .returned)
        insert(name: "饼干礼盒", qty: 4, days: 10, status: .returned)
    }

    private static func seedMemos(_ context: ModelContext, now: Date) {
        let notes = [
            (0, "可口可乐供应商说周三下午送货。"),
            (-1, "泳衣新款月底前可以退换。"),
            (0, "张老板下次配送记得带两箱矿泉水。"),
            (-2, "冰柜第二层温度偶尔偏高，继续观察。"),
            (-1, "周末温泉客人可能增加，提前准备饮料。"),
            (-3, "纸巾供应商改到周四对账。"),
            (-4, "收银台备用金今晚清点过，差额已补。"),
            (-5, "新到一批儿童泳衣，先放仓库第二层。"),
            (-6, "邻居店在做买一送一，观察客流变化。")
        ]
        for (offset, text) in notes {
            context.insert(Memo(
                title: text,
                content: text,
                createdAt: day(offset, hour: 20, minute: 15, from: now),
                updatedAt: day(offset, hour: 20, minute: 15, from: now)
            ))
        }
    }
}

enum DemoImportPreview {
    static let fileName = "扫呗交易明细_2026-09-14.csv"
    static let fileCount = 328
    static let validCount = 316
    static let duplicateCount = 12
    static let insertedCount = 304
    static let amount = 18628.50

    static func parseResult(now: Date = Date()) -> SaobeiParseResult {
        let cal = Calendar.current
        let samples: [(Int, Int, Double)] = [(9, 2, 28.00), (9, 8, 15.50), (9, 16, 46.00), (9, 25, 128.00), (9, 31, 36.80)]
        let rows = samples.map { hour, minute, amount -> SaobeiParsedRow in
            let date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
            return SaobeiParsedRow(
                date: date,
                amount: amount,
                status: "成功",
                orderNo: String(format: "DEMO%02d%02d", hour, minute),
                paymentMethod: "扫呗",
                fingerprint: String(format: "demo-import-%02d%02d", hour, minute),
                isSuccess: true,
                rawLine: ""
            )
        }
        return SaobeiParseResult(rows: rows, skipped: [], errors: [], sourceFileName: fileName)
    }

    static var fakeCommit: SaobeiImportCommitResult {
        SaobeiImportCommitResult(inserted: insertedCount, duplicates: duplicateCount, skippedFailed: fileCount - validCount)
    }
}
