import SwiftUI

// P1-4：WeatherPill 已删除（未被任何页面使用的旧 V21 主题链路组件）。
// 天气入口统一使用 HomeView.weatherButton（V32 tokens）。

struct WeatherDetailSheet: View {
    let model: WeatherViewModel
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
        V32FieldGroup {
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
        V32FieldGroup {
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
                if model.isLocationDenied {
                    divider
                    detailRow("定位", value: "未授权 · 使用默认城市")
                }
                if weather.roundedMax != nil || weather.roundedFeelsLike != nil || weather.precipitationProbability != nil || weather.isStale || model.isLocationDenied {
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
        V32FieldGroup {
            VStack(spacing: 14) {
                V32EmptyState(
                    systemName: emptySymbol,
                    title: emptyTitle,
                    message: model.isLocationDenied ? "定位未授权，已使用默认城市" : nil
                )
                if model.isConfigured {
                    V32PrimaryButton(title: "重试", systemName: "arrow.clockwise") { model.refresh() }
                        .padding(.horizontal, V32Layout.pageMargin)
                }
            }
        }
    }

    /// P0-1：真机状态区分 —— 未配置 / 定位未授权 / 网络失败 / API 请求失败
    private var emptySymbol: String {
        switch model.state {
        case .notConfigured: return "cloud.sun"
        case .unavailable(.network): return "wifi.exclamationmark"
        case .unavailable(.api): return "exclamationmark.icloud"
        default: return "wifi.exclamationmark"
        }
    }

    private var emptyTitle: String {
        switch model.state {
        case .notConfigured: return "未配置天气服务"
        case .unavailable(.network): return "网络连接失败，请检查网络后重试"
        case .unavailable(.api): return "天气服务请求失败，请稍后重试"
        default: return "天气暂不可用"
        }
    }
}
