import XCTest
@testable import XiaoZhangGui

final class ExternalCapabilityTests: XCTestCase {
    func testRouterKeepsBusinessInputOnDeterministicPath() {
        let router = AICapabilityRouter()
        XCTAssertNil(router.request(for: "今天营业额680元"))
        XCTAssertNil(router.request(for: "百威多少钱"))
        XCTAssertEqual(router.request(for: "https://example.com/article")?.capability, .urlReading)
        XCTAssertEqual(router.request(for: "网上查一下苹果今天的新闻")?.capability, .webSearch)
        XCTAssertEqual(router.request(for: "这个产品现在多少钱")?.capability, .webSearch)
    }

    func testURLReadingReturnsStructuredTextAndSource() async throws {
        let fetcher = StubURLFetcher(html: "<html><head><title>测试页面</title></head><body><h1>标题</h1><p>正文内容</p></body></html>")
        let capability = URLReadingCapability(fetcher: fetcher)
        let result = try await capability.execute(urlString: "https://example.com/article")

        XCTAssertEqual(result.capability, .urlReading)
        XCTAssertTrue(result.text.contains("测试页面"))
        XCTAssertTrue(result.text.contains("正文内容"))
        XCTAssertEqual(result.sources.count, 1)
        XCTAssertEqual(result.sources.first?.url.absoluteString, "https://example.com/article")
    }

    func testURLReadingRejectsNonHTTPInput() async {
        let capability = URLReadingCapability(fetcher: StubURLFetcher(html: "ignored"))
        do {
            _ = try await capability.execute(urlString: "not-a-url")
            XCTFail("invalid URL should fail closed")
        } catch let error as AICapabilityError {
            XCTAssertEqual(error, .invalidURL)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testRegistryMakesConfigurationBoundaryExplicit() {
        let descriptors = Dictionary(uniqueKeysWithValues: AICapabilityRegistry.foundation.descriptors.map { ($0.capability, $0) })
        XCTAssertEqual(descriptors[.urlReading]?.availability, .live)
        XCTAssertEqual(descriptors[.webSearch]?.availability, .notConfigured)
        XCTAssertEqual(descriptors[.vision]?.availability, .foundationOnly)
        XCTAssertEqual(descriptors[.documentUnderstanding]?.availability, .foundationOnly)
    }

    func testWebSearchReturnsSourcesAndMetadata() async throws {
        let provider = ScriptedSearchProvider(
            response: WebSearchResponse(
                answer: "苹果今天发布了新消息。",
                results: [WebSearchResult(
                    title: "新闻来源",
                    content: "来源摘要",
                    sourceURL: URL(string: "https://example.com/news")!,
                    provider: "scripted-search"
                )],
                provider: "scripted-search"
            )
        )
        let result = try await WebSearchCapability(provider: provider).execute(query: "苹果今天新闻")

        XCTAssertEqual(result.capability, .webSearch)
        XCTAssertEqual(result.provider, "scripted-search")
        XCTAssertFalse(result.retrievedAt.timeIntervalSinceNow.isNaN)
        XCTAssertTrue(result.userFacingText.contains("[新闻来源](https://example.com/news)"))
    }

    @MainActor
    func testAgentSearchPathDoesNotCreateActionCard() async {
        let provider = ScriptedSearchProvider(
            response: WebSearchResponse(
                answer: "实时回答",
                results: [WebSearchResult(
                    title: "来源",
                    content: "摘要",
                    sourceURL: URL(string: "https://example.com/source")!,
                    provider: "scripted-search"
                )],
                provider: "scripted-search"
            )
        )
        let live = AITestFactory.live(
            provider: ScriptedAIProvider([.success(.text("不应调用 General Assistant"))]),
            webSearchCapability: WebSearchCapability(provider: provider)
        )

        let turn = await live.agent.send("网上查一下苹果今天新闻")
        XCTAssertNil(turn.proposal, "只读搜索不得产生 ActionCard")
        XCTAssertTrue(turn.assistantMessage?.content.contains("来源") == true)
    }

    func testWebSearchProviderMissingFailsClosed() async {
        do {
            _ = try await WebSearchCapability().execute(query: "最新新闻")
            XCTFail("未配置搜索 Provider 不得伪造结果")
        } catch let error as AICapabilityError {
            XCTAssertEqual(error, .notConfigured(.webSearch))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testSearchJSONParserRejectsMalformedAndEmptyResponses() {
        XCTAssertThrowsError(try JSONWebSearchProvider.decode(Data("{}".utf8))) { error in
            XCTAssertEqual(error as? AICapabilityError, .noResults)
        }
        XCTAssertThrowsError(try JSONWebSearchProvider.decode(Data("not-json".utf8))) { error in
            XCTAssertEqual(error as? AICapabilityError, .malformedResponse)
        }
    }

    func testConfiguredSearchMapsHTTPFailureWithoutExposingBody() async {
        let provider = JSONWebSearchProvider(
            id: "configured-search",
            endpoint: URL(string: "https://search.example.test/api")!,
            apiKey: "test-only-key",
            fetcher: StubSearchHTTPFetcher(statusCode: 503, body: Data("secret provider body".utf8))
        )
        do {
            _ = try await provider.search(query: "实时信息", timeout: 1)
            XCTFail("HTTP failure should fail closed")
        } catch let error as AICapabilityError {
            XCTAssertEqual(error, .networkFailure)
            XCTAssertFalse(error.localizedDescription.contains("secret"))
        } catch { XCTFail("unexpected error: \(error)") }
    }

    func testNormalizedSearchResponsePreservesProviderAndSourceMetadata() throws {
        let data = Data(#"{"answer":"answer","results":[{"title":"source","content":"snippet","sourceURL":"https://example.com/a"}]}"#.utf8)
        let response = try JSONWebSearchProvider.decode(data, provider: "domestic-proxy")

        XCTAssertEqual(response.provider, "domestic-proxy")
        XCTAssertEqual(response.results.first?.provider, "domestic-proxy")
        XCTAssertEqual(response.results.first?.title, "source")
        XCTAssertEqual(response.results.first?.content, "snippet")
        XCTAssertEqual(response.results.first?.sourceURL.absoluteString, "https://example.com/a")
    }

    func testFreeFirstIgnoresProvidersWithoutExplicitUserEligibility() async {
        let paid = ScriptedSearchProvider(response: Self.searchResponse(provider: "not-approved"))
        let provider = FreeFirstWebSearchProvider(candidates: [
            FreeFirstSearchProviderCandidate(provider: paid, userConfirmedFreeEligible: false)
        ])

        do {
            _ = try await provider.search(query: "latest", timeout: 1)
            XCTFail("未明确允许的 Provider 不得被自动调用")
        } catch let error as AICapabilityError {
            XCTAssertEqual(error, .notConfigured(.webSearch))
        } catch { XCTFail("unexpected error: \(error)") }
    }

    func testFreeFirstFailsOverOnlyAcrossApprovedProviders() async throws {
        let failed = ScriptedSearchProvider(error: .networkFailure, id: "approved-failed")
        let working = ScriptedSearchProvider(
            response: Self.searchResponse(provider: "approved-working"),
            id: "approved-working"
        )
        let provider = FreeFirstWebSearchProvider(candidates: [
            FreeFirstSearchProviderCandidate(provider: failed, userConfirmedFreeEligible: true),
            FreeFirstSearchProviderCandidate(provider: working, userConfirmedFreeEligible: true)
        ])

        let response = try await provider.search(query: "latest", timeout: 1)
        XCTAssertEqual(response.provider, "approved-working")
    }

    func testVisionAndDocumentSlicesValidateInputAndFailClosed() async {
        do {
            _ = try await VisionCapability().execute(imageData: Data(), mimeType: "image/png")
            XCTFail("空图片必须被拒绝")
        } catch let error as AICapabilityError {
            XCTAssertEqual(error, .invalidImage)
        } catch { XCTFail("unexpected error: \(error)") }

        do {
            _ = try await DocumentCapability().execute(data: Data("x".utf8), fileName: "note.txt", mimeType: "text/plain")
            XCTFail("未配置文档 Provider 不得伪造结果")
        } catch let error as AICapabilityError {
            XCTAssertEqual(error, .notConfigured(.documentUnderstanding))
        } catch { XCTFail("unexpected error: \(error)") }
    }

    func testCapabilityCancellationIsPreserved() async {
        do {
            _ = try await WebSearchCapability(provider: ScriptedSearchProvider(cancellation: true))
                .execute(query: "实时信息")
            XCTFail("取消必须保留为 cancelled")
        } catch let error as AICapabilityError {
            XCTAssertEqual(error, .cancelled)
        } catch { XCTFail("unexpected error: \(error)") }
    }

    private static func searchResponse(provider: String) -> WebSearchResponse {
        WebSearchResponse(
            answer: "result",
            results: [WebSearchResult(
                title: "source",
                content: "content",
                sourceURL: URL(string: "https://example.com")!,
                provider: provider
            )],
            provider: provider
        )
    }
}

private struct StubURLFetcher: AICapabilityURLFetching {
    let html: String

    func data(from url: URL, timeout: TimeInterval) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html"])!
        return (Data(html.utf8), response)
    }
}

private struct ScriptedSearchProvider: WebSearchProvider {
    let id: String
    let response: WebSearchResponse?
    let error: AICapabilityError?
    let cancellation: Bool

    init(response: WebSearchResponse, id: String = "scripted-search") {
        self.id = id
        self.response = response
        self.error = nil
        self.cancellation = false
    }

    init(cancellation: Bool) {
        self.id = "scripted-search"
        self.response = nil
        self.error = nil
        self.cancellation = cancellation
    }

    init(error: AICapabilityError, id: String = "scripted-search") {
        self.id = id
        self.response = nil
        self.error = error
        self.cancellation = false
    }

    func search(query: String, timeout: TimeInterval) async throws -> WebSearchResponse {
        if cancellation { throw CancellationError() }
        if let error { throw error }
        return response!
    }
}

private struct StubSearchHTTPFetcher: WebSearchHTTPFetching {
    let statusCode: Int
    let body: Data

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil
        )!
        return (body, response)
    }
}
