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
                        Button("收起", systemImage: "xmark") { changeAI(false) }
                            .labelStyle(.iconOnly)
                            .accessibilityIdentifier("v38.motion.ai.collapse")
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
            V38MotionLabSurface(radius: 26) {
                VStack(spacing: 0) {
                    HStack {
                        Text("快速操作").font(.headline)
                        Spacer()
                        Button("收起", systemImage: "xmark") { changeQuick(false) }
                            .labelStyle(.iconOnly)
                            .accessibilityIdentifier("v38.motion.quick.collapse")
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
            .matchedGeometryEffect(id: "quick-button", in: quickGeometry)
            .transition(.opacity)
            .accessibilityIdentifier("v38.motion.quick.expanded")
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
