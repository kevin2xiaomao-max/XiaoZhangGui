import Foundation

enum WeatherSkill {
    static func answer(for query: String, forecast: WeatherForecast, now: Date = Date()) -> String {
        let offset = query.contains("后天") ? 2 : query.contains("明天") ? 1 : 0
        guard let day = forecast.days.first(where: { $0.offset == offset }) else {
            return "暂时拿不到这段时间的天气预报，请稍后再试。"
        }
        let dayText: String
        switch offset {
        case 1: dayText = "明天"
        case 2: dayText = "后天"
        default: dayText = "今天"
        }
        let range = "\(number(day.minTemperature))°~\(number(day.maxTemperature))°"
        var reply = "\(forecast.city)\(dayText)：\(day.condition)，\(range)"
        if let probability = day.precipitationProbability {
            reply += "，降雨概率 \(Int((probability * 100).rounded()))%"
        }
        if forecast.isStale || day.isStale {
            reply += "。数据可能不是最新"
        } else if day.precipitationProbability ?? 0 >= 0.6 {
            reply += "。有配送的话，出发前留意路况"
        } else {
            reply += "。"
        }
        return reply
    }

    private static func number(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}
