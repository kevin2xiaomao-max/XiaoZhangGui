import SwiftUI
import Charts

struct TrendChart: View {
    let points: [TrendPoint]

    private var hasValues: Bool {
        points.contains { $0.value > 0 }
    }

    var body: some View {
        if !hasValues {
            AppEmptyState(title: "暂无趋势", systemImage: "chart.xyaxis.line", description: "导入扫呗或记一笔营业额后显示")
                .frame(minHeight: 120)
        } else {
            Chart(points) { point in
                AreaMark(
                    x: .value("日期", point.date),
                    y: .value("营业额", point.value)
                )
                .foregroundStyle(Color.accentColor.opacity(0.12))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("日期", point.date),
                    y: .value("营业额", point.value)
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: true)
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .frame(height: 160)
            .accessibilityLabel("营业额趋势")
        }
    }
}
