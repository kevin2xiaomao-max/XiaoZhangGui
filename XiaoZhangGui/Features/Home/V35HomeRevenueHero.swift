import SwiftUI

/// 3.6 参考首页：浅底大数字 + 昨日胶囊，月目标不再塞进同一张深色卡。
struct V35HomeRevenueHero: View {
    let summary: TodaySummary
    let monthRevenue: Double
    let monthGoal: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text("今日营业额")
                    .v32Text(.caption)
                    .foregroundStyle(V32.textTertiary)
                Text("¥" + Fmt.groupedAmount(summary.revenue))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(V32.textPrimary)
                    .contentTransition(.numericText(value: summary.revenue))
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)
                if let change = summary.changePercent {
                    Text(String(format: "较昨日 %+.1f%%", change))
                        .v32Text(.pill)
                        .foregroundStyle(V32.brand)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(V32.brandSoft))
                } else if summary.yesterdayRevenue > 0 {
                    Text("昨天 ¥" + Fmt.groupedAmount(summary.yesterdayRevenue))
                        .v32Text(.pill)
                        .foregroundStyle(V32.brand)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(V32.brandSoft))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("今日营业额 \(Fmt.money(summary.revenue))，点击查看经营数据")
    }
}
