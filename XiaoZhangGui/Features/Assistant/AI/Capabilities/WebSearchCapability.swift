import Foundation

/// Provider-neutral search result. A search provider never receives SwiftData
/// or a ToolExecuting handle; it only returns externally sourced material.
struct AICapabilityWebSearchHit: Sendable, Equatable, Decodable {
    let title: String
    let url: URL
    let snippet: String
}

struct AICapabilityWebSearchResponse: Sendable, Equatable {
    let answer: String?
    let hits: [AICapabilityWebSearchHit]
}

protocol AICapabilityWebSearchProvider: Sendable {
    var id: String { get }
    func search(query: String, timeout: TimeInterval) async throws -> AICapabilityWebSearchResponse
}

struct UnconfiguredWebSearchProvider: AICapabilityWebSearchProvider {
    let id = "unconfigured-search"

    func search(query: String, timeout: TimeInterval) async throws -> AICapabilityWebSearchResponse {
        throw AICapabilityError.notConfigured(.webSearch)
    }
}

/// Minimal generic JSON adapter for a configured search endpoint. It is
/// deliberately not tied to a vendor response: a provider-specific adapter
/// can map its payload into this same response before it reaches the app.
protocol AICapabilitySearchHTTPFetching: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct FoundationSearchHTTPFetcher: AICapabilitySearchHTTPFetching {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}

struct JSONWebSearchProvider: AICapabilityWebSearchProvider {
    let id: String
    private let endpoint: URL
    private let apiKey: String
    private let fetcher: any AICapabilitySearchHTTPFetching

    init(
        id: String,
        endpoint: URL,
        apiKey: String,
        fetcher: any AICapabilitySearchHTTPFetching = FoundationSearchHTTPFetcher()
    ) {
        self.id = id
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.fetcher = fetcher
    }

    func search(query: String, timeout: TimeInterval) async throws -> AICapabilityWebSearchResponse {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AICapabilityError.notConfigured(.webSearch)
        }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AICapabilityError.noResults
        }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        var items = components?.queryItems ?? []
        items.append(URLQueryItem(name: "q", value: query))
        components?.queryItems = items
        guard let url = components?.url else { throw AICapabilityError.unavailable }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await fetcher.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw AICapabilityError.networkFailure
            }
            return try Self.decode(data)
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

    static func decode(_ data: Data) throws -> AICapabilityWebSearchResponse {
        struct Envelope: Decodable {
            let answer: String?
            let results: [AICapabilityWebSearchHit]?
        }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            let hits = envelope.results ?? []
            let answer = envelope.answer?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !(answer?.isEmpty ?? true) || !hits.isEmpty else {
                throw AICapabilityError.noResults
            }
            return AICapabilityWebSearchResponse(answer: answer, hits: hits)
        } catch let error as AICapabilityError {
            throw error
        } catch {
            throw AICapabilityError.malformedResponse
        }
    }
}

struct WebSearchCapability: Sendable {
    private let provider: any AICapabilityWebSearchProvider
    private let timeout: TimeInterval

    init(
        provider: any AICapabilityWebSearchProvider = UnconfiguredWebSearchProvider(),
        timeout: TimeInterval = 15
    ) {
        self.provider = provider
        self.timeout = timeout
    }

    func execute(query: String) async throws -> AICapabilityResult {
        do {
            let response = try await provider.search(query: query, timeout: timeout)
            let answer = response.answer?.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = answer.flatMap { $0.isEmpty ? nil : $0 }
                ?? response.hits.map(\.snippet).filter { !$0.isEmpty }.joined(separator: "\n\n")
            guard !body.isEmpty || !response.hits.isEmpty else { throw AICapabilityError.noResults }
            return AICapabilityResult(
                capability: .webSearch,
                text: body.isEmpty ? "找到相关网页：" : body,
                sources: response.hits.map {
                    AICapabilitySource(id: $0.url.absoluteString, title: $0.title, url: $0.url)
                },
                provider: provider.id,
                retrievedAt: .now
            )
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
