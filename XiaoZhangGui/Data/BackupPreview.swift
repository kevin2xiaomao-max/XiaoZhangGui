import Foundation
import SwiftData
import UserNotifications

// MARK: - V3.9 PR-G · 备份 2.0:恢复前预览 + 每周备份提醒
//
// 既有能力(V3.7 P0-1)已覆盖导出文件/恢复往返;本文件补齐三件:
// 1) 恢复前预览:只解析不落库,给出备份内各类型条数 + 与当前库对比,
//    用户确认后才真正 restore(恢复语义仍是「追加合并」,绝不清空现有数据);
// 2) 每周备份提醒:本地通知(每周一 10:00,重复),可开关;
// 3) 备份状态:最近一次备份时间,超过 7 天提示「该备份了」。

// MARK: 恢复预览(纯数据,可单测)

/// 备份文件与当前库的对比快照。
struct BackupPreview: Equatable {
    let exportedAt: Date
    /// 备份内各类型条数(键与备份 type 字段一致)。
    let backupCounts: [String: Int]
    /// 当前库各类型条数(同一套键)。
    let currentCounts: [String: Int]
    /// V3.9.1 P0-3 去重预览:预计新增 / 已存在跳过(nil = 未计算,保持旧调用兼容)。
    let dedupToInsert: Int?
    let dedupSkipped: Int?

    init(exportedAt: Date, backupCounts: [String: Int], currentCounts: [String: Int],
         dedupToInsert: Int? = nil, dedupSkipped: Int? = nil) {
        self.exportedAt = exportedAt
        self.backupCounts = backupCounts
        self.currentCounts = currentCounts
        self.dedupToInsert = dedupToInsert
        self.dedupSkipped = dedupSkipped
    }

    var backupTotal: Int { backupCounts.values.reduce(0, +) }
    var currentTotal: Int { currentCounts.values.reduce(0, +) }

    /// 类型中文名(展示用)。
    static let displayNames: [String: String] = [
        "todo": "待办", "memo": "备忘", "performance": "营业额",
        "expense": "支出", "expiry": "临期", "customer": "配送", "goods": "商品",
    ]
}

enum BackupPreviewService {
    /// 只解析备份 JSON 生成预览(不触碰数据库、不落库)。
    static func parse(data: Data) throws -> BackupPreview {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BackupError.invalidFile
        }
        guard let records = payload["records"] as? [[String: Any]] else {
            throw BackupError.invalidRecords
        }
        let exportedAt = (payload["exportedAt"] as? NSNumber)
            .map { Date(timeIntervalSince1970: $0.doubleValue / 1000) } ?? Date()
        var counts: [String: Int] = [:]
        for record in records {
            if let type = record["type"] as? String {
                counts[type, default: 0] += 1
            }
        }
        return BackupPreview(exportedAt: exportedAt, backupCounts: counts, currentCounts: [:])
    }

    /// 当前库各类型条数(与预览同一套键,便于对比展示)。
    @MainActor
    static func currentSnapshot(context: ModelContext) -> [String: Int] {
        let counts: [(String, Int)] = [
            ("todo", (try? context.fetchCount(FetchDescriptor<Todo>())) ?? 0),
            ("memo", (try? context.fetchCount(FetchDescriptor<Memo>())) ?? 0),
            ("performance", (try? context.fetchCount(FetchDescriptor<Performance>())) ?? 0),
            ("expense", (try? context.fetchCount(FetchDescriptor<Expense>())) ?? 0),
            ("expiry", (try? context.fetchCount(FetchDescriptor<ExpiryItem>())) ?? 0),
            ("customer", (try? context.fetchCount(FetchDescriptor<CustomerRequest>())) ?? 0),
            ("goods", (try? context.fetchCount(FetchDescriptor<Goods>())) ?? 0),
        ]
        return Dictionary(uniqueKeysWithValues: counts)
    }

    /// 组装完整预览(解析备份 + 拉当前库)。
    @MainActor
    static func makePreview(context: ModelContext, data: Data) throws -> BackupPreview {
        let base = try parse(data: data)
        return BackupPreview(
            exportedAt: base.exportedAt,
            backupCounts: base.backupCounts,
            currentCounts: currentSnapshot(context: context)
        )
    }
}

// MARK: 每周备份提醒 + 备份状态

enum BackupReminder {
    private static let lastBackupKey = "xzg.backup.lastAt"
    private static let weeklyEnabledKey = "xzg.backup.weeklyReminderEnabled"
    private static let notificationID = "xzg.backup.weekly"

    /// 每周一 10:00 的重复本地提醒。开启时先核查通知授权：
    /// 未授权（被拒）则不挂提醒、不置开关位，并经 completion 报告 false，
    /// 调用方据此提示用户去系统设置开启；避免“开关显示已开启但永远收不到提醒”。
    static func setWeeklyReminder(_ enabled: Bool, completion: ((Bool) -> Void)? = nil) {
        let defaults = UserDefaults.standard
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        func done(_ ok: Bool) {
            DispatchQueue.main.async { completion?(ok) }
        }
        guard enabled else {
            defaults.set(false, forKey: weeklyEnabledKey)
            done(true)
            return
        }
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.scheduleWeekly(center: center)
                defaults.set(true, forKey: weeklyEnabledKey)
                done(true)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted {
                        self.scheduleWeekly(center: center)
                        defaults.set(true, forKey: weeklyEnabledKey)
                        done(true)
                    } else {
                        defaults.set(false, forKey: weeklyEnabledKey)
                        done(false)
                    }
                }
            default: // .denied：不挂提醒、不置开关位，调用方提示去设置。
                defaults.set(false, forKey: weeklyEnabledKey)
                done(false)
            }
        }
    }

    /// 实际挂提醒（已授权时调用）。
    private static func scheduleWeekly(center: UNUserNotificationCenter = .current()) {
        let content = UNMutableNotificationContent()
        content.title = "该给账本备份啦"
        content.body = "花十秒导出一份备份,生意记录再也不怕丢。"
        content.sound = .default
        var components = DateComponents()
        components.weekday = 2 // 周一
        components.hour = 10
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        center.add(request)
    }

    /// 导出成功后静默重挂提醒（仅已授权时；未授权不改开关位，
    /// 等用户下次手动开关时再走授权流程并提示）。
    static func rescheduleIfNeeded() {
        guard weeklyReminderEnabled else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.scheduleWeekly()
            default:
                break
            }
        }
    }

    static var weeklyReminderEnabled: Bool {
        UserDefaults.standard.bool(forKey: weeklyEnabledKey)
    }

    /// 导出成功后记录时间(顺带在超期且开关开启时,重挂提醒确保在位)。
    /// 注意：调用方必须在用户真正完成分享（ShareSheet completed）后才调本函数；
    /// 仅生成文件不算备份成功。
    static func markBackedUp(now: Date = Date()) {
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastBackupKey)
        rescheduleIfNeeded()
    }

    static var lastBackupDate: Date? {
        let ts = UserDefaults.standard.double(forKey: lastBackupKey)
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    /// 距上次备份是否已超 7 天(从未备份也返回 true)。
    static func isOverdue(now: Date = Date(), window: TimeInterval = 7 * 24 * 3600) -> Bool {
        guard let last = lastBackupDate else { return true }
        return now.timeIntervalSince(last) > window
    }

    /// 备份行尾的状态文案。
    static func statusText(now: Date = Date()) -> String {
        guard let last = lastBackupDate else { return "还没备份过" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        let base = "上次 " + formatter.string(from: last)
        return isOverdue(now: now) ? base + " · 该备份了" : base
    }
}
