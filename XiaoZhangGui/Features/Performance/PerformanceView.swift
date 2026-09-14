import SwiftUI
import SwiftData

struct PerformanceView: View {
    @Environment(\.modelContext) private var context
    @Query private var performances: [Performance]
    @Query private var expenses: [Expense]
    @State private var chartPeriod: PerformanceChartPeriod = .day
    @State private var showAddDialog = false
    @State private var showImport = false
    @State private var newRecordKind: NewMoneyKind?
    @State private var editingPerformance: Performance?
    @State private var editingExpense: Expense?

    private var period: PerformancePeriod { chartPeriod.statsPeriod }
    private var range: (start: Date, end: Date) {
        period.range(customStart: Date(), customEnd: Date())
    }
    private var stats: PerformanceStats {
        PerformanceStats.compute(
            performances: performances,
            expenses: expenses,
            period: period,
            customStart: Date(),
            customEnd: Date()
        )
    }
    private var yesterdayRevenue: Double {
        let date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return performances.filter { $0.date.isSameDay(as: date) }.reduce(0) { $0 + $1.amount }
    }
    private var records: [MoneyRecord] {
        MoneyRecord.merged(performances: performances, expenses: expenses, range: range)
    }
    private var trend: [TrendPoint] {
        PerformanceTrend.points(for: chartPeriod, performances: performances)
    }

    var body: some View {
        List {
            Section {
                Picker("周期", selection: $chartPeriod) {
                    ForEach(PerformanceChartPeriod.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: Tokens.Space.page, bottom: 8, trailing: Tokens.Space.page))
                .listRowSeparator(.hidden)

                RevenueSummary(
                    title: period.rawValue + "营业额",
                    amount: stats.totalRevenue,
                    yesterday: chartPeriod == .day ? yesterdayRevenue : nil,
                    caption: chartPeriod == .day ? nil : comparisonCaption
                )
                TrendChart(points: trend)
            }

            Section("记录") {
                if records.isEmpty {
                    AppEmptyState(title: "暂无记录", systemImage: "tray", description: "记一笔或导入扫呗账单")
                } else {
                    ForEach(records) { record in
                        Button {
                            if let value = record.performance { editingPerformance = value }
                            if let value = record.expense { editingExpense = value }
                        } label: {
                            BusinessRow(
                                title: record.title,
                                subtitle: [record.source, Fmt.shortDateTime(record.date)].joined(separator: " · "),
                                trailing: record.kind == .income ? "+\(Fmt.money(record.amount))" : "-\(Fmt.money(record.amount))",
                                trailingColor: record.kind == .income ? Color.accentColor : .red,
                                systemImage: record.kind == .income ? "arrow.down.left" : "arrow.up.right"
                            )
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { deleteRecord(record) } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("业绩")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("记收入") { newRecordKind = .income }
                    Button("记支出") { newRecordKind = .expense }
                    Button("扫呗导入", systemImage: "square.and.arrow.down") { showImport = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showImport) { SaobeiImportSheet() }
        .sheet(item: $newRecordKind) { MoneyEditorSheet(mode: .new($0)) }
        .sheet(item: $editingPerformance) { MoneyEditorSheet(mode: .editPerformance($0)) }
        .sheet(item: $editingExpense) { MoneyEditorSheet(mode: .editExpense($0)) }
    }

    private var comparisonCaption: String? {
        let comparison = PeriodComparison.compute(performances: performances, currentRange: range)
        guard let percentage = comparison.percentage else { return "暂无对比数据" }
        let arrow = percentage >= 0 ? "↑" : "↓"
        return String(format: "较上一周期 %@ %.1f%%", arrow, abs(percentage))
    }

    private func deleteRecord(_ record: MoneyRecord) {
        Haptic.warning()
        if let value = record.performance { try? PerformanceRepository(context: context).delete(value) }
        if let value = record.expense { try? ExpenseRepository(context: context).delete(value) }
    }
}

enum NewMoneyKind: Identifiable {
    case income, expense
    var id: Self { self }
}
