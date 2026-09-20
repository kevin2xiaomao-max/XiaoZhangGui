import SwiftUI

struct V35HomeRecentRecords: View {
    let records: [MoneyRecord]
    let onTap: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("最近记录") { Button("全部") { onTap() }.font(.subheadline).foregroundStyle(V32.brand) }
            V32Card(padding: 4) { VStack(spacing: 0) { ForEach(Array(records.prefix(3))) { record in HStack(spacing: 10) { Image(systemName: record.kind == .income ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill").foregroundStyle(record.kind == .income ? V32.brand : V32.danger); VStack(alignment: .leading, spacing: 2) { Text(record.title).font(.subheadline); Text("\(record.date, format: .dateTime.hour().minute()) · \(record.source)").font(.caption).foregroundStyle(V32.textTertiary) }; Spacer(); Text((record.kind == .income ? "+" : "−") + Fmt.money(record.amount)).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(record.kind == .income ? V32.textPrimary : V32.danger) }.padding(12) } } }
        }
    }
}
