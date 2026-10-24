import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - 小掌柜独立 AI 页（V3.7.1 Presentation 重构）
//
// 执行语义原样保留：只换 UI。Agent / Provider / Repository 全部在
// AIConversationViewModel 与 Integration 层，本文件只做展示。
//
// V371 视觉：S0 conversation canvas、assistant/user 消息层级、
// ActionCard 用 Grouped Surface、input bar 紧凑 keyboard-safe。

struct AIChatView: View {
    /// 由 RootView 通过 xzg://ai?mode=voice 置位，触发短语音面板
    var voiceDeepLink: Binding<Bool>?

    @State private var model = AIConversationViewModel()
    @State private var showSettings = false
    @State private var showClearConfirm = false
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showFileImporter = false
    // V3.9.2：图片整张外发前的二次确认（图片里常有客户姓名、电话、单据金额）。
    @State private var showImageConsent = false
    @State private var pendingImageData: Data?
    @State private var pendingImageMimeType = "image/jpeg"
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
                            headerBlock
                            // V3.7.1 修复：`model.messages` 在请求进行期间仍是旧值
                            // （要等 refresh() 之后才写入本轮用户消息）。若只按
                            // `messages.isEmpty` 判断，会话第一条消息处理期间会一直显示
                            // emptyState，ThinkingOrbs 思考态根本不会出现。
                            // 这里把「正在处理」也纳入 else 分支条件，保证
                            // 「AI 开始实际处理时显示」在首条消息同样成立。
                            if model.messages.isEmpty && !model.isProcessing {
                                emptyState
                            } else {
                                ForEach(model.messages) { message in
                                    messageRow(message)
                                }
                                if model.isProcessing {
                                    TypingIndicator(label: model.processingLabel)
                                        .padding(.top, 2)
                                }
                                Color.clear.frame(height: 8).id("bottom-anchor")
                            }
                        }
                        .padding(.horizontal, V371.Space.page)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: model.messages.count) { _, _ in scrollToBottom(proxy) }
                    .onChange(of: model.isProcessing) { _, processing in
                        if processing { scrollToBottom(proxy) }
                    }
                    .onAppear { scrollToBottom(proxy) }
                }
            }
            .v371Canvas()
            .safeAreaInset(edge: .bottom) {
                ChatInputBar(
                    text: $model.input,
                    voiceAvailable: model.voiceAvailable,
                    isProcessing: model.isProcessing,
                    onSend: { model.send() },
                    onVoice: { model.startVoice() },
                    onPhoto: { showPhotoPicker = true },
                    onFile: { showFileImporter = true }
                )
            }
            .navigationTitle("小掌柜")
            .navigationBarTitleDisplayMode(.inline)

            if model.showVoicePanel {
                voiceOverlay
            }
        }
        // 容器 identifier 会向下覆盖子控件：用 children: .contain 保留子元素独立标识，
        // 同时容器本身仍可通过 sheet.ai 定位（诊断 37783082341 证实覆盖问题）。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(V371AccessibilityID.sheetAI)
        // 注意：禁止在此处复写 tabBar 可见性（V3.6.1 已证实的禁区）：
        // V3.7.1 系统 TabBar 由 RootView 在 TabView 级别统一隐藏，
        // 短语音面板展示期间底部安全区已天然完整，无需此处再隐藏。
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showClearConfirm = true } label: {
                        Label("新对话", systemImage: "square.and.pencil")
                    }
                    Button(role: .destructive) { showClearConfirm = true } label: {
                        Label("清空当前对话", systemImage: "trash")
                    }
                    Divider()
                    Button { showSettings = true } label: {
                        Label("AI 设置", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("对话菜单")
                .accessibilityIdentifier("ai.menu")
            }
        }
        .animation(V371.Motion.animation(V371.Motion.resolve(.spring, reduceMotion: reduceMotion)),
                   value: model.showVoicePanel)
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
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            let mimeType = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    // 默认先问一句：图片会整张上传，误选一次就收不回来。
                    if AISettings.shared.imageUploadNeedsConfirmation {
                        pendingImageData = data
                        pendingImageMimeType = mimeType
                        showImageConsent = true
                    } else {
                        model.analyzeImage(data: data, mimeType: mimeType)
                    }
                }
                selectedPhoto = nil
            }
        }
        .confirmationDialog(
            "把这张图片发给 AI 分析？",
            isPresented: $showImageConsent,
            titleVisibility: .visible
        ) {
            Button("发送") { sendPendingImage(rememberChoice: false) }
            Button("以后直接发送") { sendPendingImage(rememberChoice: true) }
            Button("取消", role: .cancel) { clearPendingImage() }
        } message: {
            Text("图片会整张上传给你配置的 AI 服务。请勿发送证件、银行卡、客户身份证等敏感照片。")
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .plainText, .text, UTType(filenameExtension: "md") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
                ?? "application/octet-stream"
            model.analyzeDocument(data: data, fileName: url.lastPathComponent, mimeType: mimeType)
        }
        .alert("清空此对话？", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { model.clearConversation() }
        } message: {
            Text("只删除聊天记录，不会删除已经保存的营业额、待办、备忘或配送记录。")
        }
    }

    // MARK: 图片外发确认

    private func sendPendingImage(rememberChoice: Bool) {
        if rememberChoice {
            // 记住「以后直接发送」；想改回来去「AI 设置 → 图片与文件」。
            AISettings.shared.imageUploadNeedsConfirmation = false
        }
        if let data = pendingImageData {
            model.analyzeImage(data: data, mimeType: pendingImageMimeType)
        }
        clearPendingImage()
    }

    private func clearPendingImage() {
        pendingImageData = nil
        showImageConsent = false
    }

    // MARK: 头部说明

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("说句话，帮你记账、派单、备忘")
                .font(.subheadline)
                .foregroundStyle(V371.Colors.textSecondary)
            HStack(spacing: 8) {
                StatusBadge(
                    model.isRemoteConfigured ? "Key 已保存" : "本地模式",
                    color: model.isRemoteConfigured ? V371.Colors.green : V371.Colors.gray
                )
                if DemoMode.shared.isEnabled {
                    StatusBadge("演示模式", color: V371.Colors.orange)
                }
            }
            if !model.isRemoteConfigured {
                Text("本地查询与记录可直接使用；联网 AI 需在设置中配置。")
                    .font(.footnote)
                    .foregroundStyle(V371.Colors.textSecondary)
            }
        }
    }

    // MARK: 空态 + 范例

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Label("我是小掌柜", systemImage: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(V371.Colors.textPrimary)
                Text("说句话或点个例子，我先整理成确认卡，你确认后才记录。")
                    .font(.subheadline)
                    .foregroundStyle(V371.Colors.textSecondary)
            }
            GroupSurface {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader("试试这样说")
                        .padding(.horizontal, V371.Space.rowPadding)
                        .padding(.top, V371.Space.rowPadding)
                        .padding(.bottom, 4)
                    ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                        if index > 0 { V371Divider() }
                        WorkRow(icon: "text.bubble", title: example) {
                            model.send(example)
                        } trailing: {
                            V371Chevron()
                        }
                    }
                    Color.clear.frame(height: 6)
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
                .transition(.opacity.combined(with: reduceMotion ? .identity : .move(edge: .bottom)))

            if let proposalID = message.proposalID,
               let proposal = model.proposals[proposalID] {
                ActionCardView(
                    proposal: proposal,
                    onConfirm: { model.confirm(proposalID) },
                    onModify: { model.modifyCard(proposalID) },
                    onCancel: { model.cancelCard(proposalID) }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: reduceMotion ? .identity : .move(edge: .bottom)))
            }
        }
    }

    @ViewBuilder
    private func bubble(_ message: AIMessage) -> some View {
        if message.role == .user {
            Text(message.content)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: V371.Radius.tile, style: .continuous)
                        .fill(V371.Colors.blue)
                )
                .frame(maxWidth: 300, alignment: .trailing)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                assistantMarkdown(message.content, color: message.isError ? V371.Colors.red : V371.Colors.textPrimary)
                if message.isError {
                    Button {
                        Haptic.light()
                        model.retryLastFailed()
                    } label: {
                        Label("重试", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(V371.Colors.blue)
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: V371.Radius.tile, style: .continuous)
                    .fill(V371.Colors.group)
                    .overlay(
                        RoundedRectangle(cornerRadius: V371.Radius.tile, style: .continuous)
                            .strokeBorder(V371.Colors.divider, lineWidth: 1)
                    )
            )
            .frame(maxWidth: 320, alignment: .leading)
            .accessibilityIdentifier(message.role == .assistant ? "ai.message.assistant" : "ai.message.user")
        }
    }

    @ViewBuilder
    private func assistantMarkdown(_ content: String, color: Color) -> some View {
        if let markdown = try? AttributedString(markdown: content) {
            Text(markdown)
                .font(.body)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(content)
                .font(.body)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: 语音覆盖层

    private var voiceOverlay: some View {
        // 遮罩自身忽略安全区铺满全屏；面板容器不忽略底部安全区，
        // 按钮避开 Home Indicator（Dock 隐藏后由外层安全区兜底）。
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
            .transition(.opacity.combined(with: reduceMotion ? .identity : .move(edge: .bottom)))
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : V371.Motion.fast) {
            proxy.scrollTo("bottom-anchor", anchor: .bottom)
        }
    }
}
