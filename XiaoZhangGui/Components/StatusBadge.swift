import SwiftUI

struct StatusBadge: View {
    let text: String
    var tone: Tone = .neutral

    enum Tone {
        case neutral, accent, warning, danger, success

        var foreground: Color {
            switch self {
            case .neutral: return .secondary
            case .accent: return Color.accentColor
            case .warning: return .orange
            case .danger: return .red
            case .success: return .green
            }
        }
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tone.foreground.opacity(0.12), in: Capsule())
    }
}
