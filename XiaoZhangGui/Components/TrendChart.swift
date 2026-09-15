import SwiftUI
import Charts

struct TrendChart: View {
    let points: [TrendPoint]
    var height: CGFloat = 56
    var showsAxis: Bool = false
    var onHero: Bool = false

    private var hasValues: Bool {
        points.contains { $0.value > 0 }
    }

    var body: some View {
        if hasValues {
            Chart(points) { point in
                LineMark(
                    x: .value("日期", point.date),
                    y: .value("营业额", point.value)
                )
                .foregroundStyle(onHero ? V32.brandOnHero : V32.brand)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(showsAxis ? .automatic : .hidden)
            .chartYAxis(showsAxis ? .automatic : .hidden)
            .chartLegend(.hidden)
            .frame(height: height)
            .accessibilityLabel("营业额趋势")
        }
    }
}
