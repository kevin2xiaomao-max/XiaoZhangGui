package com.xiaozhanggui.app.data.voice

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 短语音面板状态机。对应 iOS `Features/Assistant/AI/Voice/ShortVoiceSession.swift`
 * 的 `ShortVoicePhase`。
 */
sealed interface ShortVoicePhase {
    data object Idle : ShortVoicePhase
    data object Listening : ShortVoicePhase

    /** 已拿到 final，等待 Agent 处理 */
    data object Finalizing : ShortVoicePhase

    /** 失败：message 为提示语；原文仍保留，可经 [ShortVoiceSession.consumeRetainedTranscript] 取回 */
    data class Failed(val message: String) : ShortVoicePhase
}

/**
 * 小掌柜短语音会话（单事项，复用 [VoiceSpeechService]）。
 * 对应 iOS `Features/Assistant/AI/Voice/ShortVoiceSession.swift`。
 *
 * 约定（与 iOS 一致）：
 * - 只做「入口 + 链路接缝」：聆听 → final transcript → 与文字相同的 Agent 流程；
 *   final 原文由调用方（AI 会话 ViewModel）送入 AgentCore；
 * - [start] 前必查 [VoiceSpeechService.isAvailable]
 *  （= `SpeechRecognizer.isRecognitionAvailable()`），不可用直接进入
 *   [ShortVoicePhase.Failed]，上层降级为文字输入（OPPO 专项红线）；
 * - RECORD_AUDIO 由调用方申请，此处只检查 [VoiceSpeechService.hasAudioPermission]；
 * - 失败不丢原文：partial/final 原文保留在 [consumeRetainedTranscript]，
 *   用户可一键填入输入框改写重发；
 * - 不做长语音 / 多段合并。
 */
class ShortVoiceSession(private val speech: VoiceSpeechService) {

    private val _phase = MutableStateFlow<ShortVoicePhase>(ShortVoicePhase.Idle)
    val phase: StateFlow<ShortVoicePhase> = _phase.asStateFlow()

    /** 实时转写 */
    private val _liveTranscript = MutableStateFlow("")
    val liveTranscript: StateFlow<String> = _liveTranscript.asStateFlow()

    /** 最近一次 final 原文（无论成功失败都保留） */
    private var lastRawTranscript: String = ""

    /**
     * 开始聆听；[onFinal] 在主线程回调 final 原文，由调用方送入 Agent 流程。
     */
    fun start(onFinal: (String) -> Unit) {
        if (!speech.isAvailable) {
            _phase.value = ShortVoicePhase.Failed("当前设备不可用语音识别，可直接打字")
            return
        }
        if (!speech.hasAudioPermission()) {
            _phase.value = ShortVoicePhase.Failed("麦克风/语音识别权限被拒绝，可在系统设置中开启")
            return
        }
        _liveTranscript.value = ""
        speech.start(
            onPartial = { partial ->
                _liveTranscript.value = partial
                if (_phase.value == ShortVoicePhase.Idle ||
                    _phase.value == ShortVoicePhase.Finalizing
                ) {
                    _phase.value = ShortVoicePhase.Listening
                }
            },
            onFinal = { final ->
                val trimmed = final.trim()
                lastRawTranscript = trimmed
                if (trimmed.isEmpty()) {
                    _phase.value = ShortVoicePhase.Failed("没有听清，请再试一次；也可以直接打字")
                } else {
                    _phase.value = ShortVoicePhase.Finalizing
                    onFinal(trimmed)
                }
            },
            onError = { message ->
                // 失败不丢已识别的 partial 原文
                if (_liveTranscript.value.trim().isNotEmpty()) {
                    lastRawTranscript = _liveTranscript.value
                }
                _phase.value = ShortVoicePhase.Failed(message)
            }
        )
        if (_phase.value == ShortVoicePhase.Idle) {
            _phase.value = ShortVoicePhase.Listening
        }
    }

    /** 手动停止，等待 final */
    fun stop() {
        speech.stop()
    }

    /**
     * 永久拒绝（不再询问）：进入失败态，提示去系统设置开启或直接打字。
     * 调用方保持面板打开展示该失败态（验收文档 §2 验收项 4）。
     */
    fun onPermissionPermanentlyDenied() {
        _phase.value = ShortVoicePhase.Failed("麦克风权限已被永久拒绝，可前往系统设置开启，或直接打字")
    }

    /** 取消本次聆听 */
    fun cancel() {
        speech.cancel()
        _liveTranscript.value = ""
        _phase.value = ShortVoicePhase.Idle
    }

    /** 结束一轮（Agent 已接收 / 用户关闭错误后） */
    fun finish() {
        speech.cancel()
        _liveTranscript.value = ""
        _phase.value = ShortVoicePhase.Idle
    }

    /** 把保留的原文交回输入框（失败后改写重发） */
    fun consumeRetainedTranscript(): String {
        val text = lastRawTranscript
        lastRawTranscript = ""
        return text
    }

    /** 彻底释放（持有方 onCleared 调用） */
    fun release() {
        speech.release()
    }
}
