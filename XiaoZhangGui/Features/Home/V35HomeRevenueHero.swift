import SwiftUI

struct V35HomeRevenueHero: View {
    let summary: TodaySummary
    let monthRevenue: Double
    let monthGoal: Double
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double { monthGoal > 0 ? min(max(monthRevenue / monthGoal, 0), 1) : 0 }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日营业额").font(.subheadline.weight(.medium)).foregroundStyle(V32.textOnHeroSecondary)
                        Text("¥" + Fmt.groupedAmount(summary.revenue)).font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.56).foregroundStyle(V32.textOnHero).contentTransition(.numericText(value: summary.revenue))
                        if let change = summary.changePercent { Label(String(format: "%+.1f%% 较昨日", change), systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right").font(.caption.weight(.semibold)).foregroundStyle(V32.brandOnHero) }
                    }
                    Spacer(minLength: 12)
                    if summary.trend.contains(where: { $0.value > 0 }) { HomeSparkline(points: summary.trend, lineColor: ThemeStore.shared.accentPalette.chartAccent).frame(width: 92, height: 26).padding(.top, 10) }
                }
                Rectangle().fill(V32.dividerOnHero.opacity(0.7)).frame(height: 1)
                HStack(spacing: 18) {
                    metric("本月", Fmt.money(monthRevenue)); metric("目标", Fmt.money(monthGoal)); metric("完成", "\(Int((progress * 100).rounded()))%")
                }
                GeometryReader { proxy in
                    Capsule().fill(V32.textOnHero.opacity(0.16)).overlay(alignment: .leading) { Capsule().fill(ThemeStore.shared.accentPalette.secondaryAccent).frame(width: proxy.size.width * progress) }
                }.frame(height: 3)
            }.padding(.horizontal, 22).padding(.vertical, 15).frame(maxWidth: .infinity, alignment: .leading).background(LinearGradient(colors: [ThemeStore.shared.accentPalette.heroStart, ThemeStore.shared.accentPalette.heroEnd], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }.buttonStyle(.plain).accessibilityLabel("今日营业额 \(Fmt.money(summary.revenue))，点击查看经营数据")
    }

    private func metric(_ title: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 3) { Text(title).font(.caption).foregroundStyle(V32.textOnHeroSecondary); Text(value).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(V32.textOnHero) } }
}
