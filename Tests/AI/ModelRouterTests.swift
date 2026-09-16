import XCTest
@testable import XiaoZhangGui

final class ModelRouterTests: XCTestCase {
    private let router = FreeFirstModelRouter()

    func testIntentClassificationIsLocalZeroToken() {
        let route = router.route(task: .intentClassify, intent: .worldChat, tier: .freeFirst)
        XCTAssertTrue(route.isLocalZeroToken)
        XCTAssertEqual(route.providerID, "local")
    }

    func testToolCallGoesPrimary() {
        let route = router.route(task: .toolCall,
                                 intent: .businessAction(.recordRevenue), tier: .freeFirst)
        XCTAssertFalse(route.isLocalZeroToken)
        XCTAssertEqual(route.providerID, "primary")
    }

    func testFreeFirstChatGoesPrimaryFree() {
        let route = router.route(task: .chat, intent: .worldChat, tier: .freeFirst)
        XCTAssertEqual(route.providerID, "primary")
        XCTAssertEqual(route.tier, .freeFirst)
    }

    func testHighQualityGoesFallback() {
        let route = router.route(task: .chat, intent: .worldChat, tier: .highQuality)
        XCTAssertEqual(route.providerID, "fallback")
        XCTAssertEqual(route.tier, .highQuality)
    }

    func testBusinessAnswerDefaultPrimary() {
        let route = router.route(task: .businessAnswer,
                                 intent: .businessQuery(.delivery), tier: .auto)
        XCTAssertEqual(route.providerID, "primary")
    }
}
