import XCTest
@testable import XiaoZhangGui

final class AI20GroundingTests: XCTestCase {
    private var pack: GroundingPack {
        GroundingPack(
            todayRevenue: 1200, yesterdayRevenue: 1000,
            sevenDayRevenue: (0..<7).map { DailyRevenueSummary(date: Date().addingTimeInterval(Double($0) * 86_400), amount: Double(700 + $0 * 100)) },
            unfinishedTodoTitles: ["补货"], deliveryPendingCount: 1, deliveryDeliveringCount: 1,
            expiryTitles: ["牛奶"],
            goods: [GoodsSummary(name: "百威啤酒", purchasePrice: 4, salePrice: 6, stock: 2, minStock: 5)],
            localSummary: "今日经营平稳"
        )
    }

    func testBusinessInsightRoutes() {
        let router = IntentRouter()
        XCTAssertEqual(router.classify("今天生意怎么样"), .businessInsight(.overview))
        XCTAssertEqual(router.classify("今天比昨天怎么样"), .businessInsight(.comparison))
        XCTAssertEqual(router.classify("最近7天营业额怎么样"), .businessInsight(.sevenDayTrend))
        XCTAssertEqual(router.classify("库存有什么要注意的"), .businessInsight(.inventory))
        XCTAssertEqual(router.classify("结合我店里的数据给点建议"), .businessInsight(.advice))
    }

    @MainActor
    func testLocalInsightsUseNoProviderAndNoActionCard() async {
        for text in ["今天生意怎么样", "今天比昨天怎么样", "最近7天营业额怎么样", "库存有什么要注意的"] {
            let provider = CapturingAIProvider()
            let context = ScriptedBusinessContextProvider(.empty, pack: pack)
            let harness = AITestFactory.live(provider: provider, contextProvider: context)
            let result = await harness.agent.send(text)
            XCTAssertNotNil(result.assistantMessage)
            XCTAssertNil(result.proposal)
            let count = await provider.requestCount()
            XCTAssertEqual(count, 0)
        }
    }

    @MainActor
    func testAdviceSendsOnlyCappedRedactedGrounding() async throws {
        let provider = CapturingAIProvider()
        let context = ScriptedBusinessContextProvider(.empty, pack: pack)
        let harness = AITestFactory.live(provider: provider, contextProvider: context)
        let result = await harness.agent.send("结合我店里的数据给点建议")
        XCTAssertEqual(result.assistantMessage?.content, "测试回复")
        let captured = await provider.firstRequest()
        let request = try XCTUnwrap(captured)
        let data = try XCTUnwrap(request.context.json)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertLessThanOrEqual(try XCTUnwrap(object["grounding"]).count, 420)
        XCTAssertNil(result.proposal)
    }

    @MainActor
    func testKnowledgeQuestionCarriesNoGrounding() async throws {
        let provider = CapturingAIProvider()
        let context = ScriptedBusinessContextProvider(.empty, pack: pack)
        let harness = AITestFactory.live(provider: provider, contextProvider: context)
        _ = await harness.agent.send("什么是毛利率")
        let captured = await provider.firstRequest()
        let request = try XCTUnwrap(captured)
        XCTAssertNil(request.context.json)
    }

    func testGroundingRedactorRemovesSensitiveDataAndCapsGoods() throws {
        let sensitive = GroundingPack(
            todayRevenue: 680, yesterdayRevenue: nil, sevenDayRevenue: [],
            unfinishedTodoTitles: ["给13800138000送到幸福路302室，备注放门口"],
            deliveryPendingCount: 1, deliveryDeliveringCount: 0, expiryTitles: [],
            goods: (0..<8).map { GoodsSummary(name: "商品\($0)", purchasePrice: 1, salePrice: 2, stock: 3, minStock: 1) },
            localSummary: nil)
        let data = try XCTUnwrap(ContextRedactor().sanitize(sensitive).json)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("13800138000"))
        XCTAssertFalse(text.contains("302室"))
        XCTAssertFalse(text.contains("商品5"))
        XCTAssertFalse(text.contains("商品7"))
    }

    @MainActor
    func testNoDataDoesNotCallProviderOrInventAdvice() async {
        let provider = CapturingAIProvider()
        let harness = AITestFactory.live(provider: provider, contextProvider: ScriptedBusinessContextProvider(.empty))
        let result = await harness.agent.send("结合我店里的数据给点建议")
        XCTAssertTrue(result.assistantMessage?.content.contains("没有足够") == true)
        let count = await provider.requestCount()
        XCTAssertEqual(count, 0)
    }
}
