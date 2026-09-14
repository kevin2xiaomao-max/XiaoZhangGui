import SwiftUI

struct RevenueSummary: View {
    let title: String
    let amount: Double
    var yesterday: Double? = nil
    var caption: String? = nil

    private var change: Double? {
        guard let yesterday, yesterday > 0 else { return nil }
        return (amount - yesterday) / yesterday * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(Fmt.money(amount))
                .font(Tokens.TypeSize.hero)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            HStack(spacing: Tokens.Space.xs) {
                if let change {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(String(format: "%.1f%%", abs(change)))
                        .fontWeight(.medium)
                    Text("较昨日")
                        .foregroundStyle(.secondary)
                } else if let caption {
                    Text(caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("暂无昨日对比")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
            .foregroundStyle(change.map { $0 >= 0 ? Color.accentColor : Color.red } ?? .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
