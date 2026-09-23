import SwiftUI

// MARK: - 天气详情 Sheet（V371：HeroMetric 蓝色能量面 + 分组列表；刷新/定位逻辑原样）
//
// P1-4：WeatherPill 已删除（未被任何页面使用的旧 V21 主题链路组件）。
// 天气入口统一使用 HomeView.weatherButton。

struct WeatherDetailSheet: View {
    let model: WeatherViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: V371.Space.section) {
                    if let weather = model.snapshot {
                        heroCard(weather)
                        detailCard(weather)
                    } else {
                        emptyCard
                    }
                }
                .padding(.horizontal, V371.Space.page)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .v371Canvas()
            .navigationTitle("当前天气")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    refreshButton
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var refreshButton: some View {
        Button {
            Haptic.light()
            model.refresh()
        } label: {
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .tint(V371.Colors.blue)
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(V371.Colors.textSecondary)
            }
        }
        .disabled(model.isRefreshing || !model.isConfigured)
        .accessibilityLabel("刷新天气")
    }

    private func heroCard(_ weather: WeatherSnapshot) -> some View {
        HeroMetric(title: weather.city, value: "\(weather.roundedTemperature)°") {
            HStack(spacing: 8) {
                Image(systemName: weather.symbolName)
                    .font(.system(size: 20, weight: .medium))
                    .accessibilityHidden(true)
                Text(weather.condition)
                    .font(V371.Type.heroTitle)
            }
            .foregroundStyle(V371.Colors.heroText)
        }
        .accessibilityLabel("\(weather.city)当前\(weather.roundedTemperature)度，\(weather.condition)")
    }

    private func detailCard(_ weather: WeatherSnapshot) -> some View {
        GroupSurface {
            if let maxV = weather.roundedMax, let minV = weather.roundedMin {
                detailRow("今日最高 / 最低", value: "\(maxV)° / \(minV)°")
            }
            if let feelsLike = weather.roundedFeelsLike {
                if weather.roundedMax != nil { V371Divider(leading: 0) }
                detailRow("体感", value: "\(feelsLike)°")
            }
            if let probability = weather.precipitationProbability {
                if weather.roundedMax != nil || weather.roundedFeelsLike != nil { V371Divider(leading: 0) }
                detailRow("降雨概率", value: "\(Int((probability * 100).rounded()))%")
            }
            if weather.isStale {
                if weather.roundedMax != nil || weather.roundedFeelsLike != nil || weather.precipitationProbability != nil { V371Divider(leading: 0) }
                detailRow("状态", value: "离线缓存")
            }
            if model.isLocationDenied {
                V371Divider(leading: 0)
                detailRow("定位", value: "未授权 · 使用默认城市")
            }
            if weather.roundedMax != nil || weather.roundedFeelsLike != nil || weather.precipitationProbability != nil || weather.isStale || model.isLocationDenied {
                V371Divider(leading: 0)
            }
            detailRow("数据来源", value: "WeatherAPI.com")
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(V371.Type.rowSubtitle)
                .foregroundStyle(V371.Colors.textTertiary)
            Spacer()
            Text(value)
                .font(V371.Type.rowTitle)
                .foregroundStyle(V371.Colors.textPrimary)
        }
        .padding(.horizontal, V371.Space.rowPadding)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label)：\(value)")
    }

    private var emptyCard: some View {
        EmptyState(
            icon: emptySymbol,
            title: emptyTitle,
            message: model.isLocationDenied ? "定位未授权，已使用默认城市" : nil,
            buttonTitle: model.isConfigured ? "重试" : nil,
            buttonAction: { model.refresh() }
        )
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
