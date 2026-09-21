import SwiftUI

struct V35HomeOverviewGrid: View {
    let todoCount: Int
    let expiryCount: Int
    let customerCount: Int
    let todoInsight: String?
    let customerInsight: String?
    let expiryInsight: String?
    let onTodo: () -> Void
    let onCustomer: () -> Void
    let onExpiry: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            statusItem("待办", todoCount, todoInsight, "checkmark.circle", V32.brand, action: onTodo)
            divider
            statusItem("配送", customerCount, customerInsight, "box.truck", V32.info, action: onCustomer)
            divider
            statusItem("临期", expiryCount, expiryInsight, "clock.badge.exclamationmark", V32.amber, action: onExpiry)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) { Divider().opacity(0.6) }
        .overlay(alignment: .bottom) { Divider().opacity(0.6) }
        .accessibilityElement(children: .contain)
    }

    private var divider: some View {
        Rectangle()
            .fill(V32.divider.opacity(0.7))
            .frame(width: 1, height: 24)
    }

    private func statusItem(_ title: String, _ count: Int, _ insight: String?, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(V32.textTertiary)
                Text("\(count)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(V32.textSecondary)
                if let insight {
                    Text(insight)
                        .font(.caption2)
                        .foregroundStyle(V32.textTertiary)
                }
            }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今天\(title)\(count)项")
        .accessibilityHint("打开\(title)")
    }
}
