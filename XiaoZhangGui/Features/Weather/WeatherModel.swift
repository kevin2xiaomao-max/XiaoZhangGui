import Foundation

/// 经过标准化的天气数据。UI 和经营助手只依赖此模型，不依赖具体天气供应商。
struct WeatherSnapshot: Codable, Equatable, Sendable {
    let temperature: Double
    let feelsLike: Double?
    let condition: String
    let conditionCode: String
    let city: String
    let precipitationProbability: Double?
    let maxTemperature: Double?
    let minTemperature: Double?
    let observedAt: Date
    var isStale: Bool

    var roundedTemperature: Int { Int(temperature.rounded()) }
    var roundedFeelsLike: Int? { feelsLike.map { Int($0.rounded()) } }
    var roundedMax: Int? { maxTemperature.map { Int($0.rounded()) } }
    var roundedMin: Int? { minTemperature.map { Int($0.rounded()) } }

    var isRaining: Bool {
        let value = conditionCode.lowercased()
        return value.contains("rain") || value.contains("drizzle") || value.contains("thunderstorm")
    }

    var symbolName: String {
        let value = conditionCode.lowercased()
        if value.contains("thunderstorm") { return "cloud.bolt.rain.fill" }
        if value.contains("rain") || value.contains("drizzle") { return "cloud.rain.fill" }
        if value.contains("snow") { return "cloud.snow.fill" }
        if value.contains("mist") || value.contains("fog") || value.contains("haze") { return "cloud.fog.fill" }
        if value.contains("clear") { return "sun.max.fill" }
        if value.contains("cloud") { return "cloud.fill" }
        return "cloud.sun.fill"
    }
}

enum WeatherViewState: Equatable {
    case idle
    case loading
    case loaded
    case notConfigured
    /// 拉取失败（snapshot 为 nil）。附带失败原因供 UI 区分网络 / API 错误。
    case unavailable(WeatherFailureReason)
}

/// P0-1 真机状态区分：网络失败 / API 请求失败 / 其它
enum WeatherFailureReason: Equatable {
    /// URLSession 层失败（无网 / 超时 / DNS）
    case network
    /// 服务端返回非 2xx 或响应无法解析（多为 Key 无效 / 配额）
    case api
    case unknown
}

enum WeatherServiceError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "天气服务尚未配置"
        case .invalidURL, .invalidResponse, .requestFailed: return "天气暂时无法获取"
        }
    }
}

