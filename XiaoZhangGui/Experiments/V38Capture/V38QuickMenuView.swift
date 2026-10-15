#if DEBUG
import SwiftUI

/// V3.8 Worker B · 精修版快捷菜单（隔离演示组件）。
///
/// - 复用 `V38MotionLabTokens` / `V38MotionLabSurface` 的时序与表面（PoC 文件本身未改动）。
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
            V38MotionLabSurface(radius: 26) {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.tint)
                        Text("快速操作")
                            .font(.headline)
                        Spacer()
                        Button {
                            setExpanded(false)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityIdentifier("v38.motion.quick.collapse")
                        .accessibilityLabel("收起快速操作")
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
            .matchedGeometryEffect(id: "v38-capture-quick", in: morph)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .accessibilityIdentifier("v38.motion.quick.expanded")
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
