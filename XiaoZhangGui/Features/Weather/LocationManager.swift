import CoreLocation
import Observation

/// P0-4：定位管理。
///
/// 设计要点：
/// - `requestAuthorizationAndLocation()` 是幂等的；5 分钟内已拿到坐标直接复用，
///   不会每次刷新天气都重新触发系统定位。
/// - 任何环节失败（拒绝授权、超时、`didFail`）都返回 `nil`，由 `WeatherViewModel`
///   fallback 到 `WeatherConfiguration.current` 的恩平坐标。
/// - 使用 `requestWhenInUseAuthorization()`（仅前台使用），避免请求 Always。
/// - 4 秒超时保护，避免首页加载被定位卡死。
@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var lastLocation: CLLocation?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var locationFetchTimer: Timer?
    private let cacheInterval: TimeInterval = 5 * 60
    private let requestTimeout: TimeInterval = 4

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = manager.authorizationStatus
    }

    /// 请求授权并获取一次定位。
    /// - 已在 5 分钟内拿到坐标：直接复用。
    /// - 已被拒绝/受限：返回 `nil`。
    /// - 未授权：触发授权弹窗，授权成功后立即 `requestLocation()`；授权被拒则返回 `nil`。
    /// - 任何分支最多等待 `requestTimeout` 秒。
    func requestAuthorizationAndLocation() async -> CLLocation? {
        if let last = lastLocation, Date().timeIntervalSince(last.timestamp) < cacheInterval {
            return last
        }

        switch authorizationStatus {
        case .denied, .restricted:
            return nil
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }

        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
            locationFetchTimer = Timer.scheduledTimer(withTimeInterval: requestTimeout, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.complete(with: nil)
                }
            }
        }
    }

    private func complete(with location: CLLocation?) {
        locationFetchTimer?.invalidate()
        locationFetchTimer = nil
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(returning: location)
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                self.complete(with: nil)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let location = locations.last {
                self.lastLocation = location
                self.complete(with: location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.complete(with: nil)
        }
    }
}
