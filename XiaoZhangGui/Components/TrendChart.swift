import SwiftUI
import Charts

struct TrendChart: View {
    let points: [TrendPoint]

    private var hasValues: Bool {
        points.contains { $0.value > 0 }
    }

    var body: some View {
        if hasValues {
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
                        .font(.caption)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.caption)
                }
            }
            .frame(height: 148)
            .accessibilityLabel("营业额趋势")
        }
    }
}
