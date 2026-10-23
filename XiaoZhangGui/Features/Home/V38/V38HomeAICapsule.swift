import SwiftUI

/// V3.8 重建 · Home 生产级 AI 胶囊。
///
/// 由 Worker B 的 `V38AICapsuleView`（Experiments，`#if DEBUG`）生产化：
/// - 移除 DEBUG 限制，接入真实 AI Sheet 路由（`onOpenAI` 回调 → `showAI = true`）
/// - 展开态对照 `XZG_iOS_V38_UI_AIMorph.png`：轻玻璃输入 Sheet
/// - 不建第二条 AI Provider/ToolExecutor 链；输入行点击后打开现有 AI Sheet
/// - 动效时序使用生产模块 `V38MotionTokens`；Reduce Motion/Transparency 有回退
struct V38HomeAICapsule: View {
    @Binding var isExpanded: Bool
    /// 用户点击输入行：打开真实 AI Sheet（由宿主将 `showAI` 置 true）。
    var onOpenAI: () -> Void = {}
    /// 展开/收起变化时通知宿主（互斥收起快捷菜单）。
    var onExpandChange: (Bool) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var morph

    var body: some View {
        if isExpanded {
            // ZStack 分层：玻璃背景层只承载视觉，内容层（按钮）在玻璃之外——
            // iOS 26 下 glassEffect 内容内的嵌套按钮会从无障碍树消失（Worker B 实证）。
            ZStack(alignment: .topLeading) {
                V38HomeGlassSurface(radius: 28) {
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: 170)
                }
                .matchedGeometryEffect(id: "v38-home-ai", in: morph)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.tint)
                        Text("问小掌柜")
                            .font(.headline)
                            .lineLimit(1)
                        Spacer()
                    }
                    // 真实入口：点击打开 AI Sheet（现有 AIChatView，不新建链路）。
                    Button(action: onOpenAI) {
                        HStack(spacing: 10) {
                            Text("告诉小掌柜你想查询或记录什么…")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer()
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("v38.home.ai.openSheet")
                    .accessibilityLabel("打开问小掌柜 AI 助手")
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // 不给 ZStack 挂 identifier（避免遮蔽内部按钮）；展开态由收起按钮判定。
            .overlay(alignment: .topTrailing) {
                Button { setExpanded(false) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("v38.home.ai.collapse")
                .accessibilityLabel("收起问小掌柜")
                .padding(12)
            }
        } else {
            Button { setExpanded(true) } label: {
                V38HomeGlassSurface(radius: 27) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.tint)
                        // V3.8.1 P0-4：胶囊标题单行，大字号下等比缩放不换行。
                        Text("问小掌柜…")
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 56)
                }
                .matchedGeometryEffect(id: "v38-home-ai", in: morph)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v38.home.ai.expand")
            .accessibilityLabel("展开问小掌柜")
        }
    }

    private func setExpanded(_ value: Bool) {
        withAnimation(V38MotionTokens.animation(for: .expand, reduceMotion: reduceMotion)) {
            onExpandChange(value)
            isExpanded = value
        }
    }
}
