import SwiftUI
import SwiftData

// MARK: - V3.9 PR-H · 月度经营报表(生成 + 分享)
//
// 数据口径全部复用既有模型(MonthlyBusinessMetrics / PerformanceTrend /
// IncomeSourceSummary / TodoFilter),Builder 是纯函数可单测;
// 卡片为固定 390pt 宽的「分享图」排版,ImageRenderer 渲染成图片后经系统面板分享。

/// 月报数据(纯计算,可单测)。
struct MonthlyReport {
    let monthLabel: String            // "2026年10月"
    let revenue: Double               // 本月营业额
    let revenueChangePercent: Double? // 较上月
    let expense: Double               // 本月支出合计
    let sourceSplit: [IncomeSourceSummary] // 本月来源(金额>0)
    let todoCompleted: Int
    let todoTotalTracked: Int         // 已完成 + 全部未完成(整体口径,同 V38TodoProgress)
    let trendPoints: [TrendPoint]     // 近7日(收尾趋势)

    var todoCompletionPercent: Int {
        guard todoTotalTracked > 0 else { return 0 }
        return Int((Double(todoCompleted) / Double(todoTotalTracked) * 100).rounded())
    }

    var net: Double { revenue - expense }
}

enum MonthlyReportBuilder {
    /// 纯函数组报(不碰数据库;调用方传 @Query 数据)。
    static func build(
        performances: [Performance],
        expenses: [Expense],
        todos: [Todo],
        now: Date = Date()
    ) -> MonthlyReport {
        let cal = Calendar.current
        let thisMonthStart = cal.dateInterval(of: .month, for: now)?.start ?? now.startOfMonth
        let thisMonthEnd = min(now.endOfDay, cal.dateInterval(of: .month, for: now)?.end ?? now.endOfDay)

        let monthRevenue = performances
            .filter { $0.date >= thisMonthStart && $0.date <= thisMonthEnd }
            .reduce(0) { $0 + $1.amount }
        let monthExpense = expenses
            .filter { $0.date >= thisMonthStart && $0.date <= thisMonthEnd }
            .reduce(0) { $0 + $1.amount }

        // 较上月(上月无收入则无对比,口径同首页环比)。
        var change: Double?
        if let lastMonthInterval = cal.dateInterval(of: .month, for: cal.date(byAdding: .month, value: -1, to: now) ?? now) {
            let lastRevenue = performances
                .filter { $0.date >= lastMonthInterval.start && $0.date < lastMonthInterval.end }
                .reduce(0) { $0 + $1.amount }
            if lastRevenue > 0 {
                change = (monthRevenue - lastRevenue) / lastRevenue * 100
            }
        }

        let split = IncomeSourceSummary.compute(
            performances: performances,
            range: (thisMonthStart, thisMonthEnd)
        ).filter { $0.amount > 0 }

        let completed = todos.filter(\.isCompleted).count
        let pending = todos.filter { !$0.isCompleted }.count

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return MonthlyReport(
            monthLabel: formatter.string(from: now),
            revenue: monthRevenue,
            revenueChangePercent: change,
            expense: monthExpense,
            sourceSplit: split,
            todoCompleted: completed,
            todoTotalTracked: completed + pending,
            trendPoints: PerformanceTrend.last7Days(performances: performances, now: now)
        )
    }
}

// MARK: - 月报分享卡片(固定宽度排版,供 ImageRenderer)

struct MonthlyReportCard: View {
    let report: MonthlyReport

    private var maxValue: Double {
        max(report.trendPoints.map(\.value).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("掌柜的月报")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(V39Style.gold)
                    Text(report.monthLabel)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                if let change = report.revenueChangePercent {
                    Text("\(change >= 0 ? "↑" : "↓")\(String(format: "%.1f", abs(change)))% 较上月")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(change >= 0 ? V39Style.gold : V39Style.changeDown)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(
                            (change >= 0 ? V39Style.gold : V39Style.changeDown).opacity(0.2)
                        ))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("本月营业额")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("¥" + Fmt.groupedAmount(report.revenue))
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                    Text("支出 ¥" + Fmt.groupedAmount(report.expense))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            // 近7日收尾趋势
            VStack(alignment: .leading, spacing: 6) {
                Text("近7日趋势")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(report.trendPoints) { point in
                        let isLast = point.id == (report.trendPoints.last?.id ?? -1)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(isLast ? V39Style.gold : Color.white.opacity(0.3))
                            .frame(width: 22, height: max(CGFloat(point.value / maxValue) * 52, 4))
                    }
                }
                .frame(height: 52, alignment: .bottom)
            }

            // 收入来源
            if !report.sourceSplit.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("收入来源")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    ForEach(report.sourceSplit) { item in
                        HStack {
                            Circle()
                                .fill(item.source == .meituan ? V39Style.gold : V39Style.navy)
                                .frame(width: 6, height: 6)
                            Text(item.source.rawValue)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.85))
                            Text("¥" + Fmt.groupedAmount(item.amount) + " · \(String(format: "%.0f%%", item.ratio * 100))")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
            }

            HStack {
                Label("待办完成 \(report.todoCompletionPercent)%", systemImage: "checklist")
                Spacer()
                Text("你的小掌柜")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(V39Style.gold.opacity(0.8))
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.top, 2)
        }
        .padding(24)
        .frame(width: 390, alignment: .leading)
        .background(
            ZStack {
                V39Palette.heroGradient
                V39Palette.heroGlow.blendMode(.plusLighter)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(V39Palette.heroStroke, lineWidth: 1)
        )
    }
}

// MARK: - 月报表 Sheet(预览 + 分享为图片)

struct MonthlyReportSheet: View {
    let report: MonthlyReport
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: Image?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    MonthlyReportCard(report: report)
                        .accessibilityIdentifier("v39.report.card")
                    if let shareImage {
                        ShareLink("分享月报图片", item: shareImage, preview: SharePreview("掌柜的月报", image: shareImage))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous)
                                    .fill(V39Palette.gold)
                            )
                            .accessibilityIdentifier("v39.report.share")
                    }
                }
                .padding(16)
            }
            .background(V39Palette.canvasGradientDark.ignoresSafeArea())
            .navigationTitle("月度报表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { renderShareImage() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("v39.report.sheet")
    }

    /// ImageRenderer 渲染分享图(主线程)。
    private func renderShareImage() {
        let renderer = ImageRenderer(content: MonthlyReportCard(report: report))
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }
}
