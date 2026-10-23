import Charts
import SwiftUI

/// X 轴标签策略（V3.8.1 纠偏 P0-3，纯逻辑、可单测）。
///
/// 真机问题：月视图 30 个数据点的日期标签全部渲染，在窄屏上严重重叠。
/// 口径：**只抽稀轴标签，绝不动数据点** —— 柱子一天不少，统计口径不变。
/// 点数 ≤ 上限时全部显示（周/日视图 7 个日期完整保留）；
/// 超过上限时等距抽稀且必含首尾（月视图 30 点 → ≤6 个关键日期）。
enum V38AxisLabelPolicy {
    /// 任意周期下 X 轴最多显示的标签数（月视图上限）。
    static let maxAxisLabels = 6

    /// 返回应显示轴标签的数据点下标（升序、去重、必含首尾）。
    static func labeledIndices(pointCount: Int, maxLabels: Int = maxAxisLabels) -> [Int] {
        guard pointCount > 0, maxLabels > 0 else { return [] }
        guard pointCount > maxLabels else { return Array(0..<pointCount) }
        guard maxLabels > 1 else { return [0] }
        let step = Double(pointCount - 1) / Double(maxLabels - 1)
        var indices: [Int] = []
        for i in 0..<maxLabels {
            let index = Int((Double(i) * step).rounded())
            if indices.last != index { indices.append(index) }
        }
        return indices
    }
}

/// V3.8 重建 · 经营页收入趋势柱状图（真实数据，Swift Charts）。
///
/// 动效（Worker C 规格 §4）：数据更新时柱高从旧值插值到新值
/// （contentChange 时序）；Reduce Motion 时直接终态。
/// 坐标轴稳定：Y 轴隐藏，量程取"nice ceiling"（1/2/5×10ⁿ），
/// 小幅数据变化不改变量程，柱高变化不引起坐标轴跳动。
/// 数值全部来自既有模型 `PerformanceTrend` 的 TrendPoint，不做二次计算。
///
/// V3.8.1 纠偏：
/// - P0-3：X 轴标签按 `V38AxisLabelPolicy` 抽稀（只动标签呈现，数据点全保留）。
/// - P1-7：`chartXSelection` 原生选中 —— 点按/拖动选中某日后，其余柱淡化、
///   显示参考线，图表上方读数行给出该日日期与真实金额（同一模型数据）。
struct V38TrendBarChart: View {
    let points: [TrendPoint]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedLabel: String?

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

    /// 实际渲染的 X 轴标签（P0-3 抽稀后）；数据点本身不受影响。
    var axisLabelValues: [String] {
        V38AxisLabelPolicy.labeledIndices(pointCount: points.count).map { points[$0].label }
    }

    /// 按标签查找真实数据点（选中读数与单测共用同一查找口径）。
    func point(forLabel label: String?) -> TrendPoint? {
        guard let label else { return nil }
        return points.first { $0.label == label }
    }

    private var selectedPoint: TrendPoint? {
        point(forLabel: selectedLabel)
    }

    var body: some View {
        if hasValues {
            VStack(alignment: .leading, spacing: 6) {
                selectionReadout
                chart
            }
            // 读数行与 Chart 均为独立 AX 元素：容器只做分组（含外层
            // `v38.performance.chart` 标识），不遮蔽子元素 identifier
            // （R3 实证：容器 identifier 默认语义会吞子元素）。
            .accessibilityElement(children: .contain)
        } else {
            Text("本期暂无收入数据")
                .font(V371.Typography.rowSubtitle)
                .foregroundStyle(V371.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 120, alignment: .center)
                .accessibilityLabel("本期暂无收入数据")
        }
    }

    /// 选中读数行：固定高度，选中前后不引起布局跳动。
    /// 未选中时给出操作提示；选中时显示该日日期 + 真实金额（模型原值）。
    private var selectionReadout: some View {
        let text = selectedPoint.map { "\($0.label) · \(Fmt.money($0.value))" }
            ?? "点按或拖动柱形，查看单日金额"
        return Text(text)
            .font(V38PerformanceStyle.readoutLabel)
            .foregroundStyle(selectedPoint == nil ? V371.Colors.textTertiary : V371.Colors.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 18)
            .accessibilityIdentifier("v38.performance.chartSelection")
            .accessibilityLabel(selectedPoint == nil ? text : "已选日期 \(text)")
    }

    private var chart: some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value("日期", point.label),
                    y: .value("营业额", point.value)
                )
                .foregroundStyle(barColor(for: point))
                .cornerRadius(3)
            }

            if let selected = selectedPoint {
                RuleMark(x: .value("日期", selected.label))
                    .foregroundStyle(V371.Colors.textTertiary.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartXSelection(value: $selectedLabel)
        .chartYScale(domain: 0...domainMax)
        .chartYAxis(.hidden)
        .chartXAxis {
            // P0-3：只给抽稀后的关键日期挂标签，其余数据点照常渲染柱形。
            AxisMarks(values: axisLabelValues) { _ in
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
        // 周期切换后旧选中日期多半已不在新数据内，清空避免读数悬空。
        .onChange(of: points.map(\.label)) { _, _ in
            selectedLabel = nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("收入趋势图")
        .accessibilityValue(accessibilitySummary)
    }

    /// 选中反馈：选中柱保持实色，其余柱淡化（Light/Dark 均可辨认）。
    private func barColor(for point: TrendPoint) -> Color {
        guard let selected = selectedPoint, selected.label != point.label else {
            return V38PerformanceStyle.accent
        }
        return V38PerformanceStyle.accent.opacity(0.3)
    }

    private var accessibilitySummary: String {
        let total = points.reduce(0) { $0 + $1.value }
        var summary = "共 \(points.count) 天，合计 \(Fmt.money(total))"
        if let selected = selectedPoint {
            summary += "，已选 \(selected.label)，\(Fmt.money(selected.value))"
        }
        return summary
    }
}
