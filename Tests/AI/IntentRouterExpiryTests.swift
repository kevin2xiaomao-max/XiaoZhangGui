import XCTest
@testable import XiaoZhangGui

// MARK: - 意图分类：临期商品 READ（V3.3 AI REAL 新增第五类 READ）

final class IntentRouterExpiryTests: XCTestCase {
    private let router = IntentRouter()

    func testExpiryQuestionsClassifiedAsExpiringGoodsQuery() {
        for q in ["最近有什么临期商品", "有什么东西快过期了吗", "有什么货到期了", "保质期还有什么要注意的"] {
            guard case .businessQuery(let kind) = router.classify(q) else {
                return XCTFail("「\(q)」应分类为经营查询")
            }
            XCTAssertEqual(kind, .expiringGoods, "「\(q)」应分类为临期商品查询")
        }
    }

    func testExpiringGoodsKindRoundTripsThroughCodable() throws {
        let args = SearchRecordsArguments(query: nil, kinds: [.expiringGoods])
        let data = try JSONEncoder.ai.encode(args)
        let decoded = try JSONDecoder.ai.decode(SearchRecordsArguments.self, from: data)
        XCTAssertEqual(decoded.kinds, [.expiringGoods])
    }

    func testUnknownKindRawValueFailsDecoding() {
        let json = Data(#"{"query":null,"kinds":["futureThing"]}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder.ai.decode(SearchRecordsArguments.self, from: json),
                             "未知查询种类必须解码失败（fail-closed）")
    }
}
