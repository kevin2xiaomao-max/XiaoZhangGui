import SwiftUI
import SwiftData

struct PerformanceView: View {
    @Environment(\.modelContext) private var context
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
            VStack(alignment: .leading, spacing: 30) {
                performanceHero
                secondaryMetrics
                sourcesSection
                recordsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32PageBottomInset()
        .navigationTitle("经营数据")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("记收入") { newRecordKind = .income }
                    Button("记支出") { newRecordKind = .expense }
                    Button("扫呗导入", systemImage: "square.and.arrow.down") { showImport = true }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("经营数据操作")
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

    // MARK: Hero

    private var performanceHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("本月营业额")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(V32.textOnHeroSecondary)
                Spacer()
                Text("经营数据")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(V32.textOnHeroSecondary)
            }
            Text(Fmt.money(monthRevenue))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(V32.textOnHero)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日")
                        .font(.caption)
                        .foregroundStyle(V32.textOnHeroSecondary)
                    Text(Fmt.money(todayRevenue))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(V32.textOnHero)
                }
                changeBadge
                Spacer(minLength: 8)
                if !trend.isEmpty {
                    TrendChart(points: trend, height: 52, onHero: true)
                        .frame(width: 120)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [ThemeStore.shared.accentPalette.heroStart, ThemeStore.shared.accentPalette.heroEnd], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    @ViewBuilder
    private var changeBadge: some View {
        if let change = changePercent {
            HStack(spacing: 4) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text("\(String(format: "%.1f", abs(change)))% 较昨日")
                    .v32Text(.pill)
            }
            .foregroundStyle(change >= 0 ? V32.brandOnHero : V32.amberOnHero)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule().fill((change >= 0 ? V32.brandOnHero : V32.amberOnHero).opacity(0.16))
            )
        } else {
            Text("暂无昨日对比")
                .v32Text(.pill)
                .foregroundStyle(V32.textOnHeroSecondary)
        }
    }

    // MARK: 指标

    private var secondaryMetrics: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("关键指标")
                .font(.caption.weight(.medium))
                .foregroundStyle(V32.textTertiary)
            HStack(spacing: 0) {
                metric("昨日", Fmt.money(yesterdayRevenue))
                metricDivider
                metric("本年", Fmt.money(yearRevenue))
            }
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Divider() }
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(V32.textTertiary)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(V32.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricDivider: some View {
        Rectangle().fill(V32.divider).frame(width: 1, height: 36)
    }

    // MARK: 来源拆分（P0-3 美团）

    private var sourcesSection: some View {
        let summaries = IncomeSourceSummary.compute(
            performances: performances,
            range: (Date().startOfMonth, Date().endOfDay)
        )
        let active = summaries.filter { $0.amount > 0 }
        return VStack(alignment: .leading, spacing: 10) {
            Text("收入来源")
                .font(.caption.weight(.medium))
                .foregroundStyle(V32.textTertiary)
            VStack(spacing: 0) {
                    ForEach(Array(active.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider().padding(.leading, 12)
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.source.rawValue)
                                .font(.body.weight(.medium))
                                .foregroundStyle(V32.textPrimary)
                            Spacer(minLength: 12)
                            Text(Fmt.money(item.amount))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(ThemeStore.shared.accentPalette.chartAccent)
                            Text("\(String(format: "%.0f%%", item.ratio * 100))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(V32.textTertiary)
                        }
                        .padding(.vertical, 13)
                    }
                    if active.isEmpty {
                        Text("本月暂无收入")
                            .font(.subheadline)
                            .foregroundStyle(V32.textTertiary)
                            .padding(.vertical, 12)
                    }
            }
            .overlay(alignment: .top) { Divider() }
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    // MARK: 最近交易

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("交易流水")
                .font(.caption.weight(.medium))
                .foregroundStyle(V32.textTertiary)
            if records.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("暂无交易记录", systemImage: "tray")
                        .foregroundStyle(V32.textTertiary)
                    V32PrimaryButton(title: "记一笔", systemName: "plus") { newRecordKind = .income }
                }
                .padding(.vertical, 12)
            } else {
                    VStack(spacing: 0) {
                        ForEach(Array(records.prefix(12).enumerated()), id: \.element.id) { index, record in
                            if index > 0 { Divider().padding(.leading, 48) }
                            PerformanceRecordRow(
                                record: record,
                                onEdit: {
                                    if let value = record.performance { editingPerformance = value }
                                    if let value = record.expense { editingExpense = value }
                                },
                                onDelete: { deletingRecord = record }
                            )
                        }
                    }
                NavigationLink {
                    TransactionHistoryView()
                } label: {
                    Label("查看全部", systemImage: "list.bullet")
                        .v32Text(.subhead)
                        .foregroundStyle(V32.brand)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 10)
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
            V32IconBubble(systemName: iconName, tone: bubbleTone, size: 34, icon: 14)
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(DisplayText.visible(record.title, fallback: record.kind == .income ? "营业额" : "支出"))
                        .v32Text(.title)
                        .foregroundStyle(V32.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .v32Text(.caption)
                        .foregroundStyle(V32.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(record.kind == .income ? "+\(Fmt.money(record.amount))" : "-\(Fmt.money(record.amount))")
                .v32Text(.title)
                .foregroundStyle(record.kind == .income ? V32.brand : V32.danger)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(V32.textQuaternary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除记录")
        }
        .padding(.vertical, 14)
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

    private var bubbleTone: V32BubbleTone {
        if record.source == "扫呗" { return .neutral }
        return record.kind == .income ? .brand : .danger
    }
}

enum NewMoneyKind: Identifiable {
    case income, expense
    var id: Self { self }
}
