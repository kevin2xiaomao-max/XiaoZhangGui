import XCTest
@testable import XiaoZhangGui

final class I1SkillsTests: XCTestCase {
    func testTomorrowWeatherIsWeatherQueryAndNeverCreatesActionCard() {
        let intent = IntentRouter().classify("明天恩平天气怎么样")
        guard case .weatherQuery = intent else {
            return XCTFail("明天天气必须优先路由为 weatherQuery")
        }
    }

    func testWeatherSkillUsesForecastAndMarksStaleData() {
        let forecast = WeatherForecast(
            city: "恩平",
            days: [
                WeatherDayForecast(offset: 0, date: Date(), minTemperature: 24, maxTemperature: 31, precipitationProbability: 0.2, condition: "多云", isStale: true),
                WeatherDayForecast(offset: 1, date: Date().addingTimeInterval(86_400), minTemperature: 23, maxTemperature: 29, precipitationProbability: 0.7, condition: "小雨", isStale: true)
            ],
            fetchedAt: Date(),
            isStale: true
        )

        let reply = WeatherSkill.answer(for: "明天恩平天气怎么样", forecast: forecast)
        XCTAssertTrue(reply.contains("恩平"))
        XCTAssertTrue(reply.contains("23°~29°"))
        XCTAssertTrue(reply.contains("降雨概率 70%"))
        XCTAssertTrue(reply.contains("数据可能不是最新"))
    }

    func testWeatherServiceWithoutKeyFailsClosed() async {
        let configuration = WeatherConfiguration(apiKey: "", city: "恩平", latitude: 22.183, longitude: 112.305)
        let defaults = UserDefaults(suiteName: "I1Weather-\(UUID().uuidString)")!
        let service = WeatherService(provider: WeatherAPIProvider(configuration: configuration), defaults: defaults)
        do {
            _ = try await service.forecast(days: 3)
            XCTFail("无 Key 不应伪造天气")
        } catch WeatherServiceError.notConfigured {
            // expected
        } catch {
            XCTFail("应返回 notConfigured，而不是其它错误")
        }
    }

    func testGoodsLookupReturnsLocalPriceAndMarginWithoutActionCard() {
        let goods = [GoodsSummary(name: "百威", purchasePrice: 8, salePrice: 12, stock: 9, minStock: 3)]
        let result = GoodsLookupSkill.lookup("百威多少钱一箱", in: goods)
        XCTAssertEqual(result, .reply("百威：售价 ¥12，进价 ¥8，毛利 ¥4，毛利率 33.3%。"))
    }

    func testGoodsLookupRequiresChoiceForMultipleMatches() {
        let goods = [
            GoodsSummary(name: "百威啤酒", purchasePrice: 8, salePrice: 12, stock: 9, minStock: 3),
            GoodsSummary(name: "百威纯生", purchasePrice: 10, salePrice: 15, stock: 4, minStock: 3)
        ]
        let result = GoodsLookupSkill.lookup("百威多少钱", in: goods)
        guard case .clarify(let names) = result else { return XCTFail("同名商品必须澄清") }
        XCTAssertEqual(names, ["百威啤酒", "百威纯生"])
    }

    func testGoodsLookupDoesNotInventPurchasePrice() {
        let goods = [GoodsSummary(name: "百威", purchasePrice: 0, salePrice: 12, stock: 9, minStock: 3)]
        let result = GoodsLookupSkill.lookup("百威进价多少", in: goods)
        XCTAssertEqual(result, .reply("百威：暂未填写进价。"))
    }

    func testKnowledgeQuestionIsWorldChat() {
        if case .worldChat = IntentRouter().classify("什么是毛利率") { } else {
            XCTFail("知识问答必须进入 worldChat")
        }
    }

    func testBusinessAdviceIsWorldChatAndHasNoActionCardIntent() {
        if case .worldChat = IntentRouter().classify("便利店怎么提高客单价") { } else {
            XCTFail("经营建议必须进入 worldChat")
        }
    }

    @MainActor
    func testMetaReplyDoesNotCallProvider() async {
        XCTAssertNotNil(MetaReply.reply(for: "那我还要AI干嘛"))
        XCTAssertNotNil(MetaReply.reply(for: "你能做什么"))
        XCTAssertNotNil(MetaReply.reply(for: "小掌柜有什么用"))
        let provider = ScriptedAIProvider(id: "counted", [])
        let harness = AITestFactory.live(provider: provider)
        let result = await harness.agent.send("那我还要AI干嘛")
        XCTAssertNil(result.proposal)
        let calls = await provider.callCount
        XCTAssertEqual(calls, 0)
    }

    func testTomorrowGoodsQuestionIsGoodsReadNotTodo() {
        guard case .goodsQuery = IntentRouter().classify("明天有没有百威") else {
            return XCTFail("明天有没有百威必须进入 Goods READ")
        }
    }

    func testOriginalV33CreateIntentsRemainActionCards() {
        let router = IntentRouter()
        guard case .businessAction(.recordRevenue) = router.classify("今天美团680") else { return XCTFail("营业额路由回归") }
        guard case .businessAction(.createTodo) = router.classify("提醒我明天下午3点进货") else { return XCTFail("待办路由回归") }
        guard case .businessAction(.createMemo) = router.classify("记一下供应商周五来") else { return XCTFail("备忘路由回归") }
        guard case .businessAction(.createDelivery) = router.classify("今晚8点给302送水") else { return XCTFail("配送路由回归") }
    }
}
