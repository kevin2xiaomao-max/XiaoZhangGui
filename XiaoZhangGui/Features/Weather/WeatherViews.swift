import SwiftUI

struct WeatherPill: View {
    let model: WeatherViewModel
    let palette: AppThemePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                weatherIcon
                if let weather = model.snapshot {
                    Text("\(weather.roundedTemperature)°")
                        .font(.subheadline.monospacedDigit().weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 36, minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var weatherIcon: some View {
        if model.state == .loading && model.snapshot == nil {
            ProgressView().controlSize(.small)
        } else {
            Image(systemName: model.snapshot?.symbolName ?? fallbackSymbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var fallbackSymbol: String {
        switch model.state {
        case .notConfigured: return "cloud.sun"
        case .unavailable: return "wifi.exclamationmark"
        default: return "cloud.sun"
        }
    }

    private var accessibilityLabel: String {
        if let weather = model.snapshot {
            return "\(weather.city)，\(weather.condition)，\(weather.roundedTemperature)度"
        }
        switch model.state {
        case .notConfigured: return "天气"
        case .unavailable: return "天气暂不可用"
        case .loading: return "正在获取天气"
        default: return "天气"
        }
    }
}

struct WeatherDetailSheet: View {
    let model: WeatherViewModel
    let palette: AppThemePalette

    var body: some View {
        NavigationStack {
            List {
                if let weather = model.snapshot {
                    Section {
                        HStack(alignment: .center, spacing: 16) {
                            Image(systemName: weather.symbolName)
                                .font(.system(size: 34, weight: .medium))
                                .foregroundStyle(V21.brandGreen)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(weather.roundedTemperature)°")
                                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("\(weather.condition) · \(weather.city)")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section {
                        if let feelsLike = weather.roundedFeelsLike {
                            LabeledContent("体感", value: "\(feelsLike)°")
                        }
                        if let probability = weather.precipitationProbability {
                            LabeledContent("降雨", value: "\(Int((probability * 100).rounded()))%")
                        }
                        if weather.isStale {
                            LabeledContent("状态", value: "离线缓存")
                        }
                    }
                } else {
                    Section {
                        AppEmptyState(
                            title: model.state == .notConfigured ? "未配置天气服务" : "天气暂不可用",
                            systemImage: model.state == .notConfigured ? "cloud.sun" : "wifi.exclamationmark",
                            actionTitle: model.isConfigured ? "重试" : nil
                        ) {
                            model.refresh()
                        }
                    }
                }
            }
            .navigationTitle("当前天气")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.refresh()
                    } label: {
                        if model.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(model.isRefreshing || !model.isConfigured)
                    .accessibilityLabel("刷新天气")
                }
            }
        }
    }
}
