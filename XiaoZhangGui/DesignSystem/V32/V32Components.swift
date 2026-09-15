import SwiftUI

// MARK: - V32 / BusinessDesignSystem — 可复用组件
// 基准：已确认的首页/日程设计稿。白卡细描边少阴影、深墨绿 hero、
// 圆形勾选、浅底图标泡、点式状态胶囊、大留白大圆角。

// MARK: 普通卡片

struct V32Card<Content: View>: View {
    var padding: CGFloat = V32Layout.cardPad
    var fill: Color = V32.card
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: V32Radius.card, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: V32Radius.card, style: .continuous)
                    .strokeBorder(V32.cardOutline, lineWidth: 1)
            )
    }
}

// MARK: 深墨绿主视觉卡

struct V32HeroCard<Content: View>: View {
    var padding: CGFloat = V32Layout.heroPad
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(V32.textOnHero)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: V32Radius.cardLarge, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [V32.hero, V32.heroGlow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    // 克制的微光：右上角柔光，不做复杂渐变堆叠
                    RadialGradient(
                        colors: [V32.brandOnHero.opacity(0.14), .clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 240
                    )
                    .clipShape(RoundedRectangle(cornerRadius: V32Radius.cardLarge, style: .continuous))
                }
            )
    }
}

// MARK: 状态胶囊

enum V32Status {
    case pending      // 待处理（中性灰）
    case delivering   // 配送中（品牌绿）
    case done         // 已完成（弱化灰）
    case expiry       // 临期（琥珀）
    case info         // 普通进行态（品牌绿）

    var text: Color {
        switch self {
        case .pending, .done: return V32.textSecondary
        case .delivering, .info: return V32.brand
        case .expiry: return V32.amber
        }
    }
    var background: Color {
        switch self {
        case .pending, .done: return V32.neutralSoft
        case .delivering, .info: return V32.brandSoft
        case .expiry: return V32.amberSoft
        }
    }
    var dot: Color {
        switch self {
        case .pending: return V32.neutral
        case .done: return V32.neutral
        case .delivering, .info: return V32.brand
        case .expiry: return V32.amber
        }
    }
}

struct V32StatusPill: View {
    let text: String
    let status: V32Status

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.dot)
                .frame(width: 6, height: 6)
            Text(text)
                .v32Text(.pill)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .foregroundStyle(status.text)
        .background(Capsule().fill(status.background))
    }
}

// MARK: 图标泡

enum V32BubbleTone {
    case brand, amber, danger, info, neutral

    var fill: Color {
        switch self {
        case .brand: return V32.brandSoft
        case .amber: return V32.amberSoft
        case .danger: return V32.dangerSoft
        case .info: return V32.infoSoft
        case .neutral: return V32.neutralSoft
        }
    }
    var tint: Color {
        switch self {
        case .brand: return V32.brand
        case .amber: return V32.amber
        case .danger: return V32.danger
        case .info: return V32.info
        case .neutral: return V32.textSecondary
        }
    }
}

struct V32IconBubble: View {
    let systemName: String
    var tone: V32BubbleTone = .brand
    var size: CGFloat = V32Layout.bubbleRegular
    var icon: CGFloat = V32Layout.iconRegular
    var circular: Bool = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: icon, weight: .semibold))
            .foregroundStyle(tone.tint)
            .frame(width: size, height: size)
            .background(
                (circular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: V32Radius.bubble, style: .continuous)))
                    .fill(tone.fill)
            )
    }
}

// MARK: 指标格

struct V32MetricCell: View {
    let label: String
    let value: String
    var caption: String?
    var onHero: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .v32Text(.caption)
                .foregroundStyle(onHero ? V32.textOnHeroSecondary : V32.textTertiary)
            Text(value)
                .v32Text(.metric)
                .foregroundStyle(onHero ? V32.textOnHero : V32.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let caption {
                Text(caption)
                    .v32Text(.caption)
                    .foregroundStyle(onHero ? V32.textOnHeroSecondary : V32.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: 区块标题

struct V32SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .v32Text(.section)
                .foregroundStyle(V32.textPrimary)
            Spacer(minLength: 8)
            trailing
        }
    }
}

/// 轻量尾部动作（全部 › / N 项）
struct V32SectionAction: View {
    let text: String
    var chevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Text(text)
                    .v32Text(.subhead)
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .foregroundStyle(V32.textTertiary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: 圆形勾选

struct V32Checkbox: View {
    let checked: Bool
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            ZStack {
                Circle()
                    .fill(checked ? V32.brand : Color.clear)
                Circle()
                    .strokeBorder(checked ? Color.clear : V32.textTertiary.opacity(0.55), lineWidth: 1.6)
                if checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: V32Layout.checkbox, height: V32Layout.checkbox)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

// MARK: 空状态

struct V32EmptyState: View {
    let systemName: String
    let title: String
    var message: String?

    var body: some View {
        VStack(spacing: 12) {
            V32IconBubble(systemName: systemName, tone: .neutral, size: 56, icon: 24, circular: true)
            Text(title)
                .v32Text(.headline)
                .foregroundStyle(V32.textSecondary)
            if let message {
                Text(message)
                    .v32Text(.subhead)
                    .foregroundStyle(V32.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, V32Layout.pageMargin)
    }
}

// MARK: 按钮

struct V32PrimaryButton: View {
    let title: String
    var systemName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .v32Text(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(V32.brand))
        }
        .buttonStyle(.plain)
    }
}

struct V32SecondaryButton: View {
    let title: String
    var systemName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .v32Text(.headline)
            }
            .foregroundStyle(V32.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(V32.card)
                    .overlay(Capsule().strokeBorder(V32.cardOutline, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: 进度条

struct V32ProgressBar: View {
    /// 0...1
    let progress: Double
    var onHero: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(onHero ? V32.dividerOnHero : V32.neutralSoft)
                Capsule()
                    .fill(onHero ? V32.brandOnHero : V32.brand)
                    .frame(width: max(4, geo.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: 7)
    }
}
