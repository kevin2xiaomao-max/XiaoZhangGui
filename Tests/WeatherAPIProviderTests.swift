import XCTest
@testable import XiaoZhangGui

/// P1-2：天气城市名
/// - GPS 成功（configuration.city 传空串）→ 必须采用 WeatherAPI 返回的真实 location.name
/// - 定位失败 fallback（configuration.city=恩平）→ 保留配置城市
/// 不允许出现「数据是中山的、标题写恩平」。
final class WeatherAPIProviderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StubWeatherURLProtocol.reset()
    }

    override func tearDown() {
        StubWeatherURLProtocol.reset()
        super.tearDown()
    }

    /// 用注入的 stub session 发请求
    private func provider(city: String, latitude: Double, longitude: Double) -> WeatherAPIProvider {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubWeatherURLProtocol.self]
        let session = URLSession(configuration: config)
        return WeatherAPIProvider(
            configuration: WeatherConfiguration(
                apiKey: "test-key", city: city, latitude: latitude, longitude: longitude
            ),
            session: session
        )
    }

    func testGPSSuccessUsesAPILocationNameEvenWhenDefaultCityIsEnping() async throws {
        // 用户在中山：默认配置城市仍是「恩平」，但 GPS 成功后 city 传空串
        StubWeatherURLProtocol.stubJSON = Self.forecastJSON(city: "中山市", temp: 25.1)

        let snapshot = try await provider(city: "", latitude: 22.517, longitude: 113.393)
            .fetchCurrentWeather()

        XCTAssertEqual(snapshot.city, "中山市")
        XCTAssertEqual(snapshot.temperature, 25.1, accuracy: 0.001)
        XCTAssertEqual(snapshot.maxTemperature ?? 0, 28, accuracy: 0.001)
        XCTAssertEqual(snapshot.minTemperature ?? 0, 22, accuracy: 0.001)
        XCTAssertEqual(snapshot.condition, "多云")
    }

    func testFallbackConfigurationKeepsConfiguredCity() async throws {
        // 定位未授权：走恩平配置，即使 API 返回了别的名字也以配置城市为准
        StubWeatherURLProtocol.stubJSON = Self.forecastJSON(city: "东莞市", temp: 30)

        let snapshot = try await provider(city: "恩平", latitude: 22.183, longitude: 112.305)
            .fetchCurrentWeather()

        XCTAssertEqual(snapshot.city, "恩平")
        XCTAssertEqual(snapshot.temperature, 30, accuracy: 0.001)
    }

    func testRealCityNameFromMaomingAlsoResolved() async throws {
        // 另一真实城市，确保不是硬编码
        StubWeatherURLProtocol.stubJSON = Self.forecastJSON(city: "茂名市", temp: 27)
        let snapshot = try await provider(city: "", latitude: 21.663, longitude: 110.925)
            .fetchCurrentWeather()
        XCTAssertEqual(snapshot.city, "茂名市")
    }

    func testForecastDecodesThreeDaysIncludingDayCondition() async throws {
        StubWeatherURLProtocol.stubJSON = Self.threeDayForecastJSON()

        let forecast = try await provider(city: "恩平", latitude: 22.183, longitude: 112.305)
            .fetchForecast(days: 3)

        XCTAssertEqual(forecast.days.count, 3)
        XCTAssertEqual(forecast.days.map(\.condition), ["晴", "多云", "小雨"])
        XCTAssertEqual(forecast.days.map(\.minTemperature), [20, 21, 22])
        XCTAssertEqual(forecast.days.map(\.maxTemperature), [28, 29, 30])
    }

    // MARK: - Stub JSON

    private static func forecastJSON(city: String, temp: Double) -> Data {
        """
        {
          "location": { "name": "\(city)" },
          "current": {
            "temp_c": \(temp),
            "feelslike_c": \(temp + 1),
            "condition": { "text": "多云", "code": 1003 }
          },
          "forecast": {
            "forecastday": [
              { "day": { "maxtemp_c": 28, "mintemp_c": 22, "daily_chance_of_rain": 40 } }
            ]
          }
        }
        """.data(using: .utf8)!
    }

    private static func threeDayForecastJSON() -> Data {
        """
        {
          "location": { "name": "恩平" },
          "current": {
            "temp_c": 24,
            "feelslike_c": 25,
            "condition": { "text": "晴", "code": 1000 }
          },
          "forecast": {
            "forecastday": [
              { "date": "2026-09-19", "day": { "maxtemp_c": 28, "mintemp_c": 20, "daily_chance_of_rain": 10, "condition": { "text": "晴", "code": 1000 } } },
              { "date": "2026-09-20", "day": { "maxtemp_c": 29, "mintemp_c": 21, "daily_chance_of_rain": 40, "condition": { "text": "多云", "code": 1003 } } },
              { "date": "2026-09-21", "day": { "maxtemp_c": 30, "mintemp_c": 22, "daily_chance_of_rain": 70, "condition": { "text": "小雨", "code": 1180 } } }
            ]
          }
        }
        """.data(using: .utf8)!
    }
}

/// 截获 WeatherAPI 请求并返回固定 JSON（不访问真实网络、不依赖 Key）
final class StubWeatherURLProtocol: URLProtocol {
    static var stubJSON: Data?

    static func reset() {
        stubJSON = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data = Self.stubJSON {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
