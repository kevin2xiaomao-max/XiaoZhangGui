import SwiftUI
import SwiftData

/// 全量交易历史只在独立页面按需展示，经营首页仍保持轻量的最近 12 条。
struct TransactionHistoryView: View {
    @Query private var performances: [Performance]
    @Query private var expenses: [Expense]
    @State private var search = ""

    private var records: [MoneyRecord] {
        let all = MoneyRecord.merged(
            performances: performances,
            expenses: expenses,
            range: (.distantPast, .distantFuture)
        )
        guard !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return all }
        let query = search.lowercased()
        return all.filter { record in
            record.title.lowercased().contains(query) || record.source.lowercased().contains(query)
        }
    }

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView("暂无交易", systemImage: "tray", description: Text("导入或记录交易后会显示在这里。"))
            } else {
                ForEach(records) { record in
                    TransactionHistoryRow(record: record)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("全部交易")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "搜索交易或来源")
    }
}

private struct TransactionHistoryRow: View {
    let record: MoneyRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.kind == .income ? "arrow.down.left" : "arrow.up.right")
                .foregroundStyle(record.kind == .income ? V32.brand : V32.danger)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.title).v32Text(.body).foregroundStyle(V32.textPrimary)
                Text("\(record.date, format: .dateTime.year().month().day().hour().minute()) · \(record.source)")
                    .v32Text(.caption).foregroundStyle(V32.textTertiary)
            }
            Spacer(minLength: 8)
            Text((record.kind == .income ? "+" : "-") + Fmt.money(record.amount))
                .v32Text(.body).foregroundStyle(record.kind == .income ? V32.brand : V32.danger)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
