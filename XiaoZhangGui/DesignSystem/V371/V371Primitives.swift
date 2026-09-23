import SwiftUI

// MARK: - V371 Primitives（11 个，禁止再新增小组件）
// AppCanvas → v371Canvas()（见 V371DesignSystem.swift）
// HeroMetric / GroupSurface / SectionHeader / WorkRow / TimedRow /
// StatusBadge / QuickAction / EmptyState / FloatingTabDock / AICommandEntry

// MARK: - Hairline

/// 行内分隔线。默认与图标列对齐缩进，调用方可覆盖。
struct V371Divider: View {
    var leading: CGFloat = 52
    var body: some View {
        Rectangle()
            .fill(V371.Colors.divider)
            .frame(height: 0.5)
            .padding(.leading, leading)
    }
}

// MARK: - S2 HeroMetric（蓝色能量 Hero：今日营业额 / 经营主指标 / 日历 masthead 内容）

struct HeroMetric<Info: View>: View {
    let title: String
    let value: String
    let info: Info
    var action: (() -> Void)?

    init(title: String, value: String, action: (() -> Void)? = nil,
         @ViewBuilder info: () -> Info) {
        self.title = title
        self.value = value
        self.action = action
        self.info = info()
    }

    var body: some View {
        Button {
            Haptic.light()
            action?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(V371.Typography.heroTitle)
                    .foregroundStyle(V371.Colors.heroTextSecondary)
                Text(value)
                    .font(V371.Typography.heroNumber)
                    .foregroundStyle(V371.Colors.heroText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                info
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(heroBackground)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)：\(value)")
    }

    private var heroBackground: some View {
        ZStack {
            LinearGradient(
                colors: [V371.Colors.heroTop, V371.Colors.heroBottom],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // 柔和光感（静态，不做呼吸动画）
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 170, height: 170)
                .blur(radius: 42)
                .offset(x: -100, y: -80)
            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 55)
                .offset(x: 120, y: 60)
        }
        .clipShape(RoundedRectangle(cornerRadius: V371.Radius.hero, style: .continuous))
        .shadow(color: V371.Shadow.hero.color, radius: V371.Shadow.hero.radius,
                y: V371.Shadow.hero.y)
    }
}

// MARK: - S1 GroupSurface（1 个 section surface + 多行 editorial rows）

struct GroupSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: V371.Radius.group, style: .continuous)
                    .fill(V371.Colors.group)
            )
    }
}

// MARK: - SectionHeader

struct SectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(V371.Typography.sectionTitle)
                .foregroundStyle(V371.Colors.textPrimary)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 4)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - WorkRow（图标圆 + 标题/副标题 + trailing）

struct WorkRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let action: (() -> Void)?
    let trailing: Trailing

    init(icon: String, iconColor: Color = V371.Colors.blue,
         title: String, subtitle: String? = nil,
         action: (() -> Void)? = nil,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        Button {
            if let action {
                Haptic.light()
                action()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)
                    .background(V371.Colors.tinted(iconColor), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(V371.Typography.rowTitle)
                        .foregroundStyle(V371.Colors.textPrimary)
                        .lineLimit(2)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(V371.Typography.rowSubtitle)
                            .foregroundStyle(V371.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, V371.Space.rowPadding)
            .padding(.vertical, 12)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel(title)
    }
}

/// WorkRow 常用 trailing：chevron
struct V371Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(V371.Colors.textTertiary)
            .accessibilityHidden(true)
    }
}

// MARK: - TimedRow（时间列 + 事项，用于「接下来」/ 日程）

struct TimedRow<Trailing: View>: View {
    let time: String
    let title: String
    let subtitle: String?
    let accent: Color
    let action: (() -> Void)?
    let trailing: Trailing

    init(time: String, title: String, subtitle: String? = nil,
         accent: Color = V371.Colors.blue,
         action: (() -> Void)? = nil,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.time = time
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        Button {
            if let action {
                Haptic.light()
                action()
            }
        } label: {
            HStack(spacing: 12) {
                // 左侧彩色虚线 accent（参考图 schedule 行）
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent)
                    .frame(width: 4)
                    .frame(minHeight: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(time)
                        .font(V371.Typography.time)
                        .foregroundStyle(V371.Colors.textSecondary)
                    Text(title)
                        .font(V371.Typography.rowTitle)
                        .foregroundStyle(V371.Colors.textPrimary)
                        .lineLimit(2)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(V371.Typography.rowSubtitle)
                            .foregroundStyle(V371.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, V371.Space.rowPadding)
            .padding(.vertical, 10)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel("\(time)，\(title)")
    }
}

// MARK: - StatusBadge（彩色微状态胶囊）

struct StatusBadge: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = V371.Colors.blue) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(V371.Typography.badge)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(V371.Colors.tinted(color), in: Capsule(style: .continuous))
            .lineLimit(1)
            .accessibilityLabel(text)
    }
}

// MARK: - QuickAction（4 快捷入口 tile）

struct QuickActionItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let action: () -> Void
}

struct QuickAction: View {
    let item: QuickActionItem

    var body: some View {
        Button {
            Haptic.light()
            item.action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(V371.Colors.blue)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: V371.Radius.tile, style: .continuous)
                            .fill(V371.Colors.group)
                    )
                Text(item.title)
                    .font(V371.Typography.quickAction)
                    .foregroundStyle(V371.Colors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
    }
}

/// 4 等宽快捷入口行（参考图 hero 下方）。
struct QuickActionRow: View {
    let items: [QuickActionItem]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(items) { QuickAction(item: $0) }
        }
    }
}

// MARK: - EmptyState

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String?
    let buttonTitle: String?
    let buttonAction: (() -> Void)?

    init(icon: String, title: String, message: String? = nil,
         buttonTitle: String? = nil, buttonAction: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(V371.Colors.textTertiary)
                .padding(.bottom, 2)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(V371.Colors.textPrimary)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(V371.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let buttonTitle, let buttonAction {
                Button {
                    Haptic.light()
                    buttonAction()
                } label: {
                    Text(buttonTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(V371.Colors.blue, in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

// MARK: - S3 FloatingTabDock（悬浮奶白 dock；唯一合法用 material 的底部控件）

struct FloatingTabDock: View {
    @Binding var selection: AppTab
    let tabs: [AppTab]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = tab == selection
                Button {
                    Haptic.selection()
                    withAnimation(V32Motion.quick) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(isSelected ? V371.Colors.blue : V371.Colors.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        isSelected
                            ? AnyShapeStyle(Color(.secondarySystemFill))
                            : AnyShapeStyle(Color.clear),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .shadow(color: V371.Shadow.floating.color, radius: V371.Shadow.floating.radius,
                y: V371.Shadow.floating.y)
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }
}

// MARK: - AICommandEntry（§5.6 紧凑入口：✦ 问小掌柜…；不是第 5 Tab）

struct AICommandEntry: View {
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.light()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(V371.Colors.blue)
                    .accessibilityHidden(true)
                Text("✦ 问小掌柜…")
                    .font(.subheadline)
                    .foregroundStyle(V371.Colors.textSecondary)
                Spacer(minLength: 8)
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(V371.Colors.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, V371.Space.rowPadding)
            .padding(.vertical, 14)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: V371.Radius.group, style: .continuous)
                    .fill(V371.Colors.group)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("问小掌柜")
        .accessibilityHint("打开小掌柜 AI 对话")
    }
}
