import Foundation
import Observation

/// 天气配置入口。API Key 只从构建后的 Info.plist 或开发环境变量读取，绝不写入源码。
/// 支持的 Info.plist Key：XZGWeatherAPIKey、XZGWeatherCity、XZGWeatherLatitude、XZGWeatherLongitude。
struct WeatherConfiguration: Sendable {
    let apiKey: String
    let city: String
    let latitude: Double
    let longitude: Double

    var isConfigured: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    static func current(bundle: Bundle = .main, environment: [String: String] = ProcessInfo.processInfo.environment) -> WeatherConfiguration {
        func value(_ infoKey: String, environmentKey: String) -> String? {
            if let environmentValue = environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !environmentValue.isEmpty {
                return environmentValue
            }
            guard let bundleValue = bundle.object(forInfoDictionaryKey: infoKey) as? String else { return nil }
            let trimmed = bundleValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return WeatherConfiguration(
            apiKey: value("XZGWeatherAPIKey", environmentKey: "XZG_WEATHER_API_KEY") ?? "",
            city: value("XZGWeatherCity", environmentKey: "XZG_WEATHER_CITY") ?? "恩平",
            latitude: Double(value("XZGWeatherLatitude", environmentKey: "XZG_WEATHER_LATITUDE") ?? "") ?? 22.183,
            longitude: Double(value("XZGWeatherLongitude", environmentKey: "XZG_WEATHER_LONGITUDE") ?? "") ?? 112.305
        )
    }
}

protocol WeatherProviding: Sendable {
    func fetchCurrentWeather() async throws -> WeatherSnapshot
}

/// 默认第三方实现。替换 provider 即可接入和风天气等服务，Home 无需改动。
struct OpenWeatherProvider: WeatherProviding {
    let configuration: WeatherConfiguration

    func fetchCurrentWeather() async throws -> WeatherSnapshot {
        guard configuration.isConfigured else { throw WeatherServiceError.notConfigured }

        var components = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(configuration.latitude)),
            URLQueryItem(name: "lon", value: String(configuration.longitude)),
            URLQueryItem(name: "appid", value: configuration.apiKey),
            URLQueryItem(name: "units", value: "metric"),
            URLQueryItem(name: "lang", value: "zh_cn")
        ]
        guard let url = components?.url else { throw WeatherServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw WeatherServiceError.requestFailed
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WeatherServiceError.invalidResponse
        }

        guard let payload = try? JSONDecoder().decode(OpenWeatherResponse.self, from: data),
              let weather = payload.weather.first else {
            throw WeatherServiceError.invalidResponse
        }

        return WeatherSnapshot(
            temperature: payload.main.temp,
            feelsLike: payload.main.feelsLike,
            condition: weather.description,
            conditionCode: weather.main,
            city: configuration.city.isEmpty ? payload.name : configuration.city,
            precipitationProbability: nil,
            observedAt: Date(),
            isStale: false
        )
    }
}

private struct OpenWeatherResponse: Decodable {
    struct Main: Decodable {
        let temp: Double
        let feelsLike: Double

        enum CodingKeys: String, CodingKey {
            case temp
            case feelsLike = "feels_like"
        }
    }

    struct Condition: Decodable {
        let main: String
        let description: String
    }

    let main: Main
    let weather: [Condition]
    let name: String
}

private struct CachedWeather: Codable {
    let snapshot: WeatherSnapshot
    let cachedAt: Date
}

/// 统一处理缓存、超时后的陈旧缓存降级和 provider 替换。
actor WeatherService {
    private let provider: any WeatherProviding
    private let defaults: UserDefaults
    private let cacheKey = "xzg.weather.current.v1"
    private let freshInterval: TimeInterval = 30 * 60
    private let staleFallbackInterval: TimeInterval = 6 * 60 * 60

    init(provider: any WeatherProviding, defaults: UserDefaults = .standard) {
        self.provider = provider
        self.defaults = defaults
    }

    func currentWeather(forceRefresh: Bool = false) async throws -> WeatherSnapshot {
        let cached = loadCache()
        if !forceRefresh,
           let cached,
           Date().timeIntervalSince(cached.cachedAt) < freshInterval {
            return cached.snapshot
        }

        do {
            let snapshot = try await provider.fetchCurrentWeather()
            saveCache(snapshot)
            return snapshot
        } catch {
            if let cached,
               Date().timeIntervalSince(cached.cachedAt) < staleFallbackInterval {
                var stale = cached.snapshot
                stale.isStale = true
                return stale
            }
            throw error
        }
    }

    private func loadCache() -> CachedWeather? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(CachedWeather.self, from: data)
    }

    private func saveCache(_ snapshot: WeatherSnapshot) {
        guard let data = try? JSONEncoder().encode(CachedWeather(snapshot: snapshot, cachedAt: Date())) else { return }
        defaults.set(data, forKey: cacheKey)
    }
}

@MainActor
@Observable
final class WeatherViewModel {
    private let service: WeatherService
    private(set) var state: WeatherViewState = .idle
    private(set) var snapshot: WeatherSnapshot?
    private(set) var isRefreshing = false
    let isConfigured: Bool
    private var hasLoaded = false

    init(configuration: WeatherConfiguration = .current()) {
        isConfigured = configuration.isConfigured
        service = WeatherService(provider: OpenWeatherProvider(configuration: configuration))
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task { await request(forceRefresh: false) }
    }

    func refresh() {
        Task { await request(forceRefresh: true) }
    }

    private func request(forceRefresh: Bool) async {
        if snapshot == nil { state = .loading }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            snapshot = try await service.currentWeather(forceRefresh: forceRefresh)
            state = .loaded
        } catch WeatherServiceError.notConfigured {
            snapshot = nil
            state = .notConfigured
        } catch {
            state = snapshot == nil ? .unavailable : .loaded
        }
    }
}
