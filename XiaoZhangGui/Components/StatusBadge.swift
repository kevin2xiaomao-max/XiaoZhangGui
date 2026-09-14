import SwiftUI

struct StatusBadge: View {
    let text: String
    var tone: Tone = .neutral

    enum Tone {
        case neutral, accent, warning, danger, success

        var foreground: Color {
            switch self {
            case .neutral: return .secondary
            case .accent: return V21.brandGreen
            case .warning: return .orange
            case .danger: return V21.danger
            case .success: return V21.brandGreen
            }
        }
    }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(tone.foreground)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tone.foreground.opacity(0.12), in: Capsule())
    }
}
