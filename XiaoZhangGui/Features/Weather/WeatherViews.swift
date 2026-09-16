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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let weather = model.snapshot {
                    heroCard(weather)
                    detailCard(weather)
                } else {
                    emptyCard
                }
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 14)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32Sheet([.medium])
    }

    private var header: some View {
        ZStack {
            Text("当前天气").v32Text(.headline).foregroundStyle(V32.textPrimary)
            HStack {
                Button("关闭") { dismiss() }
                    .v32Text(.body)
                    .foregroundStyle(V32.textTertiary)
                Spacer()
                Button {
                    model.refresh()
                } label: {
                    if model.isRefreshing {
                        ProgressView().controlSize(.small).tint(V32.brand)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(V32.textSecondary)
                    }
                }
                .disabled(model.isRefreshing || !model.isConfigured)
                .accessibilityLabel("刷新天气")
            }
        }
    }

    private func heroCard(_ weather: WeatherSnapshot) -> some View {
        V32HeroCard {
            HStack(spacing: 16) {
                Image(systemName: weather.symbolName)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(V32.brandOnHero)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(weather.roundedTemperature)°")
                        .font(V32Font.heroMoney)
                        .foregroundStyle(V32.textOnHero)
                    Text("\(weather.condition) · \(weather.city)")
                        .v32Text(.body)
                        .foregroundStyle(V32.textOnHeroSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func detailCard(_ weather: WeatherSnapshot) -> some View {
        V32Card {
            VStack(spacing: 0) {
                if let maxV = weather.roundedMax, let minV = weather.roundedMin {
                    detailRow("今日最高 / 最低", value: "\(maxV)° / \(minV)°")
                }
                if let feelsLike = weather.roundedFeelsLike {
                    if weather.roundedMax != nil { divider }
                    detailRow("体感", value: "\(feelsLike)°")
                }
                if let probability = weather.precipitationProbability {
                    if weather.roundedMax != nil || weather.roundedFeelsLike != nil { divider }
                    detailRow("降雨概率", value: "\(Int((probability * 100).rounded()))%")
                }
                if weather.isStale {
                    if weather.roundedMax != nil || weather.roundedFeelsLike != nil || weather.precipitationProbability != nil { divider }
                    detailRow("状态", value: "离线缓存")
                }
                if weather.roundedMax != nil || weather.roundedFeelsLike != nil || weather.precipitationProbability != nil || weather.isStale {
                    divider
                }
                detailRow("数据来源", value: "WeatherAPI.com")
            }
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).v32Text(.subhead).foregroundStyle(V32.textTertiary)
            Spacer()
            Text(value).v32Text(.body).foregroundStyle(V32.textPrimary)
        }
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle().fill(V32.divider).frame(height: 1)
    }

    private var emptyCard: some View {
        V32Card {
            VStack(spacing: 14) {
                V32EmptyState(
                    systemName: model.state == .notConfigured ? "cloud.sun" : "wifi.exclamationmark",
                    title: model.state == .notConfigured ? "未配置天气服务" : "天气暂不可用"
                )
                if model.isConfigured {
                    V32PrimaryButton(title: "重试", systemName: "arrow.clockwise") { model.refresh() }
                        .padding(.horizontal, V32Layout.pageMargin)
                }
            }
        }
    }
}
