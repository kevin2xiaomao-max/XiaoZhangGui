import SwiftUI

struct BusinessRow: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var trailingColor: Color = .primary
    var systemImage: String? = nil
    var badge: String? = nil
    var badgeTone: StatusBadge.Tone = .neutral

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let badge {
                StatusBadge(text: badge, tone: badgeTone)
            }
            if let trailing {
                Text(trailing)
                    .font(.body.weight(.medium))
                    .foregroundStyle(trailingColor)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
