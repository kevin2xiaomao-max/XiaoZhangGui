import SwiftUI

struct GlassSurface<Content: View>: View {
    var elevated: Bool = false
    var radius: CGFloat = V21Layout.radiusLG
    var material: Material = .ultraThinMaterial
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26.0, *) {
            content()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            content()
                .background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.28), lineWidth: 0.5)
                }
        }
    }
}

struct PageBackground<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    Color(.systemGroupedBackground)
                    V21.background.opacity(0.55)
                }
                .ignoresSafeArea()
            }
    }
}

struct PriorityDot: View {
    let level: Int
    var size: CGFloat = 6

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }

    private var color: Color {
        switch level {
        case 2: return V21.danger
        case 1: return V21.info
        default: return V21.textQuaternary
        }
    }
}

struct SectionHeader: View {
    let title: String
    var color: Color = V21.textPrimary
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(V21.textPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, V21Layout.pageMargin)
    }
}

struct PillTabRow<Item: Hashable>: View {
    let items: [Item]
    let label: (Item) -> String
    @Binding var selection: Item
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    let selected = item == selection
                    Button {
                        withAnimation(V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion))) {
                            selection = item
                        }
                        Haptic.light()
                    } label: {
                        Text(label(item))
                            .font(.subheadline.weight(selected ? .semibold : .medium))
                            .foregroundStyle(selected ? V21.textPrimary : V21.tabInactive)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(selected ? V21.surfaceElevated : Color.clear)
                            }
                            .overlay {
                                if selected {
                                    Capsule(style: .continuous)
                                        .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, V21Layout.pageMargin)
        }
    }
}

struct V21FAB: View {
    let systemImage: String
    var action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button {
                Haptic.medium()
                action()
            } label: {
                Image(systemName: systemImage)
                    .font(.system(size: V21Layout.fabIconSize, weight: .semibold))
                    .frame(width: V21Layout.fabSize, height: V21Layout.fabSize)
            }
            .buttonStyle(.glassProminent)
            .tint(V21.brandGreen)
            .accessibilityLabel("新增")
        } else {
            Button {
                Haptic.medium()
                action()
            } label: {
                Image(systemName: systemImage)
                    .font(.system(size: V21Layout.fabIconSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: V21Layout.fabSize, height: V21Layout.fabSize)
                    .background(V21.brandGreen, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("新增")
        }
    }
}

struct EmptyStateView: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
            }
            Text(text)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

// MARK: - 统一底部安全区 Padding
// 解决系统 Tab Bar 遮挡长列表最后一项的问题。
// 使用 safeAreaPadding 而非 safeAreaInset+Spacer：
// 后者会把 Spacer 变成可滚动内容，短页面产生无意义空白。

struct BottomContentPaddingModifier: ViewModifier {
    let padding: CGFloat
    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.bottom, padding)
    }
}

extension View {
    /// 给 List/ScrollView 添加统一的底部呼吸空间，
    /// 确保最后一项内容不会被 Tab Bar 遮挡，且不产生可滚动空白。
    func bottomDockPadding(_ padding: CGFloat = V21Layout.bottomContentPadding) -> some View {
        modifier(BottomContentPaddingModifier(padding: padding))
    }
}
