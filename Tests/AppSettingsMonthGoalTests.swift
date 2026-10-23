import XCTest
@testable import XiaoZhangGui

/// V3.8 P0-A2：月目标跨进程共享（App Group）与旧值迁移测试。
///
/// 修复前：monthGoal 只写 UserDefaults.standard，Widget / App Intents 是独立
/// 进程读不到，快照按默认目标 120000 计算。
/// 修复后：读序 App Group → legacy（一次性迁移补写，不清除）→ 默认；
/// 写入双写两处。
final class AppSettingsMonthGoalTests: XCTestCase {

    private let legacySuite = "test.xzg.monthgoal.legacy"
    private let sharedSuite = "test.xzg.monthgoal.shared"

    private func makeSuites() -> (legacy: UserDefaults, shared: UserDefaults) {
        let legacy = UserDefaults(suiteName: legacySuite)!
        let shared = UserDefaults(suiteName: sharedSuite)!
        legacy.removePersistentDomain(forName: legacySuite)
        shared.removePersistentDomain(forName: sharedSuite)
        return (legacy, shared)
    }

    /// 都没设置 → 默认 120000，且不向任何存储落盘（保持「未设置」语义）。
    func testDefaultGoalWhenNothingStored() {
        let suites = makeSuites()
        let settings = AppSettings(legacy: suites.legacy, shared: suites.shared)
        XCTAssertEqual(settings.monthGoal, 120000.0)
        XCTAssertNil(suites.shared.object(forKey: "month_goal"))
        XCTAssertNil(suites.legacy.object(forKey: "month_goal"))
    }

    /// 设置自定义目标 → 双写 legacy 与 App Group（Widget 进程读后者）。
    func testCustomGoalWritesBothStores() {
        let suites = makeSuites()
        let settings = AppSettings(legacy: suites.legacy, shared: suites.shared)
        settings.monthGoal = 99000
        XCTAssertEqual(suites.legacy.object(forKey: "month_goal") as? Double, 99000)
        XCTAssertEqual(suites.shared.object(forKey: "month_goal") as? Double, 99000)
    }

    /// 升级迁移：仅 legacy 有旧值 → 读到旧值并补写 App Group，legacy 不清除不覆盖。
    func testLegacyValueMigratesToSharedWithoutOverwrite() {
        let suites = makeSuites()
        suites.legacy.set(88888.0, forKey: "month_goal")

        let settings = AppSettings(legacy: suites.legacy, shared: suites.shared)
        XCTAssertEqual(settings.monthGoal, 88888.0, "迁移不得改变用户已设置的值")
        XCTAssertEqual(
            suites.shared.object(forKey: "month_goal") as? Double, 88888.0,
            "legacy 旧值必须一次性补写 App Group"
        )
        XCTAssertEqual(
            suites.legacy.object(forKey: "month_goal") as? Double, 88888.0,
            "迁移不得清除 legacy 旧值（回滚兼容）"
        )
    }

    /// 优先级：App Group 有值时以它为准，legacy 不被读写覆盖。
    func testSharedValueTakesPrecedenceOverLegacy() {
        let suites = makeSuites()
        suites.shared.set(77777.0, forKey: "month_goal")
        suites.legacy.set(99999.0, forKey: "month_goal")

        let settings = AppSettings(legacy: suites.legacy, shared: suites.shared)
        XCTAssertEqual(settings.monthGoal, 77777.0)
        XCTAssertEqual(suites.legacy.object(forKey: "month_goal") as? Double, 99999.0,
                       "读取不得反向覆盖 legacy")
    }

    /// 重新启动（重建实例）后读到同一值：主 App 与 Widget 口径一致。
    func testValueSurvivesRelaunch() {
        let suites = makeSuites()
        AppSettings(legacy: suites.legacy, shared: suites.shared).monthGoal = 66666

        let relaunched = AppSettings(legacy: suites.legacy, shared: suites.shared)
        XCTAssertEqual(relaunched.monthGoal, 66666.0)
    }

    /// 设置变更后，另一进程（新实例、仅持有 shared）读到新值——Widget 同步语义。
    func testWidgetProcessSeesUpdatedGoal() {
        let suites = makeSuites()
        AppSettings(legacy: suites.legacy, shared: suites.shared).monthGoal = 123456

        // 模拟 Widget 进程：只有 App Group 可读，legacy 域为空。
        let widgetSideLegacy = UserDefaults(suiteName: "test.xzg.monthgoal.widget-process")!
        widgetSideLegacy.removePersistentDomain(forName: "test.xzg.monthgoal.widget-process")
        let widgetSettings = AppSettings(legacy: widgetSideLegacy, shared: suites.shared)
        XCTAssertEqual(widgetSettings.monthGoal, 123456.0,
                       "Widget 进程必须从 App Group 读到主 App 设置的月目标")
    }
}
