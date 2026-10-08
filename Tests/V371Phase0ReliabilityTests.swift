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
        let business = try source("XiaoZhangGui/Features/Performance/PerformanceView.swift")
        let profile = try source("XiaoZhangGui/Features/Profile/ProfileView.swift")

        XCTAssertTrue(home.contains("V371AccessibilityID.homeAI"))
        XCTAssertTrue(home.contains("V371AccessibilityID.homeQuickRecord"))
        XCTAssertTrue(business.contains("V371AccessibilityID.businessGoods"))
        XCTAssertTrue(business.contains("V371AccessibilityID.businessMemo"))
        XCTAssertTrue(business.contains("V371AccessibilityID.businessDailyReport"))
        XCTAssertTrue(profile.contains("V371AccessibilityID.profilePaymentCodes"))
        XCTAssertTrue(profile.contains("V371AccessibilityID.profileVoiceTest"))
    }
}
