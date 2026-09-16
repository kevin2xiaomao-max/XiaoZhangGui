import Foundation
import Observation

// MARK: - V3.3 Lite · 小掌柜短语音（单事项，复用现有 SpeechService）
//
// Foundation 只做「入口 + 链路接缝」：
// - 复用现有 SpeechService（zh-CN、3 秒静音自动收尾），不重写语音识别；
// - 一次语音只识别一个主要事项（5~15 秒短语音）；
// - final transcript 与文字输入走完全相同的 AgentCore.send 流程；
// - rawTranscript 必须保留：识别失败 / 为空也不丢，用户可改写重发；
// - 不做长语音、分段合并、Multi Intent（全部 V3.4）。
// 真机 Capture Audit（5s / 停顿 / 中断等）是 V3.4 长语音前的独立闸门，不在本轮。

enum ShortVoicePhase: Equatable {
    case idle
    case listening
    /// 已拿到 final，等待 Agent 处理
    case finalizing
    /// 失败：associated value 为提示语；rawTranscript 仍保留在 lastRawTranscript
    case failed(String)
}

@MainActor
@Observable
final class ShortVoiceSession {
    private(set) var phase: ShortVoicePhase = .idle
    /// 实时转写
    private(set) var liveTranscript: String = ""
    /// 最近一次 final 原文（无论成功失败都保留）
    private(set) var lastRawTranscript: String = ""

    private let speech = SpeechService()

    var isAvailable: Bool { speech.isRecognizerInitialized }
    var availabilityHint: String {
        speech.isRecognitionAvailable ? "" : "当前设备未提供系统语音识别服务"
    }

    /// 开始聆听；onFinal 在主线程回调 final 原文，由 ViewModel 送入 AgentCore。
    func start(onFinal: @escaping @MainActor (String) -> Void) {
        guard speech.isRecognizerInitialized else {
            phase = .failed("当前设备不可用语音识别，可直接打字")
            return
        }
        liveTranscript = ""
        Task { @MainActor [weak self] in
            guard let self else { return }
            let granted = await self.speech.requestPermissions()
            guard granted else {
                self.phase = .failed("麦克风 / 语音识别权限被拒绝，可在系统设置中开启")
                return
            }
            do {
                try self.speech.start(
                    partialHandler: { [weak self] partial in
                        Task { @MainActor in
                            guard let self else { return }
                            self.liveTranscript = partial
                            if self.phase == .idle || self.phase == .finalizing {
                                self.phase = .listening
                            }
                        }
                    },
                    finalHandler: { [weak self] final in
                        Task { @MainActor in
                            guard let self else { return }
                            let trimmed = final.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.lastRawTranscript = trimmed
                            guard !trimmed.isEmpty else {
                                self.phase = .failed("没有听清，请再试一次；也可以直接打字")
                                return
                            }
                            self.phase = .finalizing
                            onFinal(trimmed)
                        }
                    },
                    errorHandler: { [weak self] error in
                        Task { @MainActor in
                            guard let self else { return }
                            // 失败不丢已识别的 partial 原文
                            if self.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                                self.lastRawTranscript = self.liveTranscript
                            }
                            self.phase = .failed(Self.describe(error))
                        }
                    }
                )
                self.phase = .listening
            } catch {
                self.phase = .failed(Self.describe(error))
            }
        }
    }

    /// 手动停止，等待 final
    func stop() {
        speech.stop()
    }

    /// 取消本次聆听
    func cancel() {
        speech.cancel()
        liveTranscript = ""
        phase = .idle
    }

    /// 结束一轮（Agent 已接收 / 用户关闭错误后）
    func finish() {
        liveTranscript = ""
        phase = .idle
    }

    /// 把保留的原文交回输入框（失败后改写重发）
    func consumeRetainedTranscript() -> String {
        let text = lastRawTranscript
        lastRawTranscript = ""
        return text
    }

    /// 错误文案映射放在 AI 层本地完成，不改动既有 SpeechService（复用而非扩展）。
    private static func describe(_ error: Error) -> String {
        if let speechError = error as? SpeechService.SpeechError {
            return speechError.errorDescription ?? "语音识别失败"
        }
        return "语音识别失败，可重试或直接打字：\(error.localizedDescription)"
    }
}
