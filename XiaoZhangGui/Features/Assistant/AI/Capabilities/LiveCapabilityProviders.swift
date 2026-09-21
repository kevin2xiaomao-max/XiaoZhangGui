import Foundation
import PDFKit

/// Tavily's response is normalized into the provider-neutral search model.
struct TavilyWebSearchProvider: WebSearchProvider {
    let id = "tavily"
    let apiKey: String
    let endpoint: URL
    private let fetcher: any WebSearchHTTPFetching

    init(
        apiKey: String,
        endpoint: URL = URL(string: "https://api.tavily.com/search")!,
        fetcher: any WebSearchHTTPFetching = FoundationWebSearchHTTPFetcher()
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.fetcher = fetcher
    }

    func search(query: String, timeout: TimeInterval) async throws -> WebSearchResponse {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AICapabilityError.notConfigured(.webSearch)
        }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AICapabilityError.noResults
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "api_key": apiKey,
            "query": query,
            "search_depth": "basic",
            "include_answer": true,
            "max_results": 5
        ])

        do {
            let (data, response) = try await fetcher.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw AICapabilityError.networkFailure
            }
            struct Payload: Decodable {
                struct Result: Decodable { let title: String; let url: URL; let content: String }
                let answer: String?
                let results: [Result]?
            }
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            let retrievedAt = Date.now
            let results = (payload.results ?? []).map {
                WebSearchResult(
                    title: $0.title,
                    content: $0.content,
                    sourceURL: $0.url,
                    provider: id,
                    retrievedAt: retrievedAt
                )
            }
            let answer = payload.answer?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !(answer?.isEmpty ?? true) || !results.isEmpty else { throw AICapabilityError.noResults }
            return WebSearchResponse(
                answer: answer,
                results: results,
                provider: id,
                retrievedAt: retrievedAt
            )
        } catch is CancellationError {
            throw AICapabilityError.cancelled
        } catch let error as AICapabilityError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw AICapabilityError.timeout
        } catch is DecodingError {
            throw AICapabilityError.malformedResponse
        } catch {
            throw AICapabilityError.networkFailure
        }
    }
}

/// The only production composition point aware of concrete search adapters.
/// Capability Router and AgentCore remain vendor-blind.
enum WebSearchProviderFactory {
    static func makeCapability(settings: AISettings) -> WebSearchCapability {
        switch settings.searchProviderSelection {
        case .disabled:
            return WebSearchCapability()
        case .automaticFreeFirst:
            return WebSearchCapability(provider: FreeFirstWebSearchProvider(candidates: candidates(settings)))
        case .tavily:
            guard let provider = tavily(settings) else { return WebSearchCapability() }
            return WebSearchCapability(provider: provider)
        case .customJSON:
            guard let provider = customJSON(settings) else { return WebSearchCapability() }
            return WebSearchCapability(provider: provider)
        }
    }

    private static func candidates(_ settings: AISettings) -> [FreeFirstSearchProviderCandidate] {
        var result: [FreeFirstSearchProviderCandidate] = []
        if let provider = tavily(settings) {
            result.append(FreeFirstSearchProviderCandidate(
                provider: provider,
                userConfirmedFreeEligible: settings.tavilySearchFreeFirstEnabled
            ))
        }
        if let provider = customJSON(settings) {
            result.append(FreeFirstSearchProviderCandidate(
                provider: provider,
                userConfirmedFreeEligible: settings.customSearchFreeFirstEnabled
            ))
        }
        return result
    }

    private static func tavily(_ settings: AISettings) -> (any WebSearchProvider)? {
        guard settings.isTavilySearchConfigured,
              let endpoint = URL(string: settings.tavilySearchBaseURL) else { return nil }
        return TavilyWebSearchProvider(
            apiKey: settings.tavilySearchAPIKey,
            endpoint: endpoint
        )
    }

    private static func customJSON(_ settings: AISettings) -> (any WebSearchProvider)? {
        guard settings.isCustomSearchConfigured,
              let endpoint = URL(string: settings.customSearchBaseURL) else { return nil }
        return JSONWebSearchProvider(
            id: "custom-json-search",
            endpoint: endpoint,
            apiKey: settings.customSearchAPIKey
        )
    }
}

struct OpenAICompatibleVisionProvider: AICapabilityVisionProvider {
    let id: String
    let endpoint: URL
    let apiKey: String
    let model: String

    func analyze(_ input: AICapabilityImageInput, timeout: TimeInterval) async throws -> String {
        let content: [[String: Any]] = [
            ["type": "text", "text": input.prompt],
            ["type": "image_url", "image_url": [
                "url": "data:\(input.mimeType);base64,\(input.data.base64EncodedString())"
            ]]
        ]
        return try await OpenAICompatibleMultimodalRequest(
            endpoint: endpoint, apiKey: apiKey, model: model, capability: .vision
        ).complete(content: content, timeout: timeout)
    }
}

struct OpenAICompatibleDocumentProvider: AICapabilityDocumentProvider {
    let id: String
    let endpoint: URL
    let apiKey: String
    let model: String

    func understand(_ input: AICapabilityDocumentInput, timeout: TimeInterval) async throws -> String {
        let text = try LocalDocumentTextExtractor.extract(
            data: input.data, fileName: input.fileName, mimeType: input.mimeType
        )
        let prompt = "\(input.prompt)\n\n文件名：\(input.fileName)\n\n文件内容：\n\(text)"
        return try await OpenAICompatibleMultimodalRequest(
            endpoint: endpoint, apiKey: apiKey, model: model, capability: .documentUnderstanding
        ).complete(content: [["type": "text", "text": prompt]], timeout: timeout)
    }
}

private struct OpenAICompatibleMultimodalRequest: Sendable {
    let endpoint: URL
    let apiKey: String
    let model: String
    let capability: AICapability

    func complete(content: [[String: Any]], timeout: TimeInterval) async throws -> String {
        guard !apiKey.isEmpty, !model.isEmpty else { throw AICapabilityError.notConfigured(capability) }
        var request = URLRequest(url: endpoint.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "messages": [["role": "user", "content": content]],
            "temperature": 0.2
        ])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw AICapabilityError.networkFailure
            }
            struct Payload: Decodable {
                struct Choice: Decodable { struct Message: Decodable { let content: String? }; let message: Message }
                let choices: [Choice]
            }
            guard let text = try JSONDecoder().decode(Payload.self, from: data).choices.first?.message.content,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AICapabilityError.malformedResponse
            }
            return text
        } catch is CancellationError {
            throw AICapabilityError.cancelled
        } catch let error as AICapabilityError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw AICapabilityError.timeout
        } catch {
            throw AICapabilityError.networkFailure
        }
    }
}

enum LocalDocumentTextExtractor {
    static func extract(data: Data, fileName: String, mimeType: String) throws -> String {
        let lower = fileName.lowercased()
        if lower.hasSuffix(".pdf") || mimeType == "application/pdf" {
            guard let document = PDFDocument(data: data), let text = document.string else {
                throw AICapabilityError.invalidDocument
            }
            return text
        }
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw AICapabilityError.invalidDocument
        }
        return text
    }
}
