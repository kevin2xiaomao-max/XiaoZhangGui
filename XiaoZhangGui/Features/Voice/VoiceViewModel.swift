import Foundation
import SwiftData
import Observation

// MARK: - 语音页 ViewModel（View → ViewModel → Repository → SwiftData）

@Observable
final class VoiceViewModel {
    private(set) var phase: VoicePhase = .idle
    /// 实时识别文字（聆听过程的主要视觉内容）
    private(set) var transcript = ""
    private(set) var draft: VoiceDraft?
    /// 预览阶段可切换的记录类型
    var recordType: VoiceRecordType {
        get { draft?.type ?? .todo }
        set { draft?.type = newValue }
    }

    var speechAvailableHint: String {
        speech.isRecognitionAvailable ? "" : "当前设备未提供系统语音识别服务"
    }

    var isSpeechRecognizerInitialized: Bool {
        speech.isRecognizerInitialized
    }

    private let speech = SpeechService()
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - 流程

    /// 点击麦克风：请求权限 → 开始识别
    func beginListening() {
        // 模拟器可能无法初始化 SFSpeechRecognizer。此时由 UI 隐藏麦克风，这里静默返回。
        guard speech.isRecognizerInitialized else { return }
        transcript = ""
        draft = nil
        Task { @MainActor in
            let granted = await speech.requestPermissions()
            guard granted else {
                phase = .error("麦克风/语音识别权限被拒绝")
                return
            }
            do {
                try speech.start(
                    partialHandler: { [weak self] partial in
                        Task { @MainActor in
                            guard let self else { return }
                            self.transcript = partial
                            if self.phase == .idle || self.phase == .recognized {
                                self.phase = .listening
                            }
                        }
                    },
                    finalHandler: { [weak self] final in
                        Task { @MainActor in
                            self?.handleRecognized(final)
                        }
                    },
                    errorHandler: { [weak self] error in
                        Task { @MainActor in
                            guard let self else { return }
                            self.phase = .error(SpeechService.mapError(error))
                        }
                    }
                )
                phase = .listening
            } catch {
                phase = .error(SpeechService.mapError(error))
            }
        }
    }

    /// 手动停止录音，等待最终识别结果
    func stopListening() {
        speech.stop()
        phase = .recognized
    }

    /// 识别完成 → 解析 → 预览
    func handleRecognized(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .error("没有听清，请再试一次")
            return
        }
        guard !VoiceParser.isUnsupportedQuery(trimmed) else {
            transcript = trimmed
            phase = .error("没有听清，请再试一次")
            return
        }
        transcript = trimmed
        phase = .parsing
        draft = VoiceParser.parse(trimmed)
        phase = .preview
    }

    /// TextFallback：手动输入文本走同一解析链路
    func submitManualText(_ text: String) {
        speech.cancel()
        handleRecognized(text)
    }

    /// 进入手动输入
    func enterTextFallback() {
        speech.cancel()
        phase = .textFallback
    }

    /// 保存草稿（真实写库；金额缺失等错误直接报给用户）
    func save() {
        guard let draft else { return }
        phase = .saving
        do {
            switch draft.type {
            case .revenue:
                guard let amount = draft.amount, amount > 0 else {
                    phase = .error("请补充收入金额")
                    return
                }
                try PerformanceRepository(context: context).add(amount: amount, note: "语音记录", date: Date())
            case .expense:
                guard let amount = draft.amount, amount > 0 else {
                    phase = .error("请补充支出金额")
                    return
                }
                let category = draft.original.contains("进货") ? "进货" : "其他"
                try ExpenseRepository(context: context).add(amount: amount, category: category, note: draft.original, date: Date())
            case .expiry:
                let days = draft.expiryDays ?? 7
                try ExpiryRepository(context: context).add(
                    name: draft.title,
                    quantity: 1,
                    expiryDate: Date().addingTimeInterval(Double(days) * 86400),
                    remindDaysBefore: 7,
                    note: "语音记录"
                )
            case .memo:
                try MemoRepository(context: context).add(title: draft.title, content: draft.original)
            case .customer:
                try CustomerRepository(context: context).add(
                    customer: draft.customerName ?? "客户",
                    roomOrAddress: "",
                    phone: "",
                    content: draft.goodsName.map { "\($0) × \(draft.quantity ?? 1)" } ?? draft.original
                )
            case .todo:
                try TodoRepository(context: context).add(
                    title: draft.title,
                    detail: draft.original,
                    dueDate: draft.dueAt,
                    priority: 0
                )
            }
            Haptic.success()
            phase = .idle
            didSave = true
        } catch {
            phase = .error("保存失败，请稍后再试")
        }
    }

    /// 保存成功后由 View 延迟关闭
    var didSave: Bool = false

    /// 回到初始状态
    func reset() {
        speech.cancel()
        transcript = ""
        draft = nil
        didSave = false
        phase = .idle
    }
}

// MARK: - 错误文案（对齐 Android errorMessage）

extension SpeechService {
    static func mapError(_ error: Error) -> String {
        "没有听清，请再试一次"
    }
}
