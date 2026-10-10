import Foundation
import Speech
import AVFoundation
import Observation
import UIKit

// MARK: - 语音识别服务（真实接入 Apple Speech + AVAudioSession）
// 禁止伪造识别结果；识别不可用时由上层进入 TextFallback

struct SpeechStartGate {
    private(set) var token: UUID?

    mutating func begin() -> UUID? {
        guard token == nil else { return nil }
        let value = UUID()
        token = value
        return value
    }

    func isCurrent(_ value: UUID) -> Bool { token == value }
    mutating func end(_ value: UUID? = nil) {
        guard value == nil || token == value else { return }
        token = nil
    }
}

enum SpeechAudioFormatPolicy {
    static func isUsable(sampleRate: Double, channelCount: UInt32) -> Bool {
        sampleRate.isFinite && sampleRate > 0 && channelCount > 0
    }
}

@MainActor
protocol SpeechServicing: AnyObject {
    var isRecognizerInitialized: Bool { get }
    func requestPermissions() async -> Bool
    func start(
        partialHandler: @escaping (String) -> Void,
        finalHandler: @escaping (String) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) throws
    func stop()
    func cancel()
}

@MainActor
@Observable
final class SpeechService {
    enum SpeechError: LocalizedError {
        case notAuthorized
        case notAvailable
        case engineFailure(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "语音识别权限被拒绝"
            case .notAvailable: return "当前设备未提供系统语音识别服务"
            case .engineFailure(let reason): return reason
            }
        }
    }

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceWorkItem: DispatchWorkItem?
    private var tapInstalled = false
    private var activeRecognitionID: UUID?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    nonisolated(unsafe) private var notificationTokens: [NSObjectProtocol] = []
    private static weak var activeService: SpeechService?

    init() {
        let center = NotificationCenter.default
        for name in [AVAudioSession.interruptionNotification,
                     AVAudioSession.mediaServicesWereResetNotification,
                     UIApplication.didEnterBackgroundNotification] {
            notificationTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.cancel() }
            })
        }
    }

    deinit {
        for token in notificationTokens { NotificationCenter.default.removeObserver(token) }
    }

    /// 识别器能否成功初始化。模拟器可能返回 nil。
    static var canInitializeRecognizer: Bool {
        SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) != nil
    }

    var isRecognizerInitialized: Bool {
        recognizer != nil
    }

    /// 系统识别服务是否可用
    var isRecognitionAvailable: Bool {
        recognizer != nil && recognizer?.isAvailable == true
    }

    var isListening: Bool {
        audioEngine.isRunning
    }

    /// 请求权限：语音识别 + 麦克风
    func requestPermissions() async -> Bool {
        guard isRecognizerInitialized else { return false }
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechStatus else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// 开始流式识别（部分结果实时回调）
    func start(
        partialHandler: @escaping (String) -> Void,
        finalHandler: @escaping (String) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) throws {
        guard isRecognitionAvailable else {
            throw SpeechError.notAvailable
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              AVAudioApplication.shared.recordPermission == .granted else {
            throw SpeechError.notAuthorized
        }

        // 麦克风是进程级独占资源：新入口接管前先完整释放旧入口。
        if let active = Self.activeService, active !== self { active.cancel() }
        cancel()
        Self.activeService = self
        let recognitionID = UUID()
        activeRecognitionID = recognitionID

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            cancel()
            throw error
        }

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        request = recognitionRequest

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard SpeechAudioFormatPolicy.isUsable(
            sampleRate: recordingFormat.sampleRate,
            channelCount: recordingFormat.channelCount
        ) else {
            cancel()
            throw SpeechError.engineFailure("当前没有可用的麦克风输入，可直接打字")
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        tapInstalled = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            cancel()
            throw error
        }

        task = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.activeRecognitionID == recognitionID else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.finishRecognition(recognitionID: recognitionID)
                        partialHandler(text)
                        finalHandler(text)
                        return
                    } else {
                        partialHandler(text)
                        self.scheduleSilenceFinish(for: recognitionID)
                    }
                }
                if let error {
                    self.finishRecognition(recognitionID: recognitionID)
                    errorHandler(error)
                }
            }
        }
    }

    /// 停止录音，等待最终结果
    func stop() {
        guard activeRecognitionID != nil else { return }
        silenceWorkItem?.cancel()
        audioEngine.stop()
        removeTapIfNeeded()
        request?.endAudio()
    }

    /// 取消当前识别
    func cancel() {
        silenceWorkItem?.cancel()
        silenceWorkItem = nil
        if audioEngine.isRunning { audioEngine.stop() }
        removeTapIfNeeded()
        request?.endAudio()
        task?.cancel()
        audioEngine.reset()
        request = nil
        task = nil
        activeRecognitionID = nil
        if Self.activeService === self { Self.activeService = nil }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func scheduleSilenceFinish(for recognitionID: UUID) {
        silenceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.activeRecognitionID == recognitionID else { return }
            self.stop()
        }
        silenceWorkItem = workItem
        // 给句中停顿留出容错，避免 partial result 过早收尾。
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    private func finishRecognition(recognitionID: UUID) {
        guard activeRecognitionID == recognitionID else { return }
        silenceWorkItem?.cancel()
        silenceWorkItem = nil
        if audioEngine.isRunning { audioEngine.stop() }
        removeTapIfNeeded()
        audioEngine.reset()
        request = nil
        task = nil
        activeRecognitionID = nil
        if Self.activeService === self { Self.activeService = nil }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func removeTapIfNeeded() {
        guard tapInstalled else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }
}

extension SpeechService: SpeechServicing {}
