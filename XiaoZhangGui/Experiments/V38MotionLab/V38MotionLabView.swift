import SwiftUI

/// A standalone, no-data, no-network prototype. Not connected to RootView or repositories.
/// Open from an Xcode preview or a DEBUG-only internal route after integrating with V3.8.
struct V38MotionLabView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.v38qaReduceMotionOverride) private var qaReduceMotionOverride
    /// E·QA：CI 用 `--v38-reduce-motion` 覆盖时取覆盖值，否则取系统真实值。
    private var reduceMotion: Bool { qaReduceMotionOverride ?? systemReduceMotion }
    @Namespace private var aiGeometry
    @Namespace private var quickGeometry
    @State private var aiExpanded = false
    @State private var quickExpanded = false
    @State private var prompt = ""
    @State private var selectedDemoAction: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("V3.8 · Motion Lab")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("独立动效演示 · 不读取、不保存营业数据")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)

                sectionTitle("01 · 问小掌柜")
                aiControl

                sectionTitle("02 · 快速记录")
                quickControl

                if let selectedDemoAction {
                    Text("演示选择：\(selectedDemoAction)。未执行保存。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("v38.motion.demo.selection")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("不覆盖现有 V3.8", systemImage: "checkmark.shield")
                    Text("生产页仍由真实 Repository 读取数据。这个演示不发 AI 请求、不记账，也不修改 SwiftData。")
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("V3.8 动效实验")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var aiControl: some View {
        if aiExpanded {
            V38MotionLabSurface(radius: 28) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.tint)
                        Text("问小掌柜")
                            .font(.headline)
                        Spacer()
                        // 占位：维持标题行布局；真正的收起按钮在 surface 之外的
                        // overlay 里（iOS 26 下 glassEffect 内容层内的嵌套按钮不会
                        // 暴露到无障碍树，见 B 线 CI run 38795019084 / 38801281147
                        // 与本分支 run 38800283136 实证）。
                        Color.clear
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    }
                    TextField("说说你要记录或查询什么…", text: $prompt, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("v38.motion.ai.input")
                    HStack {
                        Text("仅演示输入界面，不连接真实 AI")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .matchedGeometryEffect(id: "ai-capsule", in: aiGeometry)
            .transition(.opacity)
            .accessibilityIdentifier("v38.motion.ai.expanded")
            // 收起按钮放在玻璃容器之外：iOS 26 下 glassEffect 内容层内的嵌套按钮
            // 会从无障碍树消失（XCTest 找不到），顶层 overlay 按钮则可被找到；
            // 视觉位置与原来一致（右上，44pt 热区）。
            .overlay(alignment: .topTrailing) {
                Button { changeAI(false) } label: {
                    Image(systemName: "xmark")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("v38.motion.ai.collapse")
                .accessibilityLabel("收起")
                .padding(20)
            }
        } else {
            Button { changeAI(true) } label: {
                V38MotionLabSurface(radius: 24) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles").foregroundStyle(.tint)
                        Text("问小掌柜…").foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 54)
                }
                .matchedGeometryEffect(id: "ai-capsule", in: aiGeometry)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v38.motion.ai.expand")
        }
    }

    @ViewBuilder private var quickControl: some View {
        if quickExpanded {
            // 注意：iOS 26 下，identifier 若挂在带 matchedGeometryEffect /
            // transition 的容器上，该容器内部的按钮不会暴露到无障碍树
            //（B 线 CI run 38795019084 / 38801281147 / 38807418888 三轮实证，
            // 本分支 run 38800283136 / 38811803218 复现；overlay / 顶层按钮可达）。
            // 因此用 ZStack 分层：玻璃背景层单独承载 morph（液滴形变保留），
            // 内容层（行按钮）在 morph 与 transition 之外，只做普通布局，
            // 且容器本身不挂 identifier，保证无障碍树可达；
            // 视觉上玻璃面板仍做液滴形变。
            ZStack {
                V38MotionLabGlassBackground(radius: 26)
                    .matchedGeometryEffect(id: "quick-button", in: quickGeometry)
                    .transition(.opacity)
                VStack(spacing: 0) {
                    HStack {
                        Text("快速操作").font(.headline)
                        Spacer()
                        // 占位：维持标题行布局；真正的收起按钮在 overlay 里（玻璃之外）。
                        Color.clear
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    }
                    .padding(16)
                    Divider().padding(.horizontal, 16)
                    quickAction("记收入", icon: "plus.circle", key: "income")
                    Divider().padding(.horizontal, 16)
                    quickAction("记支出", icon: "minus.circle", key: "expense")
                    Divider().padding(.horizontal, 16)
                    quickAction("写备忘", icon: "note.text", key: "memo")
                }
            }
            // E·QA：容器上不挂 accessibilityIdentifier——iOS 26 下，
            // 带 identifier 且参与 morph/transition 的容器会吞掉内部按钮的
            // 无障碍节点（B 线三轮 + 本分支两轮 CI 实证）；展开态改由行按钮的
            // 存在性断言（见测试）。
            .overlay(alignment: .topTrailing) {
                Button { changeQuick(false) } label: {
                    Image(systemName: "xmark")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("v38.motion.quick.collapse")
                .accessibilityLabel("收起")
                .padding(16)
            }
        } else {
            Button { changeQuick(true) } label: {
                V38MotionLabSurface(radius: 25) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.headline)
                        Text("快速记一笔")
                        Spacer()
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
                }
                .matchedGeometryEffect(id: "quick-button", in: quickGeometry)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("v38.motion.quick.expand")
        }
    }

    private func quickAction(_ title: String, icon: String, key: String) -> some View {
        Button {
            selectedDemoAction = title
            changeQuick(false)
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.horizontal, 18)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v38.motion.quick.\(key)")
    }

    private func changeAI(_ expanded: Bool) {
        withAnimation(V38MotionLabTokens.animation(for: .expand, reduceMotion: reduceMotion)) {
            aiExpanded = expanded
            if expanded { quickExpanded = false }
        }
    }

    private func changeQuick(_ expanded: Bool) {
        withAnimation(V38MotionLabTokens.animation(for: .expand, reduceMotion: reduceMotion)) {
            quickExpanded = expanded
            if expanded { aiExpanded = false }
        }
    }
}

/// 快捷菜单展开态的玻璃面板背景（三档：Reduce Transparency 回退 / iOS 26 glass / 旧系统材质）。
/// 与 `V38MotionLabSurface` 同构，但只做背景——交互内容（行按钮/收起按钮）在玻璃
/// 之外，否则 iOS 26 下 glassEffect 内容层内的按钮 identifier 会从无障碍树消失
/// （B 线 CI run 38795019084 / 38801281147 实证，本分支 run 38800283136 复现）。
private struct V38MotionLabGlassBackground: View {
    let radius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.v38qaReduceTransparencyOverride) private var qaReduceTransparencyOverride
    /// E·QA：CI 用 `--v38-reduce-transparency` 覆盖时取覆盖值，否则取系统真实值。
    private var reduceTransparency: Bool { qaReduceTransparencyOverride ?? systemReduceTransparency }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
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

#if DEBUG
#Preview("Light / iOS 26+") {
    NavigationStack { V38MotionLabView() }
        .preferredColorScheme(.light)
}

#Preview("Dark / iOS 26+") {
    NavigationStack { V38MotionLabView() }
        .preferredColorScheme(.dark)
}
#endif
