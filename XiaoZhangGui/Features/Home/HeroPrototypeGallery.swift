#if DEBUG
import SwiftUI

/// P5-A only: isolated visual prototypes. This file is not referenced by the app's production view tree.
struct HeroPrototypeGallery: View {
    enum Variant: String, CaseIterable, Identifiable {
        case editorial = "A · Editorial"
        case trend = "B · Minimal Trend"
        case rail = "C · Accent Rail"

        var id: String { rawValue }
    }

    private let preview = HeroPrototypeData.preview
    @State private var variant: Variant = .editorial

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Hero prototype", selection: $variant) {
                    ForEach(Variant.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Group {
                    switch variant {
                    case .editorial:
                        HeroEditorialPrototype(data: preview)
                    case .trend:
                        HeroTrendPrototype(data: preview)
                    case .rail:
                        HeroRailPrototype(data: preview)
                    }
                }
                .frame(maxWidth: .infinity)

                Text("Preview only · fake data · no write path")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
        .navigationTitle("Hero A/B/C")
    }
}

private struct HeroPrototypeData {
    let todayRevenue: Decimal
    let yesterdayRevenue: Decimal
    let monthRevenue: Decimal
    let monthTarget: Decimal
    let orders: Int
    let trend: [Double]

    static let preview = Self(
        todayRevenue: 2680.50,
        yesterdayRevenue: 2310.00,
        monthRevenue: 28640.50,
        monthTarget: 50000,
        orders: 13,
        trend: [0.28, 0.42, 0.36, 0.58, 0.50, 0.76, 0.68]
    )

    var changeText: String {
        let change = (todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100
        return String(format: "↑ %.0f%% 较昨日", NSDecimalNumber(decimal: change).doubleValue)
    }

    var progress: Double {
        min(NSDecimalNumber(decimal: monthRevenue / monthTarget).doubleValue, 1)
    }

    var moneyText: String {
        "¥" + NSDecimalNumber(decimal: todayRevenue).doubleValue.formatted(.number.precision(.fractionLength(2)))
    }
}

private struct HeroEditorialPrototype: View {
    let data: HeroPrototypeData

    var body: some View {
        HeroPrototypeSurface {
            HeroLabel("今日营业额")
            Text(data.moneyText)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .foregroundStyle(.primary)
                .accessibilityLabel("今日营业额 \(data.moneyText)")
            Divider().padding(.vertical, 4)
            HeroSummary(data: data)
        }
    }
}

private struct HeroTrendPrototype: View {
    let data: HeroPrototypeData

    var body: some View {
        HeroPrototypeSurface {
            HeroLabel("今日营业额")
            Text(data.moneyText)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .foregroundStyle(.primary)
            HStack(alignment: .bottom, spacing: 16) {
                MiniTrendLine(points: data.trend)
                    .frame(height: 30)
                    .accessibilityHidden(true)
                Text(data.changeText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }
            Divider().padding(.vertical, 4)
            HeroSummary(data: data, showTarget: true)
        }
    }
}

private struct HeroRailPrototype: View {
    let data: HeroPrototypeData

    var body: some View {
        HStack(spacing: 16) {
            Capsule().fill(.green).frame(width: 5)
            HeroPrototypeSurface {
                HeroLabel("今日营业额")
                Text(data.moneyText)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text("\(data.orders) 笔 · \(data.changeText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Divider().padding(.vertical, 2)
                HeroSummary(data: data, showTarget: true)
            }
        }
        .padding(.leading, 2)
    }
}

private struct HeroPrototypeSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12, content: { content })
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
    }
}

private struct HeroLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
    }
}

private struct HeroSummary: View {
    let data: HeroPrototypeData
    var showTarget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("本月")
                Spacer()
                Text("¥\(NSDecimalNumber(decimal: data.monthRevenue).doubleValue.formatted(.number.precision(.fractionLength(2))))")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if showTarget {
                ProgressView(value: data.progress)
                    .tint(.green)
                Text(targetText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var targetText: String {
        let remaining = NSDecimalNumber(decimal: data.monthTarget - data.monthRevenue).doubleValue
        return "目标完成 \(data.progress.formatted(.percent.precision(.fractionLength(0)))) · 还差 ¥\(remaining.formatted(.number.precision(.fractionLength(2))))"
    }
}

private struct MiniTrendLine: View {
    let points: [Double]

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                guard let first = points.first else { return }
                let step = proxy.size.width / CGFloat(max(points.count - 1, 1))
                path.move(to: CGPoint(x: 0, y: proxy.size.height * (1 - first)))
                for (index, value) in points.dropFirst().enumerated() {
                    path.addLine(to: CGPoint(x: CGFloat(index + 1) * step, y: proxy.size.height * (1 - value)))
                }
            }
            .stroke(.green.opacity(0.65), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

#Preview("A/B/C · Light · Normal") {
    HeroPrototypeGallery()
        .preferredColorScheme(.light)
        .dynamicTypeSize(.large)
}

#Preview("A/B/C · Dark · XXL") {
    HeroPrototypeGallery()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}

#Preview("A · iPhone Air width") {
    HeroEditorialPrototype(data: .preview)
        .frame(width: 320)
        .padding()
        .preferredColorScheme(.light)
}

#Preview("B · Reduce Motion reference") {
    HeroTrendPrototype(data: .preview)
        .transaction { $0.animation = nil }
        .padding()
}

#endif
