import SwiftUI

struct V36CircleIconButton: View {
    let systemName: String
    var badge: Int = 0
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(V32.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(V32.card)
                            .overlay(Circle().strokeBorder(V32.cardOutline, lineWidth: 1))
                    )
                if badge > 0 {
                    Text("\(min(badge, 9))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Circle().fill(V32.brand))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(V32PressButtonStyle())
    }
}

struct V36AccentRow<Content: View>: View {
    var accent: Color = V32.brand
    /// V3.6.1 紧凑变体：仅日程时间轴使用，Todo 等其他调用方保持原尺寸。
    var compact: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: compact ? 10 : 12) {
            Capsule()
                .fill(accent)
                .frame(width: compact ? 2.5 : 3, height: compact ? 24 : 28)
            content
        }
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 9 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: compact ? 13 : 16, style: .continuous)
                .fill(V32.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 13 : 16, style: .continuous)
                .strokeBorder(V32.cardOutline, lineWidth: 1)
        )
    }
}

struct V36FloatingTabBar: View {
    @Binding var selection: AppTab

    private let tabs: [AppTab] = [.home, .schedule, .assistant, .todo, .profile]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs, id: \.self) { item in
                Button {
                    selection = item
                    Haptic.light()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .semibold))
                        if selection == item {
                            Text(item.title)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(selection == item ? Color.white : V32.textTertiary)
                    .padding(.horizontal, selection == item ? 11 : 8)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(selection == item ? V32.brand : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(V32.cardOutline.opacity(0.8), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }
}
