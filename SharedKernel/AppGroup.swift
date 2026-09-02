import Foundation

// MARK: - App Group / Bundle 常量（App 与 Widget Extension 共享）

enum XZGShared {
    /// App Group 标识：主 App、Widget、App Intents 共用的 UserDefaults 与 SwiftData 容器
    static let appGroupID = "group.com.xiaozhanggui.ios.shared"
    /// 主 App Bundle ID
    static let appBundleID = "com.xiaozhanggui.ios"
    /// Widget Bundle ID
    static let widgetBundleID = "com.xiaozhanggui.ios.widget"

    /// App Group UserDefaults（Widget 读取快照的唯一数据源）
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
}
