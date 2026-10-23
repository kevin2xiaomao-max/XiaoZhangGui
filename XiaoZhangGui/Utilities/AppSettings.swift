import Foundation
import SwiftUI
import Observation

// MARK: - 应用偏好设置（对齐 Android SharedPreferences 字段）

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let ud: UserDefaults
    /// V3.8 P0-A2：月目标跨进程共享存储（App Group）。
    /// Widget / App Intents 是独立进程，UserDefaults.standard 各自隔离，
    /// 曾导致 Widget 快照按默认目标计算。shared 不可用时（无 App Group 的
    /// 裸测试宿主）回落 legacy 行为，读写语义不变。
    private let sharedDefaults: UserDefaults?

    private static let monthGoalKey = "month_goal"

    var shopName: String {
        didSet { ud.set(shopName, forKey: "shop_name") }
    }
    var ownerName: String {
        didSet { ud.set(ownerName, forKey: "owner_name") }
    }
    var monthGoal: Double {
        didSet {
            // 双写：App Group 供 Widget 进程读取；legacy 继续写，回滚到旧版本不丢设置。
            ud.set(monthGoal, forKey: Self.monthGoalKey)
            sharedDefaults?.set(monthGoal, forKey: Self.monthGoalKey)
        }
    }
    /// system / light / dark
    var themeMode: String {
        didSet { ud.set(themeMode, forKey: "theme_mode") }
    }
    var todoReminderEnabled: Bool {
        didSet { ud.set(todoReminderEnabled, forKey: "todo_reminder") }
    }
    var expiryReminderEnabled: Bool {
        didSet { ud.set(expiryReminderEnabled, forKey: "expiry_reminder") }
    }
    var voiceLanguage: String {
        didSet { ud.set(voiceLanguage, forKey: "voice_language") }
    }
    var avatarEmoji: String {
        didSet { ud.set(avatarEmoji, forKey: "avatar_emoji") }
    }
    var avatarImageData: Data? {
        didSet {
            if let avatarImageData { ud.set(avatarImageData, forKey: "avatar_image_data") }
            else { ud.removeObject(forKey: "avatar_image_data") }
        }
    }
    // P1-4：旧 appThemeName（app_theme_name）属性已删除。
    // 主题唯一入口是 ThemeStore；旧 key 的一次性迁移在 ThemeStore.init 完成（T26）。

    init(legacy: UserDefaults = .standard, shared: UserDefaults? = XZGShared.sharedDefaults) {
        ud = legacy
        sharedDefaults = shared
        shopName = ud.string(forKey: "shop_name") ?? "天福便利店"
        ownerName = ud.string(forKey: "owner_name") ?? "掌柜"
        monthGoal = Self.loadMonthGoal(legacy: ud, shared: shared)
        themeMode = ud.string(forKey: "theme_mode") ?? "system"
        todoReminderEnabled = ud.object(forKey: "todo_reminder") as? Bool ?? true
        expiryReminderEnabled = ud.object(forKey: "expiry_reminder") as? Bool ?? true
        voiceLanguage = ud.string(forKey: "voice_language") ?? "普通话"
        avatarEmoji = ud.string(forKey: "avatar_emoji") ?? "👨🏻‍💼"
        avatarImageData = ud.data(forKey: "avatar_image_data")
    }

    /// 月目标读取顺序（V3.8 P0-A2）：
    /// 1) App Group 已有值 → 直接用（主 App 与 Widget 的共同事实源）；
    /// 2) 仅 legacy 有值 → 一次性迁移补写 App Group，**不清除、不覆盖 legacy**；
    /// 3) 都没有 → 默认 120000（不落盘，保持「未设置」语义）。
    private static func loadMonthGoal(legacy: UserDefaults, shared: UserDefaults?) -> Double {
        if let sharedValue = shared?.object(forKey: monthGoalKey) as? Double {
            return sharedValue
        }
        if let legacyValue = legacy.object(forKey: monthGoalKey) as? Double {
            shared?.set(legacyValue, forKey: monthGoalKey)
            return legacyValue
        }
        return 120000.0
    }

    var colorScheme: ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var themeModeLabel: String {
        switch themeMode {
        case "light": return "浅色"
        case "dark": return "深色"
        default: return "跟随系统"
        }
    }
}
