import SwiftUI
import SwiftData

// MARK: - 经营 · 业绩（V371 presentation）
// 业务语义（PerformanceModel / Repository / 删除确认流程）原样保留，只换 presentation。

struct PerformanceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppSettings.self) private var settings
    @Query private var performances: [Performance]
    @Query private var expenses: [Expense]
    @State private var showImport = false
    @State private var newRecordKind: NewMoneyKind?
    @State private var editingPerformance: Performance?
    @State private var editingExpense: Expense?
    @State private var deletingRecord: MoneyRecord?
    @State private var deleteError: String?

    private var todayRevenue: Double {
        performances.filter { $0.date.isToday }.reduce(0) { $0 + $1.amount }
    }

    private var yesterdayRevenue: Double {
        let date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return performances.filter { $0.date.isSameDay(as: date) }.reduce(0) { $0 + $1.amount }
    }

    private var monthRevenue: Double {
        performances.filter { $0.date >= Date().startOfMonth && $0.date <= Date().endOfDay }.reduce(0) { $0 + $1.amount }
    }

    private var yearRevenue: Double {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: Date())) ?? Date()
        return performances.filter { $0.date >= start && $0.date <= Date().endOfDay }.reduce(0) { $0 + $1.amount }
    }

    private var monthGoal: Double { settings.monthGoal }

    private var goalProgress: Double {
        monthGoal > 0 ? min(max(monthRevenue / monthGoal, 0), 1) : 0
    }

    private var changePercent: Double? {
        guard yesterdayRevenue > 0 else { return nil }
        return (todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100
    }

    private var trend: [TrendPoint] {
        PerformanceTrend.last7Days(performances: performances)
    }

    private var records: [MoneyRecord] {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date().startOfDay) ?? Date()
        return MoneyRecord.merged(performances: performances, expenses: expenses, range: (start, Date().endOfDay))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V371.Space.section) {
                HeroMetric(title: "本月营业额", value: Fmt.money(monthRevenue)) {
                    heroInfo
                }
                .accessibilityLabel(heroAccessibilityLabel)
                goalSection
                sourcesSection
                recordsSection
            }
            .padding(.horizontal, V371.Space.page)
            .padding(.top, V371.Space.page)
        }
        .scrollIndicators(.hidden)
        .v371Canvas()
        .v371DockInset()
        .navigationTitle("经营数据")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("记收入") { newRecordKind = .income }
                    Button("记支出") { newRecordKind = .expense }
                    Button("扫呗导入", systemImage: "square.and.arrow.down") { showImport = true }
                } label: {
                    Label("记一笔", systemImage: "plus")
                }
                .accessibilityLabel("记一笔")
            }
        }
        .sheet(isPresented: $showImport) { SaobeiImportSheet() }
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

    // MARK: Hero info（目标 / 对比）

    private var heroInfo: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("今日")
                    .font(V371.Type.rowSubtitle)
                    .foregroundStyle(V371.Colors.heroTextSecondary)
                Text(Fmt.money(todayRevenue))
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    .foregroundStyle(V371.Colors.heroText)
            }
            changeBadge
            Spacer(minLength: 8)
            if !trend.isEmpty {
                // 趋势只保留细线（TrendChart 无大面积填充）
                TrendChart(points: trend, height: 44, onHero: true)
                    .frame(width: 110)
            }
        }
    }

    private var heroAccessibilityLabel: String {
        var parts = [
            "本月营业额 \(Fmt.money(monthRevenue))",
            "今日 \(Fmt.money(todayRevenue))"
        ]
        if let change = changePercent {
            let direction = change >= 0 ? "上涨" : "下降"
            parts.append("较昨日\(direction) \(String(format: "%.1f", abs(change)))%")
        }
        return parts.joined(separator: "，")
    }

    @ViewBuilder
    private var changeBadge: some View {
        if let change = changePercent {
            HStack(spacing: 4) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text("\(String(format: "%.1f", abs(change)))% 较昨日")
                    .font(V371.Type.badge)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(.white.opacity(0.18)))
        } else {
            Text("暂无昨日对比")
                .font(V371.Type.badge)
                .foregroundStyle(V371.Colors.heroTextSecondary)
        }
    }

    // MARK: 月目标

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("月目标")
            GroupSurface {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.money(monthRevenue))
                            .font(V371.Type.rowTitle)
                            .foregroundStyle(V371.Colors.textPrimary)
                            .monospacedDigit()
                        Text("/ 目标 \(Fmt.money(monthGoal))")
                            .font(V371.Type.rowSubtitle)
                            .foregroundStyle(V371.Colors.textTertiary)
                        Spacer(minLength: 8)
                        Text("\(Int((goalProgress * 100).rounded()))%")
                            .font(V371.Type.badge)
                            .foregroundStyle(V371.Colors.blue)
                            .monospacedDigit()
                    }
                    GeometryReader { proxy in
                        Capsule()
                            .fill(V371.Colors.groupSecondary)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(V371.Colors.blue)
                                    .frame(width: proxy.size.width * goalProgress)
                            }
                    }
                    .frame(height: 6)
                    .animation(V32Motion.progressWidth(reduceMotion: reduceMotion), value: goalProgress)
                    .accessibilityElement()
                    .accessibilityLabel("月目标完成 \(Int((goalProgress * 100).rounded()))%")
                    V371Divider(leading: 0)
                    HStack {
                        Text("本年累计")
                            .font(V371.Type.rowSubtitle)
                            .foregroundStyle(V371.Colors.textTertiary)
                        Spacer(minLength: 8)
                        Text(Fmt.money(yearRevenue))
                            .font(V371.Type.rowTitle)
                            .foregroundStyle(V371.Colors.textPrimary)
                            .monospacedDigit()
                    }
                }
                .padding(V371.Space.rowPadding)
            }
        }
    }

    // MARK: 收入来源

    private var sourcesSection: some View {
        let summaries = IncomeSourceSummary.compute(
            performances: performances,
            range: (Date().startOfMonth, Date().endOfDay)
        )
        let active = summaries.filter { $0.amount > 0 }
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader("收入来源")
            GroupSurface {
                if active.isEmpty {
                    Text("本月暂无收入")
                        .font(V371.Type.rowSubtitle)
                        .foregroundStyle(V371.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(V371.Space.rowPadding)
                } else {
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
                                .font(V371.Type.rowTitle)
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
        case .store: return V371.Colors.blue
        case .meituan: return V371.Colors.orange
        case .other: return V371.Colors.gray
        }
    }

    // MARK: 近期记录

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("近期记录")
            if records.isEmpty {
                GroupSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("暂无交易记录", systemImage: "tray")
                            .font(V371.Type.rowSubtitle)
                            .foregroundStyle(V371.Colors.textTertiary)
                        V32PrimaryButton(title: "记一笔", systemName: "plus") { newRecordKind = .income }
                    }
                    .padding(V371.Space.rowPadding)
                }
            } else {
                GroupSurface {
                    ForEach(Array(records.prefix(12).enumerated()), id: \.element.id) { index, record in
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
                                .font(V371.Type.rowTitle)
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
                        .font(V371.Type.rowTitle)
                        .foregroundStyle(V371.Colors.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(V371.Type.rowSubtitle)
                        .foregroundStyle(V371.Colors.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(record.kind == .income ? "+\(Fmt.money(record.amount))" : "-\(Fmt.money(record.amount))")
                .font(V371.Type.rowTitle)
                .foregroundStyle(record.kind == .income ? V371.Colors.blue : V371.Colors.red)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(V371.Colors.textTertiary)
                    .frame(width: 32, height: 44)
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
