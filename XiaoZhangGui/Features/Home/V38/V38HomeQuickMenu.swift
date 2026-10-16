import SwiftUI

/// V3.8 重建 · Home 生产级快捷菜单。
///
/// 由 Worker B 的 `V38QuickMenuView`（Experiments，`#if DEBUG`）生产化：
/// - 移除 DEBUG 限制；选项点击经 `onSelect` 回调接入真实 QuickRecordSheet 路由
/// - 展开态对照 `XZG_iOS_V38_UI_QuickMorph.png`：深色"快速操作"菜单
/// - 不写库、不建保存链；保存由现有 QuickRecordSheet 完成
/// - 动效时序使用生产模块 `V38MotionTokens`
/// - 无障碍：行按钮 identifier 直接挂按钮（容器不挂 identifier，避免遮蔽）
struct V38HomeQuickMenu: View {
    enum Action: String, CaseIterable {
        case income, expense, memo

        var title: String {
            switch self {
            case .income: return "记收入"
            case .expense: return "记支出"
            case .memo: return "写备忘"
            }
        }

        var icon: String {
            switch self {
            case .income: return "plus.circle"
            case .expense: return "minus.circle"
            case .memo: return "note.text"
            }
        }
    }

    @Binding var isExpanded: Bool
    /// 选项被点击：宿主打开 QuickRecordSheet（现有生产路由）。
    var onSelect: (Action) -> Void = { _ in }
    /// 展开/收起变化时通知宿主（互斥收起 AI 胶囊）。
    var onExpandChange: (Bool) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var morph

    var body: some View {
        if isExpanded {
            // 注意：不给 ZStack 容器挂 accessibilityIdentifier——实测（Worker B）：
            // identifier 挂在容器上会覆盖其内部按钮的 identifier。展开态改由
            // 收起按钮（v38.home.quick.collapse）的存在性判定。
            ZStack {
                V38HomeQuickMenuBackground()
                    .matchedGeometryEffect(id: "v38-home-quick", in: morph)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.tint)
                        Text("快速操作")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(16)
                    Divider().padding(.horizontal, 16)
                    ForEach(Action.allCases, id: \.self) { action in
                        quickRow(action)
                        if action != Action.allCases.last {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                Button { setExpanded(false) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("v38.home.quick.collapse")
                .accessibilityLabel("收起快速操作")
                .padding(12)
            }
        } else {
            Button { setExpanded(true) } label: {
                V38HomeGlassSurface(radius: 25) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.headline)
                        Text("快速记一笔")
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
                }
                .matchedGeometryEffect(id: "v38-home-quick", in: morph)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v38.home.quick.expand")
            .accessibilityLabel("展开快速操作")
        }
    }

    private func quickRow(_ action: Action) -> some View {
        Button {
            onSelect(action)
            setExpanded(false)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                Text(action.title)
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.horizontal, 18)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v38.home.quick.\(action.rawValue)")
        .accessibilityLabel(action.title)
    }

    private func setExpanded(_ value: Bool) {
        withAnimation(V38MotionTokens.animation(for: .expand, reduceMotion: reduceMotion)) {
            onExpandChange(value)
            isExpanded = value
        }
    }
}

/// 快捷菜单展开态背景：深色面板（三档：Reduce Transparency / iOS 26 glass / 旧系统材质）。
private struct V38HomeQuickMenuBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        if reduceTransparency {
            shape
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay(shape.strokeBorder(Color.secondary.opacity(0.16), lineWidth: 1))
        } else if #available(iOS 26.0, *) {
            // 深色"快速操作"面板：对照 QuickMorph 视觉稿。
            shape
                .fill(colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : Color(red: 0.13, green: 0.16, blue: 0.14))
                .glassEffect(.regular, in: shape)
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1))
        }
    }
}
