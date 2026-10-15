#if DEBUG
import SwiftUI

/// V3.8 Worker B · 精修版快捷菜单（隔离演示组件）。
///
/// - 复用 `V38MotionLabTokens` 时序（PoC 文件本身未改动）；收起态胶囊复用
///   `V38MotionLabSurface`，展开态改用 `V38QuickMenuGlassBackground` 只做玻璃背景
///   （iOS 26 下 glassEffect 内容层内的按钮会从无障碍树消失，行按钮必须在玻璃之外）。
/// - 选项点击仅回调宿主（演示选择展示），不写库、不建任何保存链。
/// - 状态由宿主持有（`isExpanded` 双向绑定），展开时宿主负责互斥收起 AI 胶囊。
struct V38QuickMenuView: View {
    enum DemoAction: String, CaseIterable {
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
    /// 展开/收起意图变化时通知宿主（例如互斥收起另一组件）。
    var onExpandChange: (Bool) -> Void = { _ in }
    /// 选项被点击：仅演示回调，不执行保存。
    var onSelect: (DemoAction) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var morph

    var body: some View {
        if isExpanded {
            // 注意：展开态不用 V38MotionLabSurface 包裹内容，也不用 morph 包裹行按钮——
            // iOS 26 下，identifier 挂在 matchedGeometryEffect / transition 子树内部的按钮
            // 不会暴露到无障碍树（CI run 38795019084 / 38801281147 / 38807418888 实证：
            // 收起按钮与菜单行均不可被 XCTest 找到，而 overlay / 顶层按钮可被找到）。
            // 因此：玻璃背景层单独承载 morph；内容层（行按钮）在 morph 与 transition 之外，
            // 只做普通布局，保证无障碍树可达；视觉上玻璃面板仍做液滴形变。
            ZStack {
                V38QuickMenuGlassBackground()
                    .matchedGeometryEffect(id: "v38-capture-quick", in: morph)
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
                    ForEach(DemoAction.allCases, id: \.self) { action in
                        quickRow(action)
                        if action != DemoAction.allCases.last {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
            }
            .accessibilityIdentifier("v38.motion.quick.expanded")
            // 收起按钮放在玻璃容器之外（overlay）：iOS 26 下 glassEffect 内容内的
            // 嵌套按钮会从无障碍树消失，顶层 Button + 直接 identifier 则可被找到。
            .overlay(alignment: .topTrailing) {
                Button {
                    setExpanded(false)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("v38.motion.quick.collapse")
                .accessibilityLabel("收起快速操作")
                .padding(16)
            }
        } else {
            Button {
                setExpanded(true)
            } label: {
                V38MotionLabSurface(radius: 25) {
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
                .matchedGeometryEffect(id: "v38-capture-quick", in: morph)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v38.motion.quick.expand")
            .accessibilityLabel("展开快速操作")
        }
    }

    private func quickRow(_ action: DemoAction) -> some View {
        Button {
            onSelect(action)
            setExpanded(false)
        } label: {
            Label(action.title, systemImage: action.icon)
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.horizontal, 18)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v38.motion.quick.\(action.rawValue)")
    }

    private func setExpanded(_ value: Bool) {
        withAnimation(V38MotionLabTokens.animation(for: .expand, reduceMotion: reduceMotion)) {
            onExpandChange(value)
            isExpanded = value
        }
    }
}

/// 快捷菜单展开态的玻璃面板背景（三档：Reduce Transparency 回退 / iOS 26 glass / 旧系统材质）。
/// 它同时是 matchedGeometryEffect 的承载层——行按钮放在它之外（ZStack 内容层），
/// 因为 iOS 26 下 morph / transition 子树内部的按钮 identifier 不会暴露到无障碍树
///（CI run 38795019084 / 38801281147 / 38807418888 实证）。
private struct V38QuickMenuGlassBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        if reduceTransparency {
            shape
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay(shape.strokeBorder(Color.secondary.opacity(0.16), lineWidth: 1))
        } else if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular, in: shape)
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1))
        }
    }
}

#Preview("V38 Quick Menu") {
    @Previewable @State var expanded = false
    return NavigationStack {
        V38QuickMenuView(isExpanded: $expanded)
            .padding(20)
            .navigationTitle("快捷菜单精修")
            .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
