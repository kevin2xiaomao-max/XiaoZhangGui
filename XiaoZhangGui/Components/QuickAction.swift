import SwiftUI

struct QuickAction: View {
    let title: String
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button {
            Haptic.light()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(V21.divider, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}
