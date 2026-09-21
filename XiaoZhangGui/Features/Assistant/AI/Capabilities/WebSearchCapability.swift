import Foundation

/// Provider-neutral search item. Vendor adapters normalize their payload into
/// this model before it reaches Capability Router / AgentCore.
struct WebSearchResult: Sendable, Equatable {
    let title: String
    let content: String
    let sourceURL: URL
    let provider: String
    let retrievedAt: Date

    init(
        title: String,
        content: String,
        sourceURL: URL,
        provider: String,
        retrievedAt: Date = .now
    ) {
        self.title = title
        self.content = content
        self.sourceURL = sourceURL
        self.provider = provider
        self.retrievedAt = retrievedAt
    }
}

struct WebSearchResponse: Sendable, Equatable {
    let answer: String?
    let results: [WebSearchResult]
    let provider: String
    let retrievedAt: Date

    init(
        answer: String?,
        results: [WebSearchResult],
        provider: String,
        retrievedAt: Date = .now
    ) {
        self.answer = answer
        self.results = results
        self.provider = provider
        self.retrievedAt = retrievedAt
    }
}

/// The only provider dependency seen by WebSearchCapability. Tavily, Bailian,
/// domestic search APIs and user proxies are adapters behind this protocol.
protocol WebSearchProvider: Sendable {
    var id: String { get }
    func search(query: String, timeout: TimeInterval) async throws -> WebSearchResponse
}

struct UnconfiguredWebSearchProvider: WebSearchProvider {
    let id = "unconfigured-search"

    func search(query: String, timeout: TimeInterval) async throws -> WebSearchResponse {
        throw AICapabilityError.notConfigured(.webSearch)
    }
}

protocol WebSearchHTTPFetching: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct FoundationWebSearchHTTPFetcher: WebSearchHTTPFetching {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}

/// Normalized JSON proxy adapter. A self-hosted or domestic provider proxy can
/// expose this stable contract without leaking vendor details into the Agent:
/// { "answer": "...", "results": [{"title","content","sourceURL"}] }
struct JSONWebSearchProvider: WebSearchProvider {
    let id: String
    private let endpoint: URL
    private let apiKey: String
    private let fetcher: any WebSearchHTTPFetching

    init(
        id: String,
        endpoint: URL,
        apiKey: String,
        fetcher: any WebSearchHTTPFetching = FoundationWebSearchHTTPFetcher()
    ) {
        self.id = id
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.fetcher = fetcher
    }

    func search(query: String, timeout: TimeInterval) async throws -> WebSearchResponse {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AICapabilityError.notConfigured(.webSearch)
        }
        guard !trimmed.isEmpty else { throw AICapabilityError.noResults }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": trimmed])

        do {
            let (data, response) = try await fetcher.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw AICapabilityError.networkFailure
            }
            return try Self.decode(data, provider: id)
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

    static func decode(_ data: Data, provider: String = "json-search") throws -> WebSearchResponse {
        struct Envelope: Decodable {
            struct Item: Decodable {
                let title: String
                let content: String
                let sourceURL: URL
            }
            let answer: String?
            let results: [Item]?
        }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            let answer = envelope.answer?.trimmingCharacters(in: .whitespacesAndNewlines)
            let retrievedAt = Date.now
            let results = (envelope.results ?? []).map {
                WebSearchResult(
                    title: $0.title,
                    content: $0.content,
                    sourceURL: $0.sourceURL,
                    provider: provider,
                    retrievedAt: retrievedAt
                )
            }
            guard !(answer?.isEmpty ?? true) || !results.isEmpty else {
                throw AICapabilityError.noResults
            }
            return WebSearchResponse(
                answer: answer,
                results: results,
                provider: provider,
                retrievedAt: retrievedAt
            )
        } catch let error as AICapabilityError {
            throw error
        } catch {
            throw AICapabilityError.malformedResponse
        }
    }
}

struct FreeFirstSearchProviderCandidate: Sendable {
    let provider: any WebSearchProvider
    /// Explicit user opt-in. The app never assumes a vendor's current pricing.
    let userConfirmedFreeEligible: Bool
}

/// Automatic search only sees providers the user explicitly marked eligible
/// for free-first use. It may fail over between those providers, but never to
/// an unapproved or potentially paid provider.
struct FreeFirstWebSearchProvider: WebSearchProvider {
    let id = "automatic-free-first"
    private let providers: [any WebSearchProvider]

    init(candidates: [FreeFirstSearchProviderCandidate]) {
        providers = candidates.compactMap { candidate in
            candidate.userConfirmedFreeEligible ? candidate.provider : nil
        }
    }

    func search(query: String, timeout: TimeInterval) async throws -> WebSearchResponse {
        guard !providers.isEmpty else { throw AICapabilityError.notConfigured(.webSearch) }
        var lastRecoverableError: AICapabilityError = .unavailable
        for provider in providers {
            do {
                return try await provider.search(query: query, timeout: timeout)
            } catch is CancellationError {
                throw AICapabilityError.cancelled
            } catch let error as AICapabilityError {
                if error == .cancelled { throw error }
                lastRecoverableError = error
            } catch {
                lastRecoverableError = .networkFailure
            }
        }
        throw lastRecoverableError
    }
}

struct WebSearchCapability: Sendable {
    private let provider: any WebSearchProvider
    private let timeout: TimeInterval

    init(
        provider: any WebSearchProvider = UnconfiguredWebSearchProvider(),
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
                ?? response.results.map(\.content).filter { !$0.isEmpty }.joined(separator: "\n\n")
            guard !body.isEmpty || !response.results.isEmpty else { throw AICapabilityError.noResults }
            return AICapabilityResult(
                capability: .webSearch,
                text: body.isEmpty ? "找到相关网页：" : body,
                sources: response.results.map {
                    AICapabilitySource(id: $0.sourceURL.absoluteString, title: $0.title, url: $0.sourceURL)
                },
                provider: response.provider,
                retrievedAt: response.retrievedAt
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
