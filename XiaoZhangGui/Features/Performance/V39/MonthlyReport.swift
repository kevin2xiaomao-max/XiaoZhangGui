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
    let revenueChangePercent: Double? // 较上月同期(本月至今 vs 上月同期天数)
    let expense: Double               // 本月支出合计
    let sourceSplit: [IncomeSourceSummary] // 本月来源(金额>0)
    let todoCompleted: Int
    let todoTotalTracked: Int         // 已完成 + 全部未完成(整体口径,同 V38TodoProgress)
    let trendPoints: [TrendPoint]     // 近7日(收尾趋势)
    /// 对比文案固定为「较上月同期」,不得再写「较上月」(V3.9.1 P0-1)。
    let comparisonLabel: String
    /// 上期对比区间,如 "5月1日–5月15日"(空 = 无对比区间)。
    let previousPeriodLabel: String

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

        // V3.9.1 P0-1 · 较上月同期(本月至今 vs 上月同期天数),不再拿本月至今比上月整月:
        // - 本月第 N 天 → 上月 1 日至第 N 天;上月天数不足 N 天时钳制到上月月末
        //   (短月规则:如 3 月 31 日比 2 月 1–28/29 日,闰年 2 月取 29 天)。
        // - 上期收入为 0 时不显示虚假百分比(change = nil,口径同首页环比)。
        // - 区间边界均为「日」粒度(endOfDay),漏记/重复计入皆无:本月用 start..<本月至今,
        //   上期用上月 1 日..<同期末日,两区间互不重叠。
        var change: Double?
        var previousPeriodLabel = ""
        if let prevMonthDate = cal.date(byAdding: .month, value: -1, to: now),
           let prevInterval = cal.dateInterval(of: .month, for: prevMonthDate),
           let prevDayCount = cal.range(of: .day, in: .month, for: prevMonthDate)?.count {
            let dayOfMonth = cal.component(.day, from: now)
            let prevDay = min(dayOfMonth, prevDayCount)
            if let prevEnd = cal.date(byAdding: .day, value: prevDay - 1, to: prevInterval.start) {
                let prevEndDay = prevEnd.endOfDay
                let prevRevenue = performances
                    .filter { $0.date >= prevInterval.start && $0.date <= prevEndDay }
                    .reduce(0) { $0 + $1.amount }
                if prevRevenue > 0 {
                    change = (monthRevenue - prevRevenue) / prevRevenue * 100
                }
                let fmt: (Date) -> String = { date in
                    let c = cal.dateComponents([.month, .day], from: date)
                    return "\(c.month ?? 0)月\(c.day ?? 0)日"
                }
                previousPeriodLabel = "\(fmt(prevInterval.start))–\(fmt(prevEnd))"
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
            trendPoints: PerformanceTrend.last7Days(performances: performances, now: now),
            comparisonLabel: "较上月同期",
            previousPeriodLabel: previousPeriodLabel
        )
    }
}

// MARK: - 月报分享卡片(固定宽度排版,供 ImageRenderer)

struct MonthlyReportCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let report: MonthlyReport
    /// 分享图排版宽度:导出固定 390(见 renderShareImage);Sheet 预览传入可用宽度,
    /// 防止小屏下 390pt 卡片溢出(V3.9.1 P1-9)。生产导出宽度不得改。
    let width: CGFloat

    /// 显式 init(不依赖 memberwise 合成,避免 Swift 6 下参数识别歧义)。
    init(report: MonthlyReport, width: CGFloat = 390) {
        self.report = report
        self.width = width
    }

    /// Fusion 来源图例：深绿、品牌绿、灰；同时保留来源文字与百分比。
    static func sourceColor(for source: IncomeSource) -> Color {
        switch source {
        case .store: return V400Tokens.greenInk
        case .meituan: return V400Tokens.brandGreen
        case .other: return Color.secondary
        }
    }

    private var maxValue: Double {
        max(report.trendPoints.map(\.value).max() ?? 0, 1)
    }

    private var adaptiveRowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
    }

    private var revenueValue: some View {
        Text("¥" + Fmt.groupedAmount(report.revenue))
            .font(V400Tokens.serifAmount(size: 44).weight(.bold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }

    private var expenseValue: some View {
        Text("支出 ¥" + Fmt.groupedAmount(report.expense))
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            adaptiveRowLayout {
                VStack(alignment: .leading, spacing: 4) {
                    Text("掌柜的月报")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(V400Tokens.greenInk)
                    Text(report.monthLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                if let change = report.revenueChangePercent {
                    Text("\(change >= 0 ? "↑" : "↓")\(String(format: "%.1f", abs(change)))% \(report.comparisonLabel)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(change >= 0 ? V400Tokens.greenInk : V400Tokens.dangerText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(
                            (change >= 0 ? V400Tokens.greenInk : V400Tokens.dangerText).opacity(0.04)
                        ))
                        .accessibilityLabel("\(report.comparisonLabel)\(change >= 0 ? "上涨" : "下降")\(String(format: "%.1f", abs(change)))%,对比区间\(report.previousPeriodLabel)")
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("本月营业额")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        revenueValue
                        expenseValue
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        revenueValue
                        expenseValue
                    }
                }
            }

            // 近7日收尾趋势(明确标注口径 + 每柱日期,不得只写「近7日」含糊带过)。
            VStack(alignment: .leading, spacing: 6) {
                Text("近7日趋势\(report.trendPoints.first.map { "（\($0.label)" } ?? "")\(report.trendPoints.last.map { "–\($0.label)）" } ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if dynamicTypeSize.isAccessibilitySize {
                    ForEach(report.trendPoints) { point in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(point.label).font(.caption)
                            Text(Fmt.money(point.value))
                                .font(.body.monospacedDigit())
                        }
                        .accessibilityElement(children: .combine)
                    }
                } else {
                    HStack(alignment: .bottom, spacing: 7) {
                        ForEach(report.trendPoints) { point in
                            let isLast = point.id == (report.trendPoints.last?.id ?? -1)
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(isLast ? V400Tokens.greenInk : V400Tokens.greenTint)
                                .frame(width: 22, height: max(CGFloat(point.value / maxValue) * 52, 4))
                                .frame(maxWidth: .infinity, alignment: .bottom)
                        }
                    }
                    .frame(height: 52, alignment: .bottom)
                    HStack(spacing: 7) {
                        ForEach(report.trendPoints) { point in
                            Text(point.label)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .accessibilityHidden(true)
                }
            }

            // 收入来源:三色区分，纸面适配系统明暗；
            // 百分比用最大余数法取整,和为 100%(见 IncomeSourceSummary.displayPercents)。
            if !report.sourceSplit.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("收入来源")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(Array(report.sourceSplit.enumerated()), id: \.element.id) { index, item in
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.source.rawValue).font(.footnote.weight(.semibold))
                                Text("¥" + Fmt.groupedAmount(item.amount)).font(.body.monospacedDigit())
                                Text("占 \(IncomeSourceSummary.displayPercents(for: report.sourceSplit)[index])%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        } else {
                            HStack {
                                Circle()
                                    .fill(MonthlyReportCard.sourceColor(for: item.source))
                                    .frame(width: 6, height: 6)
                                Text(item.source.rawValue)
                                    .font(.footnote)
                                    .foregroundStyle(.primary)
                                Text("¥" + Fmt.groupedAmount(item.amount) + " · \(IncomeSourceSummary.displayPercents(for: report.sourceSplit)[index])%")
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            adaptiveRowLayout {
                // 待办口径保持全部历史，不改为本月。
                if dynamicTypeSize.isAccessibilitySize {
                    Text("待办完成 \(report.todoCompletionPercent)%（全部历史待办）")
                } else {
                    Label("待办完成 \(report.todoCompletionPercent)%（全部历史待办）", systemImage: "checklist")
                    Spacer()
                }
                Text("你的小掌柜")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(V400Tokens.greenInk)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .padding(24)
        .frame(width: width, alignment: .leading)
        .background(V400Tokens.paperAdaptive)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
    }
}

// MARK: - 月报表 Sheet(预览 + 分享为图片)

struct MonthlyReportSheet: View {
    let report: MonthlyReport
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: Image?
    @State private var previewWidth: CGFloat = 280

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // 预览按可用宽度缩放排版(导出仍固定 390,见 renderShareImage)。
                    MonthlyReportCard(report: report, width: previewWidth)
                        .accessibilityIdentifier("v39.report.card")
                    if let shareImage {
                        // V4 主按钮使用深绿底白字。
                        ShareLink("分享月报图片", item: shareImage, preview: SharePreview("掌柜的月报", image: shareImage))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous)
                                    .fill(V400Tokens.primaryButton)
                            )
                            .accessibilityIdentifier("v39.report.share")
                    }
                }
                .frame(maxWidth: .infinity)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth in
                    previewWidth = min(390, max(280, availableWidth))
                }
                .padding(16)
            }
            .background(V400Tokens.pageBackground.ignoresSafeArea())
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
        let renderer = ImageRenderer(content: MonthlyReportCard(report: report).environment(\.colorScheme, .light).dynamicTypeSize(.large))
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }
}
