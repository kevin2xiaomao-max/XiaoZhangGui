import OSLog

// MARK: - 统一日志入口（V3.8 PR-C4）
//
// 约定：
// - 主 App 与 Widget 共享分类常量，日志进 Console.app 可按 subsystem 过滤；
// - 插值默认 `private`（客户/营业敏感值不落明文日志）；确需明文的诊断
//   字段显式标 `privacy: .public`，且只允许非敏感技术字段（id、开关状态、计数）；
// - 替换散落的 `print(...)`：Release 不再向 stdout 泄漏，DEBUG 依旧可见。

enum AppLog {
    private static let subsystem = "com.xiaozhanggui.ios"

    /// Live Activity 生命周期
    static let liveActivity = Logger(subsystem: subsystem, category: "LiveActivity")
    /// 数据库 / 快照同步
    static let database = Logger(subsystem: subsystem, category: "Database")
    /// AI Agent 执行链
    static let agent = Logger(subsystem: subsystem, category: "Agent")
    /// 主题 / 壁纸渲染
    static let theme = Logger(subsystem: subsystem, category: "Theme")
    /// 商品等业务模块诊断（原 DIAG-* 调试打印）
    static let goods = Logger(subsystem: subsystem, category: "Goods")
}
