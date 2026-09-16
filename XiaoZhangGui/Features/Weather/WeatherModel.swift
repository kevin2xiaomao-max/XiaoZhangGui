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
    case unavailable
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

