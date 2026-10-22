import Charts
import SwiftUI

/// V3.8 重建 · 经营页收入趋势柱状图（真实数据，Swift Charts）。
///
/// 动效（Worker C 规格 §4）：数据更新时柱高从旧值插值到新值
/// （contentChange 时序）；Reduce Motion 时直接终态。
/// 坐标轴稳定：Y 轴隐藏，量程取"nice ceiling"（1/2/5×10ⁿ），
/// 小幅数据变化不改变量程，柱高变化不引起坐标轴跳动。
/// 数值全部来自既有模型 `PerformanceTrend` 的 TrendPoint，不做二次计算。
struct V38TrendBarChart: View {
    let points: [TrendPoint]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasValues: Bool {
        points.contains { $0.value > 0 }
    }

    /// Y 轴量程上限：向上取到 1/2/5 × 10ⁿ，保证量程对小幅变化稳定。
    var domainMax: Double {
        let maxValue = points.map(\.value).max() ?? 0
        guard maxValue > 0 else { return 100 }
        let magnitude = pow(10, floor(log10(maxValue)))
        let scaled = maxValue / magnitude
        let nice: Double = scaled <= 1 ? 1 : (scaled <= 2 ? 2 : (scaled <= 5 ? 5 : 10))
        return nice * magnitude
    }

    var body: some View {
        if hasValues {
            Chart(points) { point in
                BarMark(
                    x: .value("日期", point.label),
                    y: .value("营业额", point.value)
                )
                .foregroundStyle(V38PerformanceStyle.accent)
                .cornerRadius(3)
            }
            .chartYScale(domain: 0...domainMax)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 120)
            // 数据变化时柱高插值过渡；Reduce Motion 下 animation 为 nil（直接终态）。
            .animation(
                V38MotionTokens.animation(for: .contentChange, reduceMotion: reduceMotion),
                value: points.map(\.value)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("收入趋势图")
            .accessibilityValue(accessibilitySummary)
        } else {
            Text("本期暂无收入数据")
                .font(V371.Typography.rowSubtitle)
                .foregroundStyle(V371.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 120, alignment: .center)
                .accessibilityLabel("本期暂无收入数据")
        }
    }

    private var accessibilitySummary: String {
        let total = points.reduce(0) { $0 + $1.value }
        return "共 \(points.count) 天，合计 \(Fmt.money(total))"
    }
}
