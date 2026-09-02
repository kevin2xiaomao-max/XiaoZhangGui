import SwiftUI

struct WeatherPill: View {
    let model: WeatherViewModel
    let palette: AppThemePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                weatherIcon
                VStack(alignment: .leading, spacing: 1) {
                    if let weather = model.snapshot {
                        Text("\(weather.roundedTemperature)° · \(weather.city)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(V21.textPrimary)
                        Text(weather.isStale ? "缓存天气" : weather.condition)
                            .font(AppTypography.caption)
                            .foregroundColor(V21.textTertiary)
                    } else {
                        Text(statusTitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(V21.textSecondary)
                    }
                }
                .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 40)
            .background(.thinMaterial, in: Capsule())
            .background(palette.accent.opacity(0.06), in: Capsule())
            .overlay(Capsule().stroke(V21.divider.opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var weatherIcon: some View {
        if model.state == .loading && model.snapshot == nil {
            ProgressView().controlSize(.small).tint(palette.accent)
        } else {
            Image(systemName: model.snapshot?.symbolName ?? fallbackSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(palette.accent)
        }
    }

    private var fallbackSymbol: String {
        switch model.state {
        case .notConfigured: return "cloud.slash"
        case .unavailable: return "wifi.exclamationmark"
        default: return "cloud.sun"
        }
    }

    private var statusTitle: String {
        switch model.state {
        case .loading: return "获取天气"
        case .notConfigured: return "天气未配置"
        case .unavailable: return "天气暂不可用"
        case .idle, .loaded: return "天气"
        }
    }

    private var accessibilityLabel: String {
        if let weather = model.snapshot {
            return "\(weather.city)，\(weather.condition)，\(weather.roundedTemperature)度"
        }
        return statusTitle
    }
}

struct WeatherDetailSheet: View {
    let model: WeatherViewModel
    let palette: AppThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("当前天气")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(V21.textPrimary)
                Spacer()
                Button {
                    model.refresh()
                } label: {
                    if model.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .foregroundColor(palette.accent)
                .frame(width: 44, height: 44)
                .disabled(model.isRefreshing || !model.isConfigured)
                .accessibilityLabel("刷新天气")
            }

            if let weather = model.snapshot {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: weather.symbolName)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundColor(palette.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(weather.roundedTemperature)°")
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .foregroundColor(V21.textPrimary)
                        Text("\(weather.condition) · \(weather.city)")
                            .font(AppTypography.body)
                            .foregroundColor(V21.textSecondary)
                    }
                }
                HStack(spacing: 18) {
                    if let feelsLike = weather.roundedFeelsLike {
                        Label("体感 \(feelsLike)°", systemImage: "thermometer.medium")
                    }
                    if let probability = weather.precipitationProbability {
                        Label("降雨 \(Int((probability * 100).rounded()))%", systemImage: "drop.fill")
                    }
                    if weather.isStale {
                        Label("离线缓存", systemImage: "clock.arrow.circlepath")
                    }
                }
                .font(AppTypography.caption)
                .foregroundColor(V21.textTertiary)
            } else {
                ContentUnavailableView(
                    model.state == .notConfigured ? "天气未配置" : "天气暂不可用",
                    systemImage: model.state == .notConfigured ? "cloud.slash" : "wifi.exclamationmark",
                    description: Text(model.state == .notConfigured ? "配置天气服务后将显示恩平实时天气" : "请检查网络后稍后重试")
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .background(V21.background)
    }
}

