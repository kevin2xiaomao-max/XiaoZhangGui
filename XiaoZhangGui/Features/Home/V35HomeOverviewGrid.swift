import SwiftUI

struct V35HomeOverviewGrid: View {
    let todoCount: Int
    let expiryCount: Int
    let customerCount: Int
    var body: some View {
        HStack(spacing: 0) {
            statusItem("待办", todoCount, "checkmark.circle", V32.brand)
            divider
            statusItem("客户需求", customerCount, "person.2", V32.info)
            divider
            statusItem("临期", expiryCount, "clock.badge.exclamationmark", V32.amber)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(V32.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(V32.cardOutline.opacity(0.7), lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private var divider: some View {
        Rectangle()
            .fill(V32.divider.opacity(0.7))
            .frame(width: 1, height: 24)
    }

    private func statusItem(_ title: String, _ count: Int, _ icon: String, _ color: Color) -> some View {
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今天\(title)\(count)项")
    }
}
