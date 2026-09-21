import Foundation

protocol AICapabilityURLFetching: Sendable {
    func data(from url: URL, timeout: TimeInterval) async throws -> (Data, URLResponse)
}

struct FoundationURLFetcher: AICapabilityURLFetching {
    func data(from url: URL, timeout: TimeInterval) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("你的小掌柜/3.6", forHTTPHeaderField: "User-Agent")
        return try await URLSession.shared.data(for: request)
    }
}

struct URLReadingCapability: Sendable {
    private let fetcher: any AICapabilityURLFetching
    private let timeout: TimeInterval

    init(fetcher: any AICapabilityURLFetching = FoundationURLFetcher(), timeout: TimeInterval = 15) {
        self.fetcher = fetcher
        self.timeout = timeout
    }

    func execute(urlString: String) async throws -> AICapabilityResult {
        guard let url = URL(string: urlString),
              ["http", "https"].contains(url.scheme?.lowercased()) else {
            throw AICapabilityError.invalidURL
        }
        do {
            let (data, response) = try await fetcher.data(from: url, timeout: timeout)
            guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
                throw AICapabilityError.unavailable
            }
            let titleAndText = HTMLTextExtractor.extract(data: data)
            guard !titleAndText.text.isEmpty else { throw AICapabilityError.unavailable }
            let excerpt = String(titleAndText.text.prefix(1800))
            let title = titleAndText.title ?? url.host ?? url.absoluteString
            return AICapabilityResult(
                capability: .urlReading,
                text: "已读取网页「\(title)」\n\n\(excerpt)",
                sources: [AICapabilitySource(id: url.absoluteString, title: title, url: url)]
            )
        } catch is CancellationError {
            throw AICapabilityError.cancelled
        } catch let error as AICapabilityError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw AICapabilityError.timeout
        } catch {
            throw AICapabilityError.unavailable
        }
    }
}

private struct HTMLTextExtractor {
    let title: String?
    let text: String

    static func extract(data: Data) -> HTMLTextExtractor {
        let html = String(decoding: data, as: UTF8.self)
        let title = capture(#"(?is)<title[^>]*>\s*(.*?)\s*</title>"#, in: html).map(clean)
        let withoutScripts = html.replacingOccurrences(of: #"(?is)<(script|style|noscript)[^>]*>.*?</\1>"#, with: " ", options: .regularExpression)
        let plain = withoutScripts.replacingOccurrences(of: #"(?is)<[^>]+>"#, with: " ", options: .regularExpression)
        let decoded = clean(plain)
        return HTMLTextExtractor(title: title, text: decoded)
    }

    private static func capture(_ pattern: String, in value: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: value) else { return nil }
        return String(value[range])
    }

    private static func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"&nbsp;|&#160;"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"&amp;"#, with: "&", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
