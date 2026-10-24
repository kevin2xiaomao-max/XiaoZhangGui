import XCTest
@testable import XiaoZhangGui

final class V371Phase0ReliabilityTests: XCTestCase {
    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    func testFailureInjectionArgumentMapsOnlyKnownOperations() {
        XCTAssertEqual(
            UITestFailureInjection.requestedOperation(
                arguments: ["app", "--ui-testing-fail-once", "customer.advance"]
            ),
            .customerAdvance
        )
        XCTAssertEqual(
            UITestFailureInjection.requestedOperation(
                arguments: ["app", "--ui-testing-fail-once", "expiry.toggleReturn"]
            ),
            .expiryToggleReturn
        )
        XCTAssertNil(
            UITestFailureInjection.requestedOperation(
                arguments: ["app", "--ui-testing-fail-once", "unknown.operation"]
            )
        )
        XCTAssertNil(UITestFailureInjection.requestedOperation(arguments: ["app"]))
    }

    func testReachableStateActionsDoNotSilentlyDiscardRepositoryErrors() throws {
        let expectations: [(path: String, forbidden: String, visibleFailure: String)] = [
            (
                "XiaoZhangGui/Features/Customer/CustomerView.swift",
                "try? CustomerRepository(context: context).advanceStatus",
                "配送状态未改变，请重试"
            ),
            (
                "XiaoZhangGui/Features/Expiry/ExpiryView.swift",
                "try? ExpiryRepository(context: context).toggleReturn",
                "退货状态未改变，请重试"
            ),
            (
                "XiaoZhangGui/Features/Goods/GoodsView.swift",
                "try? GoodsRepository(context: context).delete",
                "商品未删除，请重试"
            ),
            (
                "XiaoZhangGui/Features/Todo/TodoView.swift",
                "try? MemoRepository(context: context).add",
                "记录未保存，请重试"
            ),
        ]

        for expectation in expectations {
            let value = try source(expectation.path)
            XCTAssertFalse(value.contains(expectation.forbidden), expectation.path)
            XCTAssertTrue(value.contains(expectation.visibleFailure), expectation.path)
            XCTAssertTrue(value.contains("Button(\"重试\")"), expectation.path)
        }
    }

    func testProductionRoutesUseStableIdentifiers() throws {
        let home = try source("XiaoZhangGui/Features/Home/HomeView.swift")
        let aiCapsule = try source("XiaoZhangGui/Features/Home/V38/V38HomeAICapsule.swift")
        let business = try source("XiaoZhangGui/Features/Performance/PerformanceView.swift")
        let profile = try source("XiaoZhangGui/Features/Profile/ProfileView.swift")

        // V3.8 重建：AI 入口生产化为 V38HomeAICapsule（v38.home.ai.* identifiers
        // 定义在组件文件中，HomeView 通过 V38HomeAICapsule 引用）。
        XCTAssertTrue(
            home.contains("V371AccessibilityID.homeAI") || home.contains("V38HomeAICapsule"),
            "Home 必须有稳定的 AI 入口"
        )
        XCTAssertTrue(
            aiCapsule.contains("v38.home.ai.expand"),
            "V38HomeAICapsule 必须定义稳定的 v38.home.ai.* identifiers"
        )
        // 2026-10-23 用户确认减法：首页「快速记一笔 / 写备忘」快捷行整行删除，
        // 原「Home 必须有快速记录入口」口径作废，改为断言被删入口不得回归；
        // QuickRecord 经深链可达性由 HomeQuickEntryAuditTests 把守。
        XCTAssertFalse(home.contains("V371AccessibilityID.homeQuickRecord"))
        XCTAssertFalse(
            home.contains("V38HomeQuickMenu") || home.contains("\"快速记一笔\""),
            "Home 不得再有已被用户确认删除的快捷记录入口"
        )
        XCTAssertTrue(business.contains("V371AccessibilityID.businessGoods"))
        XCTAssertTrue(business.contains("Label(\"商品\", systemImage: \"shippingbox\")"))
        XCTAssertTrue(business.contains("V371AccessibilityID.businessMemo"))
        XCTAssertTrue(business.contains("V371AccessibilityID.businessDailyReport"))
        XCTAssertTrue(profile.contains("V371AccessibilityID.profilePaymentCodes"))
        XCTAssertTrue(profile.contains("V371AccessibilityID.profileVoiceTest"))
    }
}
