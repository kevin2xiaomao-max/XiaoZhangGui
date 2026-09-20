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

/// P5-A3 only: a complete Home-context preview. It is intentionally not used by HomeView.
struct HeroA3HomePreview: View {
    @State private var selectedTab = 0
    private let data = HeroPrototypeData.preview

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        a3Header
                        HeroA3(data: data)
                        a3FirstHomeSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
                .background(Color(uiColor: .systemBackground))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {} label: {
                            Image(systemName: "mic.fill")
                        }
                        .accessibilityLabel("一句话快速记录")
                    }
                }
            }
            .tabItem { Label("首页", systemImage: "house.fill") }
            .tag(0)

            Color(uiColor: .systemBackground)
                .tabItem { Label("日程", systemImage: "calendar") }
                .tag(1)
            Color(uiColor: .systemBackground)
                .tabItem { Label("小掌柜", systemImage: "bubble.left.and.bubble.right") }
                .tag(2)
            Color(uiColor: .systemBackground)
                .tabItem { Label("待办", systemImage: "checkmark.circle") }
                .tag(3)
            Color(uiColor: .systemBackground)
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(4)
        }
    }

    private var a3Header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("下午好")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("老板 👋")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("9月20日 · 星期日")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            Button {} label: {
                Label("26°", systemImage: "cloud.sun.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 34)
                    .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
            }
            .accessibilityLabel("天气 26度")
        }
    }

    private var a3FirstHomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日事项")
                    .font(.title3.weight(.bold))
                Spacer()
                Text("2 项")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                A3TodoRow(icon: "shippingbox", title: "确认下午配送", detail: "幸福路 · 15:00")
                Divider().padding(.leading, 42)
                A3TodoRow(icon: "checkmark.circle", title: "整理今日收款", detail: "还有 3 笔待核对")
            }
            .padding(.horizontal, 14)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

/// P5-B only: Minimal Trend in a complete Home context. Not connected to HomeView.
struct HeroBHomePreview: View {
    @State private var selectedTab = 0
    private let data = HeroPrototypeData.preview

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        bHeader
                        HeroB(data: data)
                        bFirstHomeSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
                .background(Color(uiColor: .systemBackground))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {} label: { Image(systemName: "mic.fill") }
                            .accessibilityLabel("一句话快速记录")
                    }
                }
            }
            .tabItem { Label("首页", systemImage: "house.fill") }
            .tag(0)
            Color(uiColor: .systemBackground).tabItem { Label("日程", systemImage: "calendar") }.tag(1)
            Color(uiColor: .systemBackground).tabItem { Label("小掌柜", systemImage: "bubble.left.and.bubble.right") }.tag(2)
            Color(uiColor: .systemBackground).tabItem { Label("待办", systemImage: "checkmark.circle") }.tag(3)
            Color(uiColor: .systemBackground).tabItem { Label("我的", systemImage: "person.crop.circle") }.tag(4)
        }
    }

    private var bHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("下午好").font(.subheadline).foregroundStyle(.secondary)
                Text("老板 👋")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7).lineLimit(1)
                Text("9月20日 · 星期日").font(.footnote).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            Button {} label: {
                Label("26°", systemImage: "cloud.sun.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 34)
                    .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
            }
            .accessibilityLabel("天气 26度")
        }
    }

    private var bFirstHomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日事项").font(.title3.weight(.bold))
                Spacer()
                Text("2 项").font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                A3TodoRow(icon: "shippingbox", title: "确认下午配送", detail: "幸福路 · 15:00")
                Divider().padding(.leading, 42)
                A3TodoRow(icon: "checkmark.circle", title: "整理今日收款", detail: "还有 3 笔待核对")
            }
            .padding(.horizontal, 14)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct HeroB: View {
    let data: HeroPrototypeData

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("今日营业额")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(data.moneyText)
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.68)
                .lineLimit(1)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("今日营业额 \(data.moneyText)")
            HStack(spacing: 4) {
                Text("↑ 12.6%").foregroundStyle(.green)
                Text("较昨日").foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))

            HeroBTrend(points: data.trend)
                .frame(height: 66)
                .padding(.top, 2)
                .accessibilityLabel("近七日营业额趋势")

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                BMetric(title: "本月", value: "¥76,274.90")
                Spacer(minLength: 4)
                BMetric(title: "目标", value: "¥100,000")
                Spacer(minLength: 4)
                BMetric(title: "完成", value: "76%", accent: true)
            }
            .padding(.top, 2)

            GeometryReader { proxy in
                Capsule().fill(Color.green.opacity(0.12)).overlay(alignment: .leading) {
                    Capsule().fill(.green.opacity(0.8)).frame(width: proxy.size.width * 0.76)
                }
            }
            .frame(height: 2)
            .accessibilityLabel("月目标完成 76%")
        }
        .padding(.vertical, 7)
    }
}

private struct HeroBTrend: View {
    let points: [Double]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Path { path in
                    guard let first = points.first else { return }
                    let step = proxy.size.width / CGFloat(max(points.count - 1, 1))
                    path.move(to: CGPoint(x: 0, y: proxy.size.height * (1 - first)))
                    for (index, point) in points.dropFirst().enumerated() {
                        path.addLine(to: CGPoint(x: CGFloat(index + 1) * step, y: proxy.size.height * (1 - point)))
                    }
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                    path.addLine(to: CGPoint(x: 0, y: proxy.size.height))
                    path.closeSubpath()
                }
                .fill(.green.opacity(0.07))

                Path { path in
                    guard let first = points.first else { return }
                    let step = proxy.size.width / CGFloat(max(points.count - 1, 1))
                    path.move(to: CGPoint(x: 0, y: proxy.size.height * (1 - first)))
                    for (index, point) in points.dropFirst().enumerated() {
                        path.addLine(to: CGPoint(x: CGFloat(index + 1) * step, y: proxy.size.height * (1 - point)))
                    }
                }
                .stroke(.green.opacity(0.78), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct BMetric: View {
    let title: String
    let value: String
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(accent ? .green : .primary)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
        }
    }
}

private struct HeroA3: View {
    let data: HeroPrototypeData

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("今日营业额")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("¥56,101")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                Text(".70")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.82))
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("今日营业额 ¥56,101.70")

            HStack(spacing: 4) {
                Text("↑ 12.6%")
                    .foregroundStyle(.green)
                Text("较昨日")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))

            Divider().padding(.top, 2)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                A3Metric(title: "本月", value: "¥76,274.90")
                Spacer(minLength: 18)
                A3Metric(title: "目标", value: "¥100,000", alignment: .trailing)
            }

            GeometryReader { proxy in
                Capsule()
                    .fill(Color.green.opacity(0.16))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.green)
                            .frame(width: proxy.size.width * 0.76)
                    }
            }
            .frame(height: 3)
            .accessibilityLabel("月目标完成 76%")
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 2)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.38), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, -2)
    }
}

private struct A3Metric: View {
    let title: String
    let value: String
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
    }
}

private struct A3TodoRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
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
        todayRevenue: 56101.70,
        yesterdayRevenue: 49823.18,
        monthRevenue: 76274.90,
        monthTarget: 100000,
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

#Preview("A3 · Home context") {
    HeroA3HomePreview()
        .preferredColorScheme(.light)
}

#Preview("B · Home context") {
    HeroBHomePreview().preferredColorScheme(.light)
}

#endif
