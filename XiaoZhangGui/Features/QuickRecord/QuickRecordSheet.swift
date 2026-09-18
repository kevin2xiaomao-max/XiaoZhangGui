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

/// 保存闸门：唯一条件是「trim 后非空」。类型识别结果不参与能否保存的判断。
enum QuickRecordSavePolicy {
    static func canSave(_ rawText: String) -> Bool {
        !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct QuickRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var text = ""
    @State private var parsedDraft: QuickRecordDraft?
    /// 用户手动改类型时覆盖自动识别；重新输入后回到自动识别。
    @State private var overriddenKind: QuickRecordKind?
    @State private var savedMessage: String?
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if voice.status != .idle {
                    voiceCard
                }
                inputCard
                if let draft = currentDraft {
                    resultCard(draft)
                }
                if let savedMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(V32.brand)
                        Text(savedMessage).v32Text(.body).foregroundStyle(V32.textSecondary)
                    }
                }
                V32PrimaryButton(title: "保存", systemName: "checkmark.circle.fill") { commit() }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                    .accessibilityHint(canSave ? "" : "说一句话或输入内容后即可保存")
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 14)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32Sheet([.medium, .large])
        .onAppear { autoStartListening() }
        .onDisappear { voice.cancel() }
        .onChange(of: text) { _, newValue in
            overriddenKind = nil
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            parsedDraft = trimmed.isEmpty ? nil : parser.parse(trimmed)
        }
        .onChange(of: voice.liveTranscript) { _, newValue in
            if voice.isListening, !newValue.isEmpty {
                text = newValue
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("快速记录").v32Text(.headline).foregroundStyle(V32.textPrimary)
            HStack {
                Button("取消") { dismiss() }
                    .v32Text(.body)
                    .foregroundStyle(V32.textTertiary)
                Spacer()
            }
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                V32SectionHeader("一句话")
                Spacer(minLength: 8)
                micButton
            }
            V32Card {
                TextField("例如：今天美团680", text: $text, axis: .vertical)
                    .v32Text(.body)
                    .foregroundStyle(V32.textPrimary)
                    .tint(V32.brand)
                    .lineLimit(3...6)
            }
            Text("本地规则识别，不经过 AI、不需要 API Key；识别不了的内容也会存为备忘。")
                .v32Text(.caption)
                .foregroundStyle(V32.textTertiary)
        }
    }

    // MARK: 语音

    /// 首页麦克风进入：能初始化系统识别器就直接听；不可用时安静退化为键盘输入。
    private func autoStartListening() {
        guard voice.status == .idle, voice.canUseSpeech else { return }
        voice.start { final in
            text = final
        }
    }

    private func toggleVoice() {
        if voice.isListening {
            voice.stop()
        } else {
            voice.start { final in
                text = final
            }
        }
    }

    private var micButton: some View {
        Button(action: toggleVoice) {
            Image(systemName: voice.isListening ? "stop.fill" : "mic.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(voice.isListening ? .white : V32.brand)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(voice.isListening ? V32.brand : V32.brandSoft)
                )
                .scaleEffect(reduceMotion || !voice.isListening ? 1 : 1.06)
                .animation(
                    reduceMotion ? nil : V32Motion.softSpring.repeatForever(autoreverses: true),
                    value: voice.isListening
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voice.isListening ? "停止语音输入" : "语音说一句")
    }

    private var voiceCard: some View {
        V32Card {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(V32.brandSoft)
                        .frame(width: 40, height: 40)
                    Image(systemName: voice.isListening ? "mic.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(voice.isListening ? V32.brand : V32.amber)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(voiceStatusTitle)
                        .v32Text(.subhead)
                        .foregroundStyle(V32.textPrimary)
                    if voice.isListening {
                        Text(voice.liveTranscript.isEmpty ? "停顿后会自动结束，也可点方块手动停止" : voice.liveTranscript)
                            .v32Text(.caption)
                            .foregroundStyle(V32.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if voice.isListening {
                    Button {
                        voice.cancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(V32.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(V32.neutralSoft))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("取消语音")
                }
            }
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

    private func resultCard(_ draft: QuickRecordDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("识别结果")
            V32Card {
                VStack(spacing: 0) {
                    kindRow(draft)
                    divider
                    resultRow("内容", value: draft.note)
                    if let amount = draft.amount {
                        divider
                        resultRow("金额", value: Fmt.money(amount))
                    }
                    if let date = draft.date {
                        divider
                        resultRow("时间", value: Fmt.dateTime(date))
                    }
                }
            }
        }
    }

    /// 类型行：自动识别为主，用户可随时手动改类型（次入口）
    private func kindRow(_ draft: QuickRecordDraft) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("类型").v32Text(.subhead).foregroundStyle(V32.textTertiary)
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
                        .v32Text(.body)
                        .foregroundStyle(V32.textPrimary)
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(V32.textTertiary)
                }
            }
            .accessibilityLabel("改类型，当前：\(kindLabel(draft.kind))")
        }
        .padding(.vertical, 10)
    }

    private func resultRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).v32Text(.subhead).foregroundStyle(V32.textTertiary)
            Spacer(minLength: 12)
            Text(value).v32Text(.body).foregroundStyle(V32.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle().fill(V32.divider).frame(height: 1)
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
            savedMessage = "已保存：\(kindLabel(draft.kind))"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
        } catch {
            Haptic.error()
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
