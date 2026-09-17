import SwiftUI

// MARK: - 小掌柜独立 AI 页（V3.3 第三个 Tab）
//
// Foundation：全 Mock，可完成文字 Chat、短语音入口、四个 CREATE 的 ActionCard 预览；
// 确认不写业务库。UI 全程沿用 V32 设计系统 / ThemeStore / 壁纸，不另造视觉体系。

struct AIChatView: View {
    /// 由 RootView 通过 xzg://ai?mode=voice 置位，触发短语音面板
    var voiceDeepLink: Binding<Bool>?

    @State private var model = AIConversationViewModel()
    @State private var showSettings = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let examples = [
        "今天美团680",
        "明天下两箱可乐",
        "记一下供应商周五来",
        "今晚8点给302送两箱怡宝"
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            V32PageHeader("小掌柜", subtitle: "说句话，帮你记账、派单、备忘") {
                                HStack(spacing: 8) {
                                    V32StatusPill(
                                        text: model.isRemoteConfigured ? "正式版" : "未配置",
                                        status: model.isRemoteConfigured ? .delivering : .expiry)
                                    Button {
                                        showSettings = true
                                    } label: {
                                        Image(systemName: "gearshape")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(V32.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("AI 设置")
                                }
                            }
                            if model.messages.isEmpty {
                                emptyState
                            } else {
                                ForEach(model.messages) { message in
                                    messageRow(message)
                                }
                                if model.isProcessing {
                                    TypingIndicator()
                                        .padding(.top, 2)
                                }
                                Color.clear.frame(height: 8).id("bottom-anchor")
                            }
                        }
                        .padding(.horizontal, V32Layout.pageMargin)
                        .padding(.top, 8)
                        .padding(.bottom, V32Layout.pageBottomBreathing)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: model.messages.count) { _, _ in scrollToBottom(proxy) }
                    .onChange(of: model.isProcessing) { _, processing in
                        if processing { scrollToBottom(proxy) }
                    }
                    .onAppear { scrollToBottom(proxy) }
                }
            }
            .v32PageBackground()
            .safeAreaInset(edge: .bottom) {
                ChatInputBar(
                    text: $model.input,
                    voiceAvailable: model.voiceAvailable,
                    isProcessing: model.isProcessing,
                    onSend: { model.send() },
                    onVoice: { model.startVoice() }
                )
            }
            .toolbar(.hidden, for: .navigationBar)

            if model.showVoicePanel {
                voiceOverlay
            }
        }
        .onChange(of: voiceDeepLink?.wrappedValue ?? false) { _, triggered in
            if triggered {
                model.startVoice()
                voiceDeepLink?.wrappedValue = false
            }
        }
        // 由 AI 目录外的桥接修饰符注入 live Agent（真实 Provider / Repository 执行器）；
        // 本文件不 import SwiftData，ModelContext 不出 Integration 层。
        .aiAttachLive { liveAgent in
            model.attach(live: liveAgent)
        }
        .sheet(isPresented: $showSettings) {
            AIProviderSettingsSheet()
        }
    }

    // MARK: 空态 + 范例

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            V32EmptyState(
                systemName: "sparkles",
                title: "我是小掌柜",
                message: "说句话或点个例子，我先整理成确认卡，你确认后才记录。"
            )
            V32Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("试试这样说")
                        .v32Text(.section)
                        .foregroundStyle(V32.textPrimary)
                    ForEach(examples, id: \.self) { example in
                        Button {
                            model.send(example)
                        } label: {
                            HStack {
                                Image(systemName: "text.bubble")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(V32.brand)
                                Text(example)
                                    .v32Text(.body)
                                    .foregroundStyle(V32.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(V32.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: 消息行

    @ViewBuilder
    private func messageRow(_ message: AIMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            bubble(message)
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if let proposalID = message.proposalID,
               let proposal = model.proposals[proposalID] {
                ActionCardView(
                    proposal: proposal,
                    onConfirm: { model.confirm(proposalID) },
                    onModify: { model.modifyCard(proposalID) },
                    onCancel: { model.cancelCard(proposalID) }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func bubble(_ message: AIMessage) -> some View {
        if message.role == .user {
            Text(message.content)
                .v32Text(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(V32.brand)
                )
                .frame(maxWidth: 300, alignment: .trailing)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(message.content)
                    .v32Text(.body)
                    .foregroundStyle(message.isError ? V32.danger : V32.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if message.isError {
                    Button {
                        model.retryLastFailed()
                    } label: {
                        Label("重试", systemImage: "arrow.clockwise")
                            .v32Text(.caption)
                            .foregroundStyle(V32.brand)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(message.isError ? V32.dangerSoft : V32.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(V32.cardOutline, lineWidth: 1)
                    )
            )
            .frame(maxWidth: 320, alignment: .leading)
        }
    }

    // MARK: 语音覆盖层

    private var voiceOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { model.cancelVoice() }
            ShortVoicePanel(
                phase: model.voicePhase,
                liveTranscript: model.liveTranscript,
                onStop: { model.stopVoice() },
                onCancel: { model.cancelVoice() },
                onEditText: { model.retainVoiceTranscriptToInput() }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .animation(V32Motion.standard, value: model.showVoicePanel)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : V32Motion.quick) {
            proxy.scrollTo("bottom-anchor", anchor: .bottom)
        }
    }
}
