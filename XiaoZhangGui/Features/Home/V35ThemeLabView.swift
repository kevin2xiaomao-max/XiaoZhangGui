#if DEBUG
import SwiftUI

/// P5.0 Theme Lab. Fixed preview data only; never connected to HomeView or a model context.
struct V35ThemeLabView: View {
    let theme: AccentTheme
    private let data = V35ThemeLabData()

    private var palette: AccentPalette { theme.palette }
    private var background: BackgroundPalette { BackgroundTheme.warmCream.palette }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                revenueHero
                overview
                importantSection
                recentSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Color(background.pageBG))
        .navigationTitle("主题实验室")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("主题设置")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("你的小掌柜")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color(palette.accent))
                Text("晚上好，掌柜")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(background.textPrimary))
                Text("今日经营概览")
                    .font(.subheadline)
                    .foregroundStyle(Color(background.textSecondary))
            }
            Spacer()
            Circle()
                .fill(Color(palette.selectedTint))
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "sparkles").foregroundStyle(Color(palette.accent)))
        }
    }

    private var revenueHero: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                Text("今日营业额")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(palette.onAccent.opacity(0.78)))
                Spacer()
                Text("经营摘要")
                    .font(.caption)
                    .foregroundStyle(Color(palette.onAccent.opacity(0.64)))
            }
            Text("¥2,680")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(palette.onAccent))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            HStack(spacing: 5) {
                Text("↑ 12.6%").foregroundStyle(Color(palette.chartAccent))
                Text("较昨日").foregroundStyle(Color(palette.onAccent.opacity(0.72)))
            }
            .font(.subheadline.weight(.semibold))
            Divider().overlay(Color(palette.onAccent.opacity(0.16)))
            HStack {
                Text("本月目标完成")
                    .foregroundStyle(Color(palette.onAccent.opacity(0.72)))
                Spacer()
                Text("68%")
                    .foregroundStyle(Color(palette.onAccent))
                    .fontWeight(.bold)
            }
            .font(.subheadline)
            GeometryReader { proxy in
                Capsule().fill(Color(palette.onAccent.opacity(0.18))).overlay(alignment: .leading) {
                    Capsule().fill(Color(palette.chartAccent)).frame(width: proxy.size.width * 0.68)
                }
            }
            .frame(height: 3)
        }
        .padding(22)
        .background(
            LinearGradient(colors: [Color(palette.heroStart), Color(palette.heroEnd)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今日营业额 2680 元，本月目标完成 68%")
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("今日概览", detail: "经营脉搏")
            HStack(spacing: 10) {
                overviewMetric("待办", value: "4", icon: "checkmark.circle")
                overviewMetric("配送", value: "2", icon: "shippingbox")
                overviewMetric("临期", value: "1", icon: "clock")
                overviewMetric("需求", value: "2", icon: "person.2")
            }
        }
    }

    private func overviewMetric(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon).font(.subheadline.weight(.semibold)).foregroundStyle(Color(palette.accent))
            Text(value).font(.title2.weight(.bold).monospacedDigit()).foregroundStyle(Color(background.textPrimary))
            Text(title).font(.caption).foregroundStyle(Color(background.textSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(palette.subtleTint), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var importantSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("现在最重要", detail: "优先处理")
            labRow(icon: "shippingbox.fill", title: "确认下午配送", detail: "幸福路 · 15:00", emphasized: true)
            labRow(icon: "checkmark.circle", title: "核对今日收款", detail: "还有 3 笔待确认")
        }
        .padding(16)
        .background(Color(background.card), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("最近记录", detail: "查看全部")
            labRow(icon: "arrow.down.left", title: "美团收款", detail: "¥680 · 今天 18:20")
            labRow(icon: "arrow.down.left", title: "现金收款", detail: "¥320 · 今天 16:45")
        }
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        HStack {
            Text(title).font(.title3.weight(.bold)).foregroundStyle(Color(background.textPrimary))
            Spacer()
            Text(detail).font(.caption.weight(.semibold)).foregroundStyle(Color(palette.accent))
        }
    }

    private func labRow(icon: String, title: String, detail: String, emphasized: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(emphasized ? Color(palette.accent) : Color(background.textSecondary))
                .frame(width: 25)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color(background.textPrimary))
                Text(detail).font(.caption).foregroundStyle(Color(background.textSecondary))
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color(background.textTertiary))
        }
        .padding(.vertical, 5)
    }
}

private struct V35ThemeLabData {
    let revenue = 2680
    let revenueChange = 12.6
    let goalProgress = 68
    let todos = 4
    let deliveries = 2
    let expiring = 1
    let customerRequests = 2
}

#Preview("V35 Theme Lab · Emerald") {
    NavigationStack { V35ThemeLabView(theme: .emerald) }
}
#endif
