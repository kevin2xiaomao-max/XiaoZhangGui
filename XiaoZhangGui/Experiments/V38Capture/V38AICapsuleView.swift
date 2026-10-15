#if DEBUG
import SwiftUI

/// V3.8 Worker B · 精修版 AI 胶囊（隔离演示组件）。
///
/// - 复用 `V38MotionLabTokens` / `V38MotionLabSurface` 的时序与表面（PoC 文件本身未改动）。
/// - 无业务数据、无网络、不调真实 AI；展开面板内的输入行仅为静态演示占位。
/// - 状态由宿主持有（`isExpanded` 双向绑定），展开时宿主负责互斥收起快捷菜单。
struct V38AICapsuleView: View {
    @Binding var isExpanded: Bool
    /// 展开/收起意图变化时通知宿主（例如互斥收起另一组件）。
    var onExpandChange: (Bool) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var morph

    var body: some View {
        if isExpanded {
            V38MotionLabSurface(radius: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.tint)
                        Text("问小掌柜")
                            .font(.headline)
                        Spacer()
                        Button {
                            setExpanded(false)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityIdentifier("v38.motion.ai.collapse")
                        .accessibilityLabel("收起问小掌柜")
                    }
                    // 演示占位输入行：不可编辑，不发送任何内容。
                    HStack(spacing: 10) {
                        Text("说说你要记录或查询什么…")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("演示输入框，不发送")
                    Text("仅演示，不连接真实 AI")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .matchedGeometryEffect(id: "v38-capture-ai", in: morph)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .accessibilityIdentifier("v38.motion.ai.expanded")
        } else {
            Button {
                setExpanded(true)
            } label: {
                V38MotionLabSurface(radius: 27) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.tint)
                        Text("问小掌柜…")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 56)
                }
                .matchedGeometryEffect(id: "v38-capture-ai", in: morph)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v38.motion.ai.expand")
            .accessibilityLabel("展开问小掌柜")
        }
    }

    private func setExpanded(_ value: Bool) {
        withAnimation(V38MotionLabTokens.animation(for: .expand, reduceMotion: reduceMotion)) {
            onExpandChange(value)
            isExpanded = value
        }
    }
}

#Preview("V38 AI Capsule") {
    @Previewable @State var expanded = false
    return NavigationStack {
        V38AICapsuleView(isExpanded: $expanded)
            .padding(20)
            .navigationTitle("AI 胶囊精修")
            .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
