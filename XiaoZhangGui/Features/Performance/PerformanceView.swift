import SwiftUI
import SwiftData

struct PerformanceView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query private var performances: [Performance]
    @Query private var expenses: [Expense]
    @State private var period: PerformancePeriod = .today
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
    @State private var customEnd = Date()
    @State private var showAddDialog = false
    @State private var newRecordKind: NewMoneyKind?
    @State private var editingPerformance: Performance?
    @State private var editingExpense: Expense?

    private var isMockPreview: Bool { RuntimeMode.allowsMockData }

    private var range: (start: Date, end: Date) { period.range(customStart: customStart, customEnd: customEnd) }
    private var stats: PerformanceStats {
        PerformanceStats.compute(performances: performances, expenses: expenses, period: period, customStart: customStart, customEnd: customEnd)
    }
    private var records: [MoneyRecord] { MoneyRecord.merged(performances: performances, expenses: expenses, range: range) }
    private var trend: [TrendPoint] {
        if isMockPreview {
            let values: [(String, Double)] = [("8/23",1860),("8/24",2120),("8/25",1980),("8/26",2430),("8/27",2210),("8/28",2380),("8/29",2680)]
            return values.enumerated().map { TrendPoint(id: $0.offset, label: $0.element.0, value: $0.element.1, date: Date()) }
        }
        return PerformanceTrend.last7Days(performances: performances)
    }
    private var sources: [(name: String, amount: Double, ratio: Double)] {
        if isMockPreview { return [("微信支付",1320,0.49),("支付宝",720,0.27),("现金",420,0.16),("美团",220,0.08)] }
        return IncomeSourceSummary.compute(performances: performances, range: range).map { ($0.source.rawValue, $0.amount, $0.ratio) }
    }
    private var comparison: PeriodComparison { PeriodComparison.compute(performances: performances, currentRange: range) }

    var body: some View {
        PageBackground {
            ZStack(alignment: .bottomTrailing) {
                List {
                    titleSection.performanceRow(top: V21Layout.spaceXL, bottom: 12)
                    periodSection.performanceRow(bottom: 18, horizontal: false)
                    heroSection.performanceRow(bottom: 20)
                    trendSection.performanceRow(bottom: 20)
                    sourceSection.performanceRow(bottom: 24)
                    recentHeader.performanceRow(bottom: 8)

                    if isMockPreview {
                        ForEach(Array(mockRecent.enumerated()), id: \.offset) { _, item in
                            MockMoneyRecordRow(item: item).performanceRow(bottom: 0)
                        }
                    } else if records.isEmpty {
                        EmptyStateView(text: "当前时段暂无收入或支出记录", icon: "tray")
                            .performanceRow(bottom: 0)
                    } else {
                        ForEach(records) { record in
                            MoneyRecordRow(record: record) {
                                if let value = record.performance { editingPerformance = value }
                                if let value = record.expense { editingExpense = value }
                            }
                            .performanceRow(bottom: 0)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { deleteRecord(record) } label: { Label("删除", systemImage: "trash") }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: 8)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: V21Layout.bottomDockContentGap)
                }

                compactAddButton
                    .padding(.trailing, V21Layout.spaceXL)
                    .padding(.bottom, V21Layout.bottomDockContentGap - 24)
            }
        }
        .confirmationDialog("记一笔", isPresented: $showAddDialog, titleVisibility: .visible) {
            Button("记收入") { newRecordKind = .income }
            Button("记支出") { newRecordKind = .expense }
            Button("取消", role: .cancel) {}
        }
        .sheet(item: $newRecordKind) { MoneyEditorSheet(mode: .new($0)) }
        .sheet(item: $editingPerformance) { MoneyEditorSheet(mode: .editPerformance($0)) }
        .sheet(item: $editingExpense) { MoneyEditorSheet(mode: .editExpense($0)) }
    }

    private func deleteRecord(_ record: MoneyRecord) {
        Haptic.warning()
        if let value = record.performance { try? PerformanceRepository(context: context).delete(value) }
        if let value = record.expense { try? ExpenseRepository(context: context).delete(value) }
    }

    private var mockRecent: [(String, String, String, Double)] {
        [("20:18", "便利店销售", "门店", 86), ("19:42", "302别墅配送", "配送", 128), ("18:36", "便利店销售", "门店", 52), ("17:20", "泳装销售", "门店", 168), ("16:45", "温泉票", "门店", 240)]
    }
}

private struct MockMoneyRecordRow: View {
    @Environment(AppSettings.self) private var settings
    let item: (String, String, String, Double)
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "arrow.up.right").font(.system(size: 14, weight: .semibold)).foregroundColor(AppTheme.palette(named: settings.appThemeName).accent).frame(width: 34, height: 34).background(AppTheme.palette(named: settings.appThemeName).accent.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 3) { Text(item.1).font(AppTypography.body).foregroundColor(V21.textPrimary); Text("\(item.2) · \(item.0)").font(AppTypography.caption).foregroundColor(V21.textTertiary) }
            Spacer(); Text("+¥\(Fmt.groupedInt(item.3))").font(AppTypography.bodyMedium).foregroundColor(AppTheme.palette(named: settings.appThemeName).accent)
        }.padding(.horizontal, 18).padding(.vertical, 9)
    }
}

enum NewMoneyKind: Identifiable {
    case income, expense
    var id: Self { self }
}

private extension PerformanceView {
    var titleSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("业绩").v21Style(.titlePage).foregroundColor(V21.textPrimary)
            Text("真实的每一笔收入与支出").v21Style(.bodyMedium).foregroundColor(V21.textTertiary)
        }
    }

    var periodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PillTabRow(items: PerformancePeriod.allCases, label: { $0.rawValue }, selection: $period)
            if period == .custom {
                GlassSurface(radius: 14) {
                    HStack(spacing: 8) {
                        compactDatePicker("开始", selection: $customStart)
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold)).foregroundColor(V21.textQuaternary)
                        compactDatePicker("结束", selection: $customEnd, range: customStart...)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                }
                .padding(.horizontal, V21Layout.pageMargin)
            }
        }
    }

    func compactDatePicker(_ title: String, selection: Binding<Date>, range: PartialRangeFrom<Date>? = nil) -> some View {
        HStack(spacing: 4) {
            Text(title).v21Style(.labelMedium).foregroundColor(V21.textTertiary)
            if let range {
                DatePicker("", selection: selection, in: range, displayedComponents: .date).labelsHidden()
            } else {
                DatePicker("", selection: selection, displayedComponents: .date).labelsHidden()
            }
        }
        .frame(maxWidth: .infinity)
    }

    var heroSection: some View {
        let revenue = isMockPreview ? 2680.0 : stats.totalRevenue
        return VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text("收入").v21Style(.labelLarge).foregroundColor(V21.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("¥").font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundColor(AppTheme.palette(named: settings.appThemeName).accent)
                    Text(Fmt.groupedAmount(revenue))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(V21.textPrimary).lineLimit(1).minimumScaleFactor(0.38).layoutPriority(1)
                }
            }
            HStack(spacing: 0) {
                metricItem("收入", value: Fmt.money(revenue), color: AppTheme.palette(named: settings.appThemeName).accent)
                metricDivider
                metricItem("支出", value: Fmt.money(stats.totalExpense), color: V21.danger)
                metricDivider
                metricItem("净额", value: Fmt.money(isMockPreview ? 2680 : stats.net), color: V21.textPrimary)
            }
            comparisonView
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(V21.surfacePrimary)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(V21.divider.opacity(0.55), lineWidth: 0.75)
        }
    }

    func metricItem(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).v21Style(.labelMedium).foregroundColor(V21.textTertiary)
            Text(value).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var metricDivider: some View {
        Rectangle().fill(V21.divider).frame(width: 1, height: 28).padding(.horizontal, 8)
    }

    @ViewBuilder var comparisonView: some View {
        if isMockPreview {
            Text("↑ 12.6%  较昨日").v21Style(.labelMedium).foregroundColor(AppTheme.palette(named: settings.appThemeName).accent)
        } else if let percentage = comparison.percentage {
            HStack(spacing: 7) {
                Image(systemName: percentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text(String(format: "%.1f%%", abs(percentage))).fontWeight(.semibold)
                Text("较上一周期").foregroundColor(V21.textTertiary)
            }
            .v21Style(.labelMedium).foregroundColor(percentage >= 0 ? AppTheme.palette(named: settings.appThemeName).accent : V21.danger)
        } else {
            Text("暂无对比数据").v21Style(.labelMedium).foregroundColor(V21.textTertiary)
        }
    }

    var trendSection: some View {
        VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline) {
                    Text("收入趋势").v21Style(.titleLarge).foregroundColor(V21.textPrimary)
                    Spacer()
                    Text("最近 7 天").v21Style(.labelMedium).foregroundColor(V21.textTertiary)
                }
                if trend.contains(where: { $0.value > 0 }) {
                    IncomeTrendChart(points: trend).frame(height: 146)
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: "chart.xyaxis.line").font(.system(size: 22, weight: .light)).foregroundColor(V21.textQuaternary)
                        Text("最近 7 天暂无收入数据").v21Style(.bodyMedium).foregroundColor(V21.textTertiary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(V21.surfacePrimary))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(V21.divider.opacity(0.55), lineWidth: 0.75))
    }

    var sourceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
                Text("收入来源").v21Style(.titleLarge).foregroundColor(V21.textPrimary)
                ForEach(Array(sources.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 9) {
                        HStack {
                            Text(item.name).v21Style(.bodyLarge).foregroundColor(V21.textSecondary)
                            Spacer()
                            Text(Fmt.money(item.amount)).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(V21.textPrimary)
                            Text("\(Int((item.ratio * 100).rounded()))%")
                                .v21Style(.labelMedium).foregroundColor(V21.textTertiary).frame(width: 38, alignment: .trailing)
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(V21.divider)
                                Capsule()
                                    .fill(AppTheme.palette(named: settings.appThemeName).accent.opacity(0.7))
                                    .frame(width: geometry.size.width * item.ratio)
                            }
                        }
                        .frame(height: 3)
                        .accessibilityHidden(true)
                        if index < sources.count - 1 { Divider().overlay(V21.divider) }
                    }
                }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(V21.surfacePrimary))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(V21.divider.opacity(0.55), lineWidth: 0.75))
    }

    var recentHeader: some View { Text("最近记录").v21Style(.titleLarge).foregroundColor(V21.textPrimary) }

    var compactAddButton: some View {
        Button {
            Haptic.medium(); showAddDialog = true
        } label: {
            Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                .frame(width: 48, height: 48).background(Circle().fill(AppTheme.palette(named: settings.appThemeName).accent))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct MoneyRecordRow: View {
    @Environment(AppSettings.self) private var settings
    let record: MoneyRecord
    var onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 13) {
                Image(systemName: record.kind == .income ? "arrow.down.left" : "arrow.up.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(record.kind == .income ? AppTheme.palette(named: settings.appThemeName).accent : V21.danger)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill((record.kind == .income ? AppTheme.palette(named: settings.appThemeName).accent : V21.danger).opacity(0.1)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title).v21Style(.bodyLarge).fontWeight(.medium).foregroundColor(V21.textPrimary).lineLimit(1)
                    HStack(spacing: 6) { Text(record.source); Text("·"); Text(Fmt.shortDateTime(record.date)) }
                        .v21Style(.labelMedium).foregroundColor(V21.textTertiary).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(record.kind == .income ? "+\(Fmt.money(record.amount))" : "-\(Fmt.money(record.amount))")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(record.kind == .income ? AppTheme.palette(named: settings.appThemeName).accent : V21.danger).lineLimit(1).minimumScaleFactor(0.75)
            }
            .padding(.vertical, 11).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct IncomeTrendChart: View {
    @Environment(AppSettings.self) private var settings
    let points: [TrendPoint]

    var body: some View {
        Canvas { context, size in
            guard points.count > 1 else { return }
            let labelHeight: CGFloat = 22
            let chartHeight = size.height - labelHeight
            let maximum = max(points.map(\.value).max() ?? 0, 1)
            let stepX = size.width / CGFloat(points.count - 1)
            let chartPoints = points.enumerated().map { index, point in
                CGPoint(x: CGFloat(index) * stepX, y: chartHeight - CGFloat(point.value / maximum) * (chartHeight - 10))
            }
            for fraction in [0.0, 0.5, 1.0] {
                let y = chartHeight * fraction
                var grid = Path(); grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(grid, with: .color(V21.divider), lineWidth: 1)
            }
            let line = smoothPath(points: chartPoints)
            var area = line
            area.addLine(to: CGPoint(x: chartPoints.last?.x ?? size.width, y: chartHeight))
            area.addLine(to: CGPoint(x: chartPoints.first?.x ?? 0, y: chartHeight)); area.closeSubpath()
            context.fill(area, with: .linearGradient(
                Gradient(colors: [AppTheme.palette(named: settings.appThemeName).accent.opacity(0.22), AppTheme.palette(named: settings.appThemeName).accent.opacity(0.01)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: chartHeight)
            ))
            context.stroke(line, with: .color(AppTheme.palette(named: settings.appThemeName).accent), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            for index in [0, points.count / 2, points.count - 1] {
                context.draw(Text(points[index].label).font(.system(size: 10, weight: .medium)).foregroundColor(V21.textTertiary),
                             at: CGPoint(x: chartPoints[index].x, y: size.height - 7),
                             anchor: index == 0 ? .leading : (index == points.count - 1 ? .trailing : .center))
            }
        }
        .accessibilityLabel("最近七天收入趋势")
    }

    private func smoothPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for index in 1..<points.count {
            let previous = points[index - 1], current = points[index]
            let midpoint = (previous.x + current.x) / 2
            path.addCurve(to: current, control1: CGPoint(x: midpoint, y: previous.y), control2: CGPoint(x: midpoint, y: current.y))
        }
        return path
    }
}

private extension View {
    func performanceRow(top: CGFloat = 0, bottom: CGFloat, horizontal: Bool = true) -> some View {
        listRowSeparator(.hidden).listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: top, leading: horizontal ? V21Layout.pageMargin : 0,
                                     bottom: bottom, trailing: horizontal ? V21Layout.pageMargin : 0))
    }
}
