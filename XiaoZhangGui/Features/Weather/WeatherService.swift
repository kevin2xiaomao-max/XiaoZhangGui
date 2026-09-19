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
    func fetchForecast(days: Int) async throws -> WeatherForecast
}

extension WeatherProviding {
    func fetchForecast(days: Int) async throws -> WeatherForecast {
        let current = try await fetchCurrentWeather()
        return WeatherForecast(
            city: current.city,
            days: [WeatherDayForecast(offset: 0, date: current.observedAt, minTemperature: current.temperature, maxTemperature: current.temperature, precipitationProbability: current.precipitationProbability, condition: current.condition, isStale: current.isStale)],
            fetchedAt: current.observedAt,
            isStale: current.isStale
        )
    }
}

/// P0-4：WeatherAPI.com 实现。
/// 端点：https://api.weatherapi.com/v1/forecast.json?key=...&q=...&days=1&aqi=no&alerts=no
/// 返回 current.temp_c / feelslike_c / condition.text / condition.code，
/// forecast.forecastday[0].day.maxtemp_c / mintemp_c / daily_chance_of_rain，
/// location.name。
struct WeatherAPIProvider: WeatherProviding {
    let configuration: WeatherConfiguration
    /// 允许注入 URLSession（单元测试用 stub URLProtocol 模拟 WeatherAPI 响应）
    var session: URLSession = .shared

    func fetchCurrentWeather() async throws -> WeatherSnapshot {
        guard configuration.isConfigured else { throw WeatherServiceError.notConfigured }

        var components = URLComponents(string: "https://api.weatherapi.com/v1/forecast.json")
        components?.queryItems = [
            URLQueryItem(name: "key", value: configuration.apiKey),
            URLQueryItem(name: "q", value: String(format: "%.4f,%.4f", configuration.latitude, configuration.longitude)),
            URLQueryItem(name: "days", value: "1"),
            URLQueryItem(name: "aqi", value: "no"),
            URLQueryItem(name: "alerts", value: "no"),
            URLQueryItem(name: "lang", value: "zh")
        ]
        guard let url = components?.url else { throw WeatherServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw WeatherServiceError.requestFailed
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WeatherServiceError.invalidResponse
        }

        guard let payload = try? JSONDecoder().decode(WeatherAPIResponse.self, from: data) else {
            throw WeatherServiceError.invalidResponse
        }

        let day = payload.forecast.forecastday.first?.day
        return WeatherSnapshot(
            temperature: payload.current.tempC,
            feelsLike: payload.current.feelslikeC,
            condition: payload.current.condition.text,
            conditionCode: payload.current.condition.text,
            // P1-2：GPS 定位成功时 configuration.city 传空串 → 使用 API 返回的真实城市名，
            // 不允许「天气数据是中山的、标题还写恩平」；
            // 仅定位失败走默认配置（city=恩平）时才用配置城市。
            city: configuration.city.isEmpty ? payload.location.name : configuration.city,
            precipitationProbability: day?.dailyChanceOfRain.map { Double($0) / 100.0 },
            maxTemperature: day?.maxtempC,
            minTemperature: day?.mintempC,
            observedAt: Date(),
            isStale: false
        )
    }

    func fetchForecast(days: Int) async throws -> WeatherForecast {
        guard configuration.isConfigured else { throw WeatherServiceError.notConfigured }
        var components = URLComponents(string: "https://api.weatherapi.com/v1/forecast.json")
        components?.queryItems = [
            URLQueryItem(name: "key", value: configuration.apiKey),
            URLQueryItem(name: "q", value: String(format: "%.4f,%.4f", configuration.latitude, configuration.longitude)),
            URLQueryItem(name: "days", value: String(min(max(days, 1), 3))),
            URLQueryItem(name: "aqi", value: "no"),
            URLQueryItem(name: "alerts", value: "no"),
            URLQueryItem(name: "lang", value: "zh")
        ]
        guard let url = components?.url else { throw WeatherServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw WeatherServiceError.requestFailed
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WeatherServiceError.invalidResponse
        }
        guard let payload = try? JSONDecoder().decode(WeatherAPIResponse.self, from: data) else {
            throw WeatherServiceError.invalidResponse
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let now = Date()
        let days = payload.forecast.forecastday.enumerated().compactMap { index, item -> WeatherDayForecast? in
            guard let rawDate = item.date,
                  let date = formatter.date(from: rawDate),
                  let condition = item.day.condition else { return nil }
            return WeatherDayForecast(
                offset: index,
                date: date,
                minTemperature: item.day.mintempC,
                maxTemperature: item.day.maxtempC,
                precipitationProbability: item.day.dailyChanceOfRain.map { Double($0) / 100.0 },
                condition: condition.text,
                isStale: false
            )
        }
        return WeatherForecast(city: configuration.city.isEmpty ? payload.location.name : configuration.city, days: days, fetchedAt: now, isStale: false)
    }
}

private struct WeatherAPIResponse: Decodable {
    struct Location: Decodable {
        let name: String
    }
    struct Condition: Decodable {
        let text: String
        let code: Int
    }
    struct Current: Decodable {
        let tempC: Double
        let feelslikeC: Double
        let condition: Condition

        enum CodingKeys: String, CodingKey {
            case tempC = "temp_c"
            case feelslikeC = "feelslike_c"
            case condition
        }
    }
    struct Day: Decodable {
        let condition: Condition?
        let maxtempC: Double
        let mintempC: Double
        let dailyChanceOfRain: Int?

        enum CodingKeys: String, CodingKey {
            case maxtempC = "maxtemp_c"
            case mintempC = "mintemp_c"
            case dailyChanceOfRain = "daily_chance_of_rain"
        }
    }
    struct ForecastDay: Decodable {
        let date: String?
        let day: Day
    }
    struct Forecast: Decodable {
        let forecastday: [ForecastDay]
    }
    let location: Location
    let current: Current
    let forecast: Forecast
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
    private let forecastCacheKey = "xzg.weather.forecast.v1"
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

    func forecast(days: Int = 3, forceRefresh: Bool = false) async throws -> WeatherForecast {
        let cached = loadForecastCache()
        if !forceRefresh, let cached, Date().timeIntervalSince(cached.cachedAt) < freshInterval {
            return cached.forecast
        }
        do {
            let forecast = try await provider.fetchForecast(days: min(max(days, 1), 3))
            saveForecast(forecast)
            return forecast
        } catch {
            if let cached, Date().timeIntervalSince(cached.cachedAt) < staleFallbackInterval {
                var stale = cached.forecast
                stale.isStale = true
                stale.days = stale.days.map { day in
                    var copy = day
                    copy.isStale = true
                    return copy
                }
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

    private func loadForecastCache() -> CachedForecast? {
        guard let data = defaults.data(forKey: forecastCacheKey) else { return nil }
        return try? JSONDecoder().decode(CachedForecast.self, from: data)
    }

    private func saveForecast(_ forecast: WeatherForecast) {
        guard let data = try? JSONEncoder().encode(CachedForecast(forecast: forecast, cachedAt: Date())) else { return }
        defaults.set(data, forKey: forecastCacheKey)
    }
}

private struct CachedForecast: Codable {
    let forecast: WeatherForecast
    let cachedAt: Date
}

@MainActor
@Observable
final class WeatherViewModel {
    private var service: WeatherService
    private let locationManager: LocationManager
    private(set) var state: WeatherViewState = .idle
    private(set) var snapshot: WeatherSnapshot?
    private(set) var isRefreshing = false
    /// P0-1：定位被拒绝/受限时为 true（天气继续用配置 fallback 城市请求，不阻塞）
    private(set) var isLocationDenied = false
    let isConfigured: Bool
    private var hasLoaded = false
    private let baseConfiguration: WeatherConfiguration
    private var lastUsedCoordinates: (latitude: Double, longitude: Double)?

    init(configuration: WeatherConfiguration = .current(),
         locationManager: LocationManager? = nil) {
        baseConfiguration = configuration
        isConfigured = configuration.isConfigured
        self.locationManager = locationManager ?? LocationManager()
        service = WeatherService(provider: WeatherAPIProvider(configuration: configuration))
        lastUsedCoordinates = (configuration.latitude, configuration.longitude)
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task { await requestWithLocationFallback(forceRefresh: false) }
    }

    func refresh() {
        Task { await requestWithLocationFallback(forceRefresh: true) }
    }

    /// 先尝试 CoreLocation 真实定位（4 秒超时 / 拒绝授权 fallback 恩平），
    /// 拿到新坐标后重建 provider，再发请求。失败一律 fallback 到 `baseConfiguration`。
    private func requestWithLocationFallback(forceRefresh: Bool) async {
        if let location = await locationManager.requestAuthorizationAndLocation() {
            isLocationDenied = false
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            if lastUsedCoordinates?.latitude != lat || lastUsedCoordinates?.longitude != lon {
                // P1-2：GPS 成功后城市名传空串，由 WeatherAPIProvider 采用 API 返回的
                // 真实 location.name；配置里的「恩平」只在定位失败 fallback 时才使用。
                let resolved = WeatherConfiguration(
                    apiKey: baseConfiguration.apiKey,
                    city: "",
                    latitude: lat,
                    longitude: lon
                )
                service = WeatherService(provider: WeatherAPIProvider(configuration: resolved))
                lastUsedCoordinates = (lat, lon)
            }
        } else {
            // P0-1：拿到 nil 时区分「定位未授权」与普通超时/失败
            switch locationManager.authorizationStatus {
            case .denied, .restricted:
                isLocationDenied = true
            default:
                break
            }
        }
        await request(forceRefresh: forceRefresh)
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
            // P0-1：区分网络失败 / API 请求失败，供详情页展示不同文案。
            // 已有数据时保留旧快照（state=.loaded），只在无任何数据时进入失败态。
            if snapshot == nil {
                state = .unavailable(Self.failureReason(of: error))
            } else {
                state = .loaded
            }
        }
    }

    private static func failureReason(of error: Error) -> WeatherFailureReason {
        switch error as? WeatherServiceError {
        case .requestFailed: return .network
        case .invalidURL, .invalidResponse: return .api
        default: return .unknown
        }
    }
}
