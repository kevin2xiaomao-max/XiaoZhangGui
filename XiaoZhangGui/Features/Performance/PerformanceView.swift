import SwiftUI
import SwiftData

// MARK: - 经营 · 业绩（V3.8 重建 · Editorial）
//
// 视觉依据：
// - `02_设计与交互升级说明.md`：Editorial Content + Soft Frosted Controls +
//   Native Interaction；经营页金额来自真实模型，不补演示数字。
// - Worker C `Docs/V38-Page-Motion-Spec.md` §4：金额 numericText 过渡、
//   图表柱高插值、分类 chip 的 matchedGeometryEffect 滑动选中。
//
// 业务语义全部保留自 V3.7.1（PerformanceModel / IncomeSourceSummary /
// MonthlyBusinessMetrics / Repository / 删除确认流程），仅重做 Presentation。
// 收入分类与营业额公式零改动（红线）。重建提交前缀 `rebuild(ios/v3.8):`，
// 不冒充原始 8f3a892。

struct PerformanceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppSettings.self) private var settings
    @Bindable private var demo = DemoMode.shared
    @Query private var performances: [Performance]
    @Query private var expenses: [Expense]
    @Query private var todos: [Todo]
    @Query private var customers: [CustomerRequest]
    @Query private var expiryItems: [ExpiryItem]
    @State private var showImport = false
    @State private var showDailyReport = false
    @State private var showMonthlyReport = false
    @State private var showGoods = false
    @State private var showMemo = false
    @State private var newRecordKind: NewMoneyKind?
    @State private var editingPerformance: Performance?
    @State private var editingExpense: Expense?
    @State private var deletingRecord: MoneyRecord?
    @State private var deleteError: String?

    // V3.8：图表周期与收入分类选择（纯展示层状态，不影响任何业务计算）。
    @State private var chartPeriod: PerformanceChartPeriod = .week
    @State private var sourceSelection: V38SourceSelection = .all

    /// V3.9.1 P1-7:头部四项统计一次遍历产出(旧代码每项各 filter 全量一次)。
    /// 注意:goalSection/editorialHero 由 body 一次求值后下发,不得各自再算。
    private var headerAggregates: PerformanceHeaderAggregates {
        PerformanceHeaderAggregates.build(performances: performances)
    }

    private var monthGoal: Double {
        MonthlyBusinessMetrics.goal(isDemoEnabled: demo.isEnabled, settingsGoal: settings.monthGoal)
    }

    /// 图表数据：既有模型 `PerformanceTrend.points(for:)`，不做二次计算。
    private var chartPoints: [TrendPoint] {
        PerformanceTrend.points(for: chartPeriod, performances: performances)
    }

    private var chartTotal: Double {
        chartPoints.reduce(0) { $0 + $1.value }
    }

    /// 收入分类汇总：既有模型 `IncomeSourceSummary.compute`（公式零改动）。
    private var sourceSummaries: [IncomeSourceSummary] {
        IncomeSourceSummary.compute(
            performances: performances,
            range: (Date().startOfMonth, Date().endOfDay)
        )
    }

    /// 近期记录列表仅展示最近 30 天(展示截断,另有「查看全部」进全量交易页);
    /// 本月/本年累计一律用全量 performances(headerAggregates),严禁把 30 天截断
    /// 误读为统计口径(V3.9.1 P1-7 红线:不得为性能把经营记录限制为最近两个月)。
    private var records: [MoneyRecord] {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date().startOfDay) ?? Date()
        return MoneyRecord.merged(performances: performances, expenses: expenses, range: (start, Date().endOfDay))
    }

    var body: some View {
        let header = headerAggregates
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if demo.isEnabled {
                    demoBanner
                }
                editorialHero(header)
                .accessibilityLabel(heroAccessibilityLabel(header))
                trendSection
                sourcesSection
                goalSection(header)
                recordsSection
                V371ScrollEndMarker(identifier: V371AccessibilityID.scrollEndBusiness)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(V371AccessibilityID.screenBusiness)
        .v371Canvas()
        // V3.8.1 P0-2：共享浮动 Tab 栏底部避让（safeAreaInset，非内容内 Spacer）。
        .v32PageBottomInset()
        // V3.8 P1-B2：标题与 Tab 口径统一为「经营」（Tab/首页入口/页面标题三处一致）。
        .navigationTitle("经营")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { showGoods = true } label: {
                    Label("商品", systemImage: "shippingbox")
                }
                .accessibilityLabel("商品管理")
                .accessibilityIdentifier(V371AccessibilityID.businessGoods)

                // V3.9.1 P1-6:「记一笔」只含录入(收入/支出/扫呗导入);
                // 报表/备忘/日报移到独立「更多」菜单,不得再混入录入菜单。
                Menu {
                    Button("记收入") { newRecordKind = .income }
                        .accessibilityIdentifier(V371AccessibilityID.businessAddIncome)
                    Button("记支出") { newRecordKind = .expense }
                        .accessibilityIdentifier(V371AccessibilityID.businessAddExpense)
                    Button("扫呗导入", systemImage: "square.and.arrow.down") { showImport = true }
                        .accessibilityIdentifier(V371AccessibilityID.businessImport)
                } label: {
                    Label("记一笔", systemImage: "plus")
                }
                .accessibilityLabel("记一笔")
                .accessibilityIdentifier(V371AccessibilityID.businessMenu)
                Menu {
                    // V3.9 PR-H:月度报表(生成+分享图片)。
                    Button("月度报表", systemImage: "doc.richtext") { showMonthlyReport = true }
                        .accessibilityIdentifier("v39.performance.monthlyReport")
                    Button("记录", systemImage: "note.text") { showMemo = true }
                        .accessibilityIdentifier(V371AccessibilityID.businessMemo)
                    Button("今日经营日报", systemImage: "doc.text.magnifyingglass") { showDailyReport = true }
                        .accessibilityIdentifier(V371AccessibilityID.businessDailyReport)
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
                .accessibilityLabel("更多")
                .accessibilityIdentifier("v39.performance.moreMenu")
            }
        }
        .navigationDestination(isPresented: $showGoods) { GoodsView() }
        .navigationDestination(isPresented: $showMemo) { MemoView() }
        .sheet(isPresented: $showImport) { SaobeiImportSheet() }
        .sheet(isPresented: $showMonthlyReport) {
            // V3.9 PR-H:月报数据全部来自当前 @Query,口径与页面一致。
            MonthlyReportSheet(report: MonthlyReportBuilder.build(
                performances: performances,
                expenses: expenses,
                todos: todos
            ))
        }
        .sheet(isPresented: $showDailyReport) {
            DailyReportSheet(
                report: .build(
                    performances: performances,
                    todos: todos,
                    customers: customers,
                    expiryItems: expiryItems
                )
            )
        }
        .sheet(item: $newRecordKind) { MoneyEditorSheet(mode: .new($0)) }
        .sheet(item: $editingPerformance) { MoneyEditorSheet(mode: .editPerformance($0)) }
        .sheet(item: $editingExpense) { MoneyEditorSheet(mode: .editExpense($0)) }
        .confirmationDialog("删除这条经营记录？", isPresented: Binding(get: { deletingRecord != nil }, set: { if !$0 { deletingRecord = nil } }), titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let record = deletingRecord {
                    do { try deleteRecord(record) }
                    catch { deleteError = "经营记录未删除，请重试。" }
                }
                deletingRecord = nil
            }
            Button("取消", role: .cancel) { deletingRecord = nil }
        }
        .alert("删除失败", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("知道了", role: .cancel) { deleteError = nil }
        } message: { Text(deleteError ?? "请稍后重试") }
    }

    // MARK: Demo 提示条(V3.9.1 P1-12,与首页同口径)

    private var demoBanner: some View {
        HStack(spacing: 8) {
            Label("演示数据", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
            Text("仅供演示，不会写入真实账本")
                .font(.footnote)
                .foregroundStyle(V400Tokens.tertiaryInk)
            Spacer()
            Button("退出演示") { demo.isEnabled = false }
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(V371.Colors.orange.opacity(0.15)))
        .accessibilityIdentifier("v39.demo.banner.business")
        .accessibilityLabel("演示数据，仅供演示，不会写入真实账本，可退出演示")
    }

    // MARK: Hero（本月营业额 · 54pt Editorial 大数字）

    private func editorialHero(_ header: PerformanceHeaderAggregates) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本月营业额")
                .font(V38PerformanceStyle.heroLabel)
                .foregroundStyle(V400Tokens.tertiaryInk)
            Text(Fmt.money(header.month))
                .font(V38PerformanceStyle.heroAmount)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .contentTransition(.numericText())
                .animation(
                    reduceMotion ? nil : V38MotionTokens.animation(for: .contentChange, reduceMotion: false),
                    value: header.month
                )
            heroInfo(header)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(V400Tokens.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .accessibilityIdentifier("v38.performance.hero")
    }

    private func heroInfo(_ header: PerformanceHeaderAggregates) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("今日")
                .font(V371.Typography.rowSubtitle)
                .foregroundStyle(V400Tokens.tertiaryInk)
            Text(Fmt.money(header.today))
                .font(V38PerformanceStyle.secondaryAmount)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())
                .animation(
                    reduceMotion ? nil : V38MotionTokens.animation(for: .contentChange, reduceMotion: false),
                    value: header.today
                )
            changeBadge(header)
        }
    }

    private func heroAccessibilityLabel(_ header: PerformanceHeaderAggregates) -> String {
        var parts = [
            "本月营业额 \(Fmt.money(header.month))",
            "今日 \(Fmt.money(header.today))"
        ]
        if let change = header.changePercent {
            let direction = change >= 0 ? "上涨" : "下降"
            parts.append("较昨日\(direction) \(String(format: "%.1f", abs(change)))%")
        }
        return parts.joined(separator: "，")
    }

    @ViewBuilder
    private func changeBadge(_ header: PerformanceHeaderAggregates) -> some View {
        // V4 纸面徽标使用可读的语义绿/红，保留涨跌方向与口径。
        if let change = header.changePercent {
            HStack(spacing: 4) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text("\(String(format: "%.1f", abs(change)))% 较昨日")
                    .font(V371.Typography.badge)
            }
            .foregroundStyle(change >= 0 ? V400Tokens.greenInk : V400Tokens.dangerText)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(
                    (change >= 0 ? V400Tokens.greenInk : V400Tokens.dangerText).opacity(0.04)
                )
            )
        } else {
            Text("暂无昨日对比")
                .font(V371.Typography.badge)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: 收入趋势（周期 chip + 柱状图）

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            V38HomeSectionHeader(title: "收入趋势")
            V38ChipSelector(
                options: PerformanceChartPeriod.allCases,
                selection: $chartPeriod,
                title: { $0.rawValue },
                identifier: { periodIdentifier($0) }
            )
            GroupSurface {
                VStack(alignment: .leading, spacing: 10) {
                    V38TrendBarChart(points: chartPoints)
                        .accessibilityIdentifier("v38.performance.chart")
                    V371Divider(leading: 0)
                    HStack(alignment: .firstTextBaseline) {
                        Text(chartPeriod.trendTotalLabel)
                            .font(V371.Typography.rowSubtitle)
                            .foregroundStyle(V371.Colors.textTertiary)
                        Spacer(minLength: 8)
                        Text(Fmt.money(chartTotal))
                            .font(V38PerformanceStyle.secondaryAmount)
                            .foregroundStyle(V371.Colors.textPrimary)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(
                                reduceMotion ? nil : V38MotionTokens.animation(for: .contentChange, reduceMotion: false),
                                value: chartTotal
                            )
                    }
                }
                .padding(V371.Space.rowPadding)
            }
        }
    }

    private func periodIdentifier(_ period: PerformanceChartPeriod) -> String {
        switch period {
        case .day: return "v38.performance.period.day"
        case .week: return "v38.performance.period.week"
        case .month: return "v38.performance.period.month"
        }
    }

    // MARK: 收入来源（分类 chip + 汇总数字 + 明细）

    private var sourcesSection: some View {
        let summaries = sourceSummaries
        let summary = V38SourceSummary.make(summaries: summaries, selection: sourceSelection)
        let active = summaries.filter { $0.amount > 0 }
        return VStack(alignment: .leading, spacing: 12) {
            V38HomeSectionHeader(title: "收入来源")
            if summary.total <= 0 {
                GroupSurface {
                    EmptyState(icon: "chart.bar", title: "本月暂无收入", message: "记录第一笔收入开始统计")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(V371.Space.rowPadding)
                }
            } else {
                V38ChipSelector(
                    options: V38SourceSelection.allCases,
                    selection: $sourceSelection,
                    title: { $0.title },
                    identifier: { $0.identifier }
                )
                // 分类汇总数字：切换 chip 时 numericText 滚动过渡（规格 §4）。
                VStack(alignment: .leading, spacing: 4) {
                    Text(sourceSelection == .all ? "本月总收入" : "\(sourceSelection.title)收入")
                        .font(V371.Typography.rowSubtitle)
                        .foregroundStyle(V371.Colors.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(Fmt.money(summary.amount))
                            .font(V38PerformanceStyle.summaryAmount)
                            .foregroundStyle(V371.Colors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .contentTransition(.numericText())
                            .animation(
                                reduceMotion ? nil : V38MotionTokens.animation(for: .contentChange, reduceMotion: false),
                                value: summary.amount
                            )
                            .accessibilityIdentifier("v38.performance.sourceAmount")
                        if sourceSelection != .all {
                            Text("占 \(String(format: "%.0f%%", summary.ratio * 100))")
                                .font(V371.Typography.badge)
                                .foregroundStyle(V371.Colors.textTertiary)
                        }
                    }
                }
                GroupSurface {
                    ForEach(Array(active.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { V371Divider() }
                        let ratioText = "占 \(String(format: "%.0f%%", item.ratio * 100))"
                        WorkRow(
                            icon: sourceIcon(item.source),
                            iconColor: sourceColor(item.source),
                            title: item.source.rawValue,
                            subtitle: ratioText
                        ) {
                            Text(Fmt.money(item.amount))
                                .font(V400Tokens.serifAmount(size: 17, relativeTo: .body))
                                .foregroundStyle(V371.Colors.textPrimary)
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        .accessibilityLabel("\(item.source.rawValue)，\(Fmt.money(item.amount))，\(ratioText)")
                    }
                }
            }
        }
    }

    private func sourceIcon(_ source: IncomeSource) -> String {
        switch source {
        case .store: return "storefront"
        case .meituan: return "bag"
        case .other: return "ellipsis.circle"
        }
    }

    private func sourceColor(_ source: IncomeSource) -> Color {
        switch source {
        case .store: return V400Tokens.greenInk
        case .meituan: return V400Tokens.brandGreen
        case .other: return V371.Colors.gray
        }
    }

    // MARK: 月目标

    private func goalSection(_ header: PerformanceHeaderAggregates) -> some View {
        let goalProgress = monthGoal > 0 ? min(max(header.month / monthGoal, 0), 1) : 0
        return VStack(alignment: .leading, spacing: 12) {
            V38HomeSectionHeader(title: "月目标")
            GroupSurface {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.money(header.month))
                            .font(V371.Typography.rowTitle)
                            .foregroundStyle(V371.Colors.textPrimary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("/ 目标 \(Fmt.money(monthGoal))")
                            .font(V371.Typography.rowSubtitle)
                            .foregroundStyle(V371.Colors.textTertiary)
                        Spacer(minLength: 8)
                        Text("\(Int((goalProgress * 100).rounded()))%")
                            .font(V371.Typography.badge)
                            .foregroundStyle(V400Tokens.greenInk)
                            .monospacedDigit()
                    }
                    GeometryReader { proxy in
                        Capsule()
                            .fill(V371.Colors.groupSecondary)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(V38PerformanceStyle.accent)
                                    .frame(width: proxy.size.width * goalProgress)
                            }
                    }
                    .frame(height: 6)
                    .animation(V371.Motion.progressWidth(reduceMotion: reduceMotion), value: goalProgress)
                    .accessibilityElement()
                    .accessibilityLabel("月目标完成 \(Int((goalProgress * 100).rounded()))%")
                    V371Divider(leading: 0)
                    HStack {
                        Text("本年累计")
                            .font(V371.Typography.rowSubtitle)
                            .foregroundStyle(V371.Colors.textTertiary)
                        Spacer(minLength: 8)
                        Text(Fmt.money(header.year))
                            .font(V371.Typography.rowTitle)
                            .foregroundStyle(V371.Colors.textPrimary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                .padding(V371.Space.rowPadding)
            }
        }
    }

    // MARK: 近期记录

    private var recordsSection: some View {
        // 取一次：records 内含两次 Date() 与一次全表合并，原来 isEmpty 与 prefix(12) 各算一遍。
        let items = records
        return VStack(alignment: .leading, spacing: 12) {
            V38HomeSectionHeader(title: "近期记录")
            if items.isEmpty {
                GroupSurface {
                    VStack(spacing: 12) {
                        EmptyState(icon: "tray", title: "暂无交易记录", message: "记录第一笔交易开始统计")
                        Button { newRecordKind = .income } label: {
                            Label("记一笔", systemImage: "plus")
                                .font(V371.Typography.rowTitle)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(V371.Colors.heroTop))
                        }
                    }
                    .padding(V371.Space.rowPadding)
                }
            } else {
                GroupSurface {
                    ForEach(Array(items.prefix(12).enumerated()), id: \.element.id) { index, record in
                        if index > 0 { V371Divider() }
                        PerformanceRecordRow(
                            record: record,
                            onEdit: {
                                if let value = record.performance { editingPerformance = value }
                                if let value = record.expense { editingExpense = value }
                            },
                            onDelete: { deletingRecord = record }
                        )
                    }
                    V371Divider(leading: 0)
                    NavigationLink {
                        TransactionHistoryView()
                    } label: {
                        HStack {
                            Text("查看全部")
                                .font(V371.Typography.rowTitle)
                                .foregroundStyle(V371.Colors.blue)
                            Spacer(minLength: 8)
                            V371Chevron()
                        }
                        .padding(.horizontal, V371.Space.rowPadding)
                        .padding(.vertical, 12)
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("查看全部交易")
                }
            }
        }
    }

    private func deleteRecord(_ record: MoneyRecord) throws {
        Haptic.warning()
        if let value = record.performance { try PerformanceRepository(context: context).delete(value) }
        if let value = record.expense { try ExpenseRepository(context: context).delete(value) }
    }
}

private struct PerformanceRecordRow: View {
    let record: MoneyRecord
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(V371.Colors.tinted(iconColor), in: Circle())
                .accessibilityHidden(true)
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(DisplayText.visible(record.title, fallback: record.kind == .income ? "营业额" : "支出"))
                        .font(V371.Typography.rowTitle)
                        .foregroundStyle(V371.Colors.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(V371.Typography.rowSubtitle)
                        .foregroundStyle(V371.Colors.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(record.kind == .income ? "+\(Fmt.money(record.amount))" : "-\(Fmt.money(record.amount))")
                .font(V400Tokens.serifAmount(size: 17, relativeTo: .body))
                .foregroundStyle(record.kind == .income ? V371.Colors.blue : V371.Colors.red)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(V371.Colors.textTertiary)
                    // V3.8 P1-B2：删除命中区提到 44×44pt 最低触控标准（原 32×44 易误触漏触）。
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除记录")
        }
        .padding(.horizontal, V371.Space.rowPadding)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
    }

    private var subtitle: String {
        let source = record.source
        let time = Fmt.shortDateTime(record.date)
        if source.isEmpty { return time }
        return "\(source) · \(time)"
    }

    private var iconName: String {
        record.source == "扫呗" ? "qrcode" : (record.kind == .income ? "arrow.down.left" : "arrow.up.right")
    }

    private var iconColor: Color {
        if record.source == "扫呗" { return V371.Colors.gray }
        return record.kind == .income ? V371.Colors.blue : V371.Colors.red
    }
}

enum NewMoneyKind: Identifiable {
    case income, expense
    var id: Self { self }
}
