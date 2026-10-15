import SwiftUI

#if DEBUG

// MARK: - V3.8 AI Safety UX · 只读操作状态展示卡片（Debug-only 隔离组件）
//
// 不接入 RootView、生产 AI Sheet、AgentCore / ToolExecutor / Voice / Repository。
// 全部按钮只驱动本地 `V38AIOperationMachine`（内存状态），不调真实 AI、不写库、不删数据。
// Thinking 态使用系统原生 ProgressView 样式（ThinkingOrbs 仅真实 AI 处理态播放，此处禁用）。

/// 各态展示卡片。`machine` 为演示绑定，生产代码不得引用。
struct V38AIOperationCardView: View {
    @Binding var machine: V38AIOperationMachine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            switch machine.state {
            case .idle: idleBody
            case .listening: listeningBody
            case .thinking: thinkingBody
            case .draftPreview: draftPreviewBody
            case .awaitingConfirmation: awaitingConfirmationBody
            case .executing: executingBody
            case .verified: verifiedBody
            case .failed: failedBody
            }
            footer
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityIdentifier("v38.aiux.card.\(machine.state.rawValue)")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: headerIcon)
                .foregroundStyle(headerTint)
                .symbolEffect(.pulse, isActive: machine.state == .listening && !reduceMotion)
            Text("小掌柜 · 操作状态（演示）")
                .font(.headline)
            Spacer()
            Text(stateLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
        }
        .accessibilityElement(children: .combine)
    }

    private var headerIcon: String {
        switch machine.state {
        case .idle: "mic"
        case .listening: "waveform"
        case .thinking: "sparkles"
        case .draftPreview: "doc.text"
        case .awaitingConfirmation: "hand.raised"
        case .executing: "arrow.triangle.2.circlepath"
        case .verified: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var headerTint: Color {
        switch machine.state {
        case .verified: .green
        case .failed: .red
        case .awaitingConfirmation: .orange
        default: .accentColor
        }
    }

    private var stateLabel: String {
        switch machine.state {
        case .idle: "静置"
        case .listening: "收音中"
        case .thinking: "思考中"
        case .draftPreview: "草稿预览"
        case .awaitingConfirmation: "等待确认"
        case .executing: "执行中"
        case .verified: "已确认"
        case .failed: "失败"
        }
    }

    // MARK: - State bodies

    private var idleBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("说一句试试（演示，不会真实执行）")
                .font(.subheadline)
            Text("“今天营业额是多少？”只读查询；“微信收入 68 元”会先出草稿卡，不直接记账。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            demoButton("开始收音（演示）", id: "v38.aiux.action.startListening") {
                tryAdvance(to: .listening)
            }
        }
    }

    private var listeningBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.variableColor.iterative, isActive: !reduceMotion)
                Text("正在听…（演示：未开启真实麦克风）")
                    .font(.subheadline)
            }
            HStack(spacing: 12) {
                demoButton("识别到输入 → 思考", id: "v38.aiux.action.inputCaptured") {
                    tryAdvance(to: .thinking)
                }
                demoButton("取消", style: .secondary, id: "v38.aiux.action.cancelListening") {
                    tryAdvance(to: .idle)
                }
            }
        }
    }

    private var thinkingBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // 系统原生 loading 样式（不引入 ThinkingOrbsKit：它只在真实 AI 处理态播放）。
                ProgressView()
                    .accessibilityIdentifier("v38.aiux.thinking.progress")
                Text("小掌柜正在整理…（演示：未调用真实 AI）")
                    .font(.subheadline)
            }
            HStack(spacing: 12) {
                demoButton("产出草稿", id: "v38.aiux.action.draftReady") {
                    tryAdvance(to: .draftPreview)
                }
                demoButton("模拟失败", style: .secondary, id: "v38.aiux.action.thinkFailed") {
                    tryAdvance(to: .failed)
                }
            }
        }
    }

    private var draftPreviewBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            draftCard
            HStack(spacing: 12) {
                demoButton("内容无误 → 等待确认", id: "v38.aiux.action.requestConfirmation") {
                    tryAdvance(to: .awaitingConfirmation)
                }
                demoButton("重新生成", style: .secondary, id: "v38.aiux.action.regenerate") {
                    tryAdvance(to: .thinking)
                }
            }
            demoButton("放弃草稿", style: .secondary, id: "v38.aiux.action.discardDraft") {
                tryAdvance(to: .idle)
            }
        }
    }

    private var awaitingConfirmationBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            draftCard
            Label("只有你点「确认写入」，才会进入执行；未确认绝不写入。", systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                demoButton("确认写入", style: .primary, id: "v38.aiux.action.confirm") {
                    tryAdvance(to: .executing)
                }
                demoButton("取消（保留草稿）", style: .secondary, id: "v38.aiux.action.cancelKeepDraft") {
                    tryAdvance(to: .draftPreview)
                }
            }
        }
    }

    private var executingBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProgressView()
                    .accessibilityIdentifier("v38.aiux.executing.progress")
                Text("正在写入…落库回读确认中（演示：未真实写入）")
                    .font(.subheadline)
            }
            ProgressView(value: 0.6)
                .accessibilityHidden(true)
            HStack(spacing: 12) {
                demoButton("回读成功", id: "v38.aiux.action.writeSucceeded") {
                    tryAdvance(to: .verified)
                }
                demoButton("写入失败", style: .secondary, id: "v38.aiux.action.writeFailed") {
                    tryAdvance(to: .failed)
                }
            }
        }
    }

    private var verifiedBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("落库回读已确认（演示：未真实写库）", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
            demoButton("完成，回到静置", id: "v38.aiux.action.acknowledge") {
                tryAdvance(to: .idle)
            }
        }
    }

    private var failedBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("操作失败（演示）。草稿已保留，可重试；失败不会直接变成“已确认”。", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
            HStack(spacing: 12) {
                demoButton("重试（保留草稿）", style: .primary, id: "v38.aiux.action.retry") {
                    tryAdvance(to: .draftPreview)
                }
                demoButton("关闭", style: .secondary, id: "v38.aiux.action.dismissFailed") {
                    tryAdvance(to: .idle)
                }
            }
        }
    }

    private var draftCard: some View {
        let draft = machine.draft ?? .placeholder
        return VStack(alignment: .leading, spacing: 6) {
            Text(draft.title).font(.subheadline).bold()
            HStack(alignment: .top, spacing: 8) {
                Text("改前").font(.caption).foregroundStyle(.secondary).frame(width: 32, alignment: .leading)
                Text(draft.beforeText).font(.footnote).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 8) {
                Text("改后").font(.caption).foregroundStyle(Color.accentColor).frame(width: 32, alignment: .leading)
                Text(draft.afterText).font(.footnote)
            }
            if let note = draft.note {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("v38.aiux.draft.card")
    }

    private var footer: some View {
        Text("隔离演示组件 · 不调真实 AI · 不写库 · 不删数据")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    // MARK: - Demo helpers（仅内存状态机推进）

    private enum DemoButtonStyle { case primary, secondary }

    @ViewBuilder
    private func demoButton(_ title: String, style: DemoButtonStyle = .primary, id: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .tint(style == .primary ? .accentColor : .gray)
            .controlSize(.small)
            .accessibilityIdentifier(id)
    }

    private func tryAdvance(to next: V38AIOperationState) {
        // 演示按钮只提供合法转换；若状态机拒绝则保持原态（展示层不崩溃）。
        try? machine.advance(to: next)
    }
}

// MARK: - 八态演示容器（Debug-only，截图/预览用）

/// 一次展示八个状态的卡片，仅用于 Xcode Preview 与 CI 截图演示。
/// 不接入 RootView，不触碰任何生产文件。
struct V38AIStatesDemoView: View {
    @State private var machines: [V38AIOperationMachine] = V38AIOperationState.allCases.map { state in
        // 为每个态构造一个可达的演示机：按合法路径推进到目标态。
        var m = V38AIOperationMachine()
        let path: [V38AIOperationState]
        switch state {
        case .idle: path = []
        case .listening: path = [.listening]
        case .thinking: path = [.listening, .thinking]
        case .draftPreview: path = [.listening, .thinking, .draftPreview]
        case .awaitingConfirmation: path = [.listening, .thinking, .draftPreview, .awaitingConfirmation]
        case .executing: path = [.listening, .thinking, .draftPreview, .awaitingConfirmation, .executing]
        case .verified: path = [.listening, .thinking, .draftPreview, .awaitingConfirmation, .executing, .verified]
        case .failed: path = [.listening, .thinking, .failed]
        }
        for step in path { try? m.advance(to: step) }
        return m
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("V3.8 · AI 操作状态（只读演示）")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("八态展示 · 纯本地状态机 · 不调真实 AI、不写库")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(0..<machines.count, id: \.self) { index in
                    V38AIOperationCardView(machine: $machines[index])
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("AI 状态演示")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("V38 AI States / Light") {
    NavigationStack { V38AIStatesDemoView() }
        .preferredColorScheme(.light)
}

#Preview("V38 AI States / Dark") {
    NavigationStack { V38AIStatesDemoView() }
        .preferredColorScheme(.dark)
}

#endif
