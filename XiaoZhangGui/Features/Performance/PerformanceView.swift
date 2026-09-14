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
        List {
            Section {
                hero
                metricRow
            }

            Section("最近交易") {
                if records.isEmpty {
                    AppEmptyState(title: "暂无记录", systemImage: "tray", actionTitle: "记一笔") {
                        newRecordKind = .income
                    }
                } else {
                    ForEach(Array(records.prefix(12))) { record in
                        Button {
                            if let value = record.performance { editingPerformance = value }
                            if let value = record.expense { editingExpense = value }
                        } label: {
                            PerformanceRecordRow(record: record)
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

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日营业额")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Fmt.money(todayRevenue))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    if let change = changePercent {
                        Label {
                            Text("\(String(format: "%.1f", abs(change)))% 较昨日")
                        } icon: {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(change >= 0 ? V21.brandGreen : V21.danger)
                    } else {
                        Text("暂无昨日对比")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                TrendChart(points: trend, height: 42)
                    .frame(width: 96)
            }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
    }

    private var metricRow: some View {
        HStack(spacing: 8) {
            metricCell(title: "昨日", value: yesterdayRevenue)
            metricCell(title: "本月", value: monthRevenue)
            metricCell(title: "本年", value: yearRevenue)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func metricCell(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Fmt.money(value))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.28), lineWidth: 0.5)
        )
    }

    private func deleteRecord(_ record: MoneyRecord) {
        Haptic.warning()
        if let value = record.performance { try? PerformanceRepository(context: context).delete(value) }
        if let value = record.expense { try? ExpenseRepository(context: context).delete(value) }
    }
}

private struct PerformanceRecordRow: View {
    let record: MoneyRecord

    var body: some View {
        HStack(spacing: 12) {
            sourceMark
            VStack(alignment: .leading, spacing: 2) {
                Text(DisplayText.visible(record.title, fallback: record.kind == .income ? "营业额" : "支出"))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(record.kind == .income ? "+\(Fmt.money(record.amount))" : "-\(Fmt.money(record.amount))")
                .font(.body.weight(.medium).monospacedDigit())
                .foregroundStyle(record.kind == .income ? V21.brandGreen : V21.danger)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let source = record.source
        let time = Fmt.shortDateTime(record.date)
        if source.isEmpty { return time }
        return "\(source) · \(time)"
    }

    private var sourceMark: some View {
        ZStack {
            Circle().fill(record.kind == .income ? V21.brandGreen.opacity(0.14) : V21.danger.opacity(0.12))
            Image(systemName: record.source == "扫呗" ? "qrcode" : (record.kind == .income ? "plus" : "minus"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(record.kind == .income ? V21.brandGreen : V21.danger)
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }
}

enum NewMoneyKind: Identifiable {
    case income, expense
    var id: Self { self }
}
