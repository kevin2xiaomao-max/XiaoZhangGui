import SwiftUI

// MARK: - Floating Dock（Studio UI）
// 4 个线框 Tab + 最右实心加号（语音/记一笔），胶囊浮层，无文字标签。

enum AppTab: Hashable {
    case home, performance, todo, profile

    var title: String {
        switch self {
        case .home: return "首页"
        case .performance: return "业绩"
        case .todo: return "待办"
        case .profile: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .performance: return "square.stack"
        case .todo: return "checkmark.circle"
        case .profile: return "person"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .performance: return "square.stack.fill"
        case .todo: return "checkmark.circle.fill"
        case .profile: return "person.fill"
        }
    }
}

struct FloatingDock: View {
    @Binding var selection: AppTab
    var showsVoiceButton: Bool = true
    var onVoice: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private let tabs: [AppTab] = [.home, .todo, .performance, .profile]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.self) { tab in
                dockItem(tab)
            }
            plusButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).fill(V21.surfaceElevated.opacity(0.55)))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(V21.divider.opacity(0.55), lineWidth: 0.6)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.10), radius: 18, y: 8)
        .padding(.horizontal, 28)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func dockItem(_ tab: AppTab) -> some View {
        let selected = selection == tab
        Button {
            guard selection != tab else { return }
            selection = tab
            Haptic.light()
        } label: {
            Image(systemName: selected ? tab.selectedIcon : tab.icon)
                .font(.system(size: 20, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? V21.textPrimary : V21.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var plusButton: some View {
        Button {
            Haptic.medium()
            onVoice()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? V21.background : Color.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(V21.textPrimary))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsVoiceButton ? "语音记一笔" : "记一笔")
        .opacity(showsVoiceButton ? 1 : 0.92)
    }
}

// MARK: - 触感反馈

import UIKit

enum Haptic {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
