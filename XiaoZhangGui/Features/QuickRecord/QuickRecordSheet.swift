import SwiftUI
import SwiftData
import Observation

// MARK: - 快速记录（Local First）
//
// V3.3 真机 hotfix：
// - 首页麦克风进入，弹出即听，停顿 3 秒自动结束（复用 SpeechService，不重写识别）；
// - 语音转写与手动输入走同一个 LocalQuickRecordParser；
// - 只要 trim 后非空就一定能保存，无法识别的句子由 parser 兜底为「备忘」；
// - 全程本地规则，不调用远程 AI、不需要 API Key；
// - 保存仍走各现有 Repository，不新增写入路径。
// - 监听期间唯一麦克风视觉入口是监听状态卡（头部麦克风整体不渲染），
//   停止 / 取消都在状态卡内；全程静态样式，无 repeatForever 脉冲动画。
//
// V3.7.1：仅 presentation 重构（NavigationStack + toolbar、SectionHeader、
// GroupSurface + 行内 hairline、V371 按钮样式）。解析、语义、写入逻辑原样不动。

/// 保存闸门：唯一条件是「trim 后非空」。类型识别结果不参与能否保存的判断。
enum QuickRecordSavePolicy {
    static func canSave(_ rawText: String) -> Bool {
        !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct QuickRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var text = ""
    @State private var parsedDraft: QuickRecordDraft?
    /// 用户手动改类型时覆盖自动识别；重新输入后回到自动识别。
    @State private var overriddenKind: QuickRecordKind?
    @State private var savedMessage: String?
    @State private var errorMessage: String?
    @State private var voice = QuickRecordVoiceRecorder()

    private let parser = LocalQuickRecordParser()

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { QuickRecordSavePolicy.canSave(text) }

    private var currentDraft: QuickRecordDraft? {
        guard canSave else { return nil }
        var draft = parsedDraft ?? parser.parse(trimmedText)
        if let overriddenKind { draft.kind = overriddenKind }
        return draft
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: V371.Space.section) {
                    SectionHeader("一句话") {
                        // 监听期间头部麦克风按钮整体不渲染：唯一麦克风入口是监听状态卡。
                        if !voice.isListening {
                            micButton
                        }
                    }
                    inputGroup
                    if voice.status != .idle {
                        voiceCard
                    }
                    if let draft = currentDraft {
                        SectionHeader("识别结果")
                        resultGroup(draft)
                    }
                    statusViews
                    saveButton
                }
                .padding(.horizontal, V371.Space.page)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("快速记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .v371Canvas()
        .onAppear { autoStartListening() }
        .onDisappear { voice.cancel() }
        .onChange(of: text) { _, newValue in
            overriddenKind = nil
            errorMessage = nil
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            parsedDraft = trimmed.isEmpty ? nil : parser.parse(trimmed)
        }
        .onChange(of: voice.liveTranscript) { _, newValue in
            if voice.isListening, !newValue.isEmpty {
                text = newValue
            }
        }
    }

    private var inputGroup: some View {
        GroupSurface {
            VStack(alignment: .leading, spacing: 10) {
                TextField("例如：今天美团680", text: $text, axis: .vertical)
                    .font(V371.Typography.rowTitle)
                    .foregroundStyle(V371.Colors.textPrimary)
                    .tint(V371.Colors.blue)
                    .lineLimit(3...6)
                    .frame(minHeight: 64, alignment: .top)
                Text("本地规则识别，不经过 AI、不需要 API Key；识别不了的内容也会存为备忘。")
                    .font(V371.Typography.rowSubtitle)
                    .foregroundStyle(V371.Colors.textTertiary)
            }
            .padding(V371.Space.rowPadding)
        }
    }

    // MARK: 语音

    /// 首页麦克风进入：能初始化系统识别器就直接听；不可用时安静退化为键盘输入。
    private func autoStartListening() {
        guard voice.status == .idle, voice.canUseSpeech else { return }
        startListening()
    }

    private func startListening() {
        voice.start { final in
            text = final
        }
    }

    /// 头部麦克风：只在非监听态出现（监听态由 `if !voice.isListening` 整体不渲染）。
    /// V3.3 静态样式：无 repeatForever 缩放 / 脉冲动画，避免持续跳动与布局抖动。
    private var micButton: some View {
        Button(action: startListening) {
            Image(systemName: "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(V371.Colors.blue)
                .frame(width: 44, height: 44)
                .background(Circle().fill(V371.Colors.tinted(V371.Colors.blue)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("语音说一句")
    }

    private var voiceCard: some View {
        GroupSurface {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(V371.Colors.tinted(V371.Colors.blue))
                        .frame(width: 44, height: 44)
                    Image(systemName: voice.isListening ? "mic.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(voice.isListening ? V371.Colors.blue : V371.Colors.orange)
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(voiceStatusTitle)
                        .font(V371.Typography.rowTitle)
                        .foregroundStyle(V371.Colors.textPrimary)
                    if voice.isListening {
                        Text(voice.liveTranscript.isEmpty ? "停顿后会自动结束，也可停止或取消" : voice.liveTranscript)
                            .font(V371.Typography.rowSubtitle)
                            .foregroundStyle(V371.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if voice.isListening {
                    HStack(spacing: 8) {
                        Button {
                            voice.stop()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(V371.Colors.blue))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("停止语音")
                        Button {
                            voice.cancel()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(V371.Colors.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(V371.Colors.groupSecondary))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("取消语音")
                    }
                }
            }
            .padding(V371.Space.rowPadding)
        }
    }

    private var voiceStatusTitle: String {
        switch voice.status {
        case .idle:
            return ""
        case .listening:
            return voice.liveTranscript.isEmpty ? "正在听…说一件事" : "正在识别"
        case .denied:
            return "麦克风 / 语音识别权限未开启，可直接打字"
        case .empty:
            return "没有听清，可再说一次或直接打字"
        case .failed(let message):
            return message
        }
    }

    // MARK: 识别结果

    private func resultGroup(_ draft: QuickRecordDraft) -> some View {
        GroupSurface {
            VStack(spacing: 0) {
                kindRow(draft)
                V371Divider()
                resultRow("内容", value: draft.note)
                if let amount = draft.amount {
                    V371Divider()
                    resultRow("金额", value: Fmt.money(amount))
                }
                if let date = draft.date {
                    V371Divider()
                    resultRow("时间", value: Fmt.dateTime(date))
                }
            }
        }
    }

    /// 类型行：自动识别为主，用户可随时手动改类型（次入口）
    private func kindRow(_ draft: QuickRecordDraft) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("类型")
                .font(V371.Typography.rowSubtitle)
                .foregroundStyle(V371.Colors.textTertiary)
            Spacer(minLength: 12)
            Menu {
                ForEach(QuickRecordKind.allCases, id: \.self) { kind in
                    Button {
                        overriddenKind = kind
                    } label: {
                        if draft.kind == kind {
                            Label(kindLabel(kind), systemImage: "checkmark")
                        } else {
                            Text(kindLabel(kind))
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(kindLabel(draft.kind))
                        .font(V371.Typography.rowTitle)
                        .foregroundStyle(V371.Colors.textPrimary)
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(V371.Colors.textTertiary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("改类型，当前：\(kindLabel(draft.kind))")
        }
        .padding(.horizontal, V371.Space.rowPadding)
        .padding(.vertical, 10)
    }

    private func resultRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(V371.Typography.rowSubtitle)
                .foregroundStyle(V371.Colors.textTertiary)
            Spacer(minLength: 12)
            Text(value)
                .font(V371.Typography.rowTitle)
                .foregroundStyle(V371.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, V371.Space.rowPadding)
        .padding(.vertical, 10)
        .frame(minHeight: 48)
    }

    private func kindLabel(_ kind: QuickRecordKind) -> String {
        switch kind {
        case .performance: return "营业额"
        case .todo: return "待办"
        case .customer: return "配送"
        case .expiry: return "临时商品"
        case .memo: return "备忘"
        }
    }

    // MARK: 状态与保存

    @ViewBuilder
    private var statusViews: some View {
        if let savedMessage {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(V371.Colors.green)
                Text(savedMessage)
                    .font(V371.Typography.rowSubtitle)
                    .foregroundStyle(V371.Colors.textSecondary)
            }
            .accessibilityElement(children: .combine)
        }
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(V371.Typography.rowSubtitle)
                .foregroundStyle(V371.Colors.red)
        }
    }

    private var saveButton: some View {
        Button {
            commit()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("确认保存")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous)
                    .fill(V371.Colors.blue)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.5)
        .accessibilityHint(canSave ? "" : "说一句话或输入内容后即可保存")
    }

    private func commit() {
        let trimmed = trimmedText
        // 非空是唯一闸门；识别不了时 parser 已兜底为备忘，任何一句话都不会丢。
        guard QuickRecordSavePolicy.canSave(trimmed) else { return }
        var draft = parsedDraft ?? parser.parse(trimmed)
        if let overriddenKind { draft.kind = overriddenKind }
        voice.cancel()
        do {
            switch draft.kind {
            case .performance:
                try PerformanceRepository(context: context).add(
                    amount: draft.amount ?? 0,
                    note: draft.note,
                    date: draft.date ?? Date()
                )
            case .todo:
                try TodoRepository(context: context).add(
                    title: draft.title,
                    detail: "",
                    dueDate: draft.date
                )
            case .customer:
                try CustomerRepository(context: context).add(
                    customer: draft.customer ?? "",
                    roomOrAddress: "",
                    phone: "",
                    content: draft.title
                )
            case .expiry:
                try ExpiryRepository(context: context).add(
                    name: draft.title,
                    quantity: draft.quantity ?? 1,
                    expiryDate: draft.date ?? Date()
                )
            case .memo:
                try MemoRepository(context: context).add(title: draft.title, content: draft.note)
            }
            Haptic.success()
            errorMessage = nil
            savedMessage = QuickCaptureSemantic.savedMessage(destination: kindLabel(draft.kind))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
        } catch {
            Haptic.error()
            errorMessage = QuickCaptureSemantic.failed
        }
    }
}

// MARK: - 快速记录语音（复用 SpeechService；停顿自动结束由 SpeechService 内置 3 秒静音完成）

@MainActor
@Observable
final class QuickRecordVoiceRecorder {
    enum Status: Equatable {
        case idle
        case listening
        case denied
        case empty
        case failed(String)
    }

    private let speech = SpeechService()
    private(set) var status: Status = .idle
    private(set) var liveTranscript = ""

    /// 识别器无法初始化（部分模拟器）时，只保留键盘输入，不展示错误卡。
    var canUseSpeech: Bool { SpeechService.canInitializeRecognizer }
    var isListening: Bool { status == .listening }

    func start(onFinal: @escaping @MainActor (String) -> Void) {
        guard status != .listening else { return }
        liveTranscript = ""
        Task { @MainActor [weak self] in
            guard let self else { return }
            let granted = await self.speech.requestPermissions()
            guard granted else {
                self.status = .denied
                return
            }
            do {
                try self.speech.start(
                    partialHandler: { [weak self] partial in
                        Task { @MainActor in
                            self?.liveTranscript = partial
                        }
                    },
                    finalHandler: { [weak self] final in
                        Task { @MainActor in
                            guard let self else { return }
                            let trimmed = final.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                self.status = .empty
                            } else {
                                self.status = .idle
                                onFinal(trimmed)
                            }
                        }
                    },
                    errorHandler: { [weak self] error in
                        Task { @MainActor in
                            self?.status = .failed(Self.describe(error))
                        }
                    }
                )
                self.status = .listening
            } catch {
                self.status = .failed(Self.describe(error))
            }
        }
    }

    /// 手动停止，等待最终结果
    func stop() {
        speech.stop()
    }

    /// 取消 / 关闭时立即释放麦克风
    func cancel() {
        speech.cancel()
        liveTranscript = ""
        if status == .listening {
            status = .idle
        }
    }

    private static func describe(_ error: Error) -> String {
        if let speechError = error as? SpeechService.SpeechError {
            return speechError.errorDescription ?? "语音识别失败，可直接打字"
        }
        return "语音识别失败，可直接打字：\(error.localizedDescription)"
    }
}
