package com.xiaozhanggui.app.data.voice

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicInteger

/**
 * 系统语音识别封装。对应 iOS Voice/SpeechService.swift。
 *
 * Android 等价链路（审计 C §3.2）：`android.speech.SpeechRecognizer`
 * + `RecognizerIntent.ACTION_RECOGNIZE_SPEECH`（`EXTRA_PARTIAL_RESULTS=true`，
 * 语言 zh-CN），3 秒静音自动结束用协程 `delay(3000)` 实现。
 *
 * 约定：
 * - 禁止伪造识别结果；识别器不可用时由上层进入 textFallback（手动输入走同一解析链路）。
 * - RECORD_AUDIO 由调用方申请，此处只检查状态（[hasAudioPermission]）。
 */
class VoiceSpeechService(private val appContext: Context) {

    companion object {
        private const val TAG = "VoiceSpeech"
        private const val LANGUAGE = "zh-CN"
        private const val SILENCE_TIMEOUT_MS = 3000L
        const val ERROR_NO_SPEECH_HEARD = "没有听清，请再试一次"
        const val ERROR_PERMISSION_DENIED = "麦克风/语音识别权限被拒绝"
        const val ERROR_NOT_AVAILABLE = "当前设备未提供系统语音识别服务"
    }

    /** 识别器能否初始化（对齐 iOS `isRecognizerInitialized` / `canInitializeRecognizer`）。 */
    val isAvailable: Boolean
        get() = SpeechRecognizer.isRecognitionAvailable(appContext)

    /** RECORD_AUDIO 运行时权限状态（只检查，不申请）。 */
    fun hasAudioPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            appContext,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED

    private var recognizer: SpeechRecognizer? = null
    private var silenceJob: Job? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    /**
     * 防止 stop()/cancel() 后迟到的回调污染下一次识别（对齐 iOS activeRecognitionID）。
     */
    private val activeId = AtomicInteger(0)

    /**
     * 开始流式识别。partial 结果实时回调；3 秒静音自动结束等待 final。
     * 识别器不可用时直接走 [onError]（[ERROR_NOT_AVAILABLE]），上层切 textFallback。
     */
    fun start(
        onPartial: (String) -> Unit,
        onFinal: (String) -> Unit,
        onError: (String) -> Unit,
    ) {
        if (!isAvailable) {
            onError(ERROR_NOT_AVAILABLE)
            return
        }
        // 上一次失败/取消后可立即重试，不沿用旧 recognizer（对齐 iOS start 开头的 cancel()）。
        cancel()
        val id = activeId.incrementAndGet()

        val listener = object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) = Unit
            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit
            override fun onEndOfSpeech() = Unit

            override fun onPartialResults(partialResults: Bundle?) {
                if (id != activeId.get()) return
                val text = partialResults
                    .bestText()
                    .takeIf { it.isNotBlank() }
                    ?: return
                onPartial(text)
                scheduleSilenceStop(id)
            }

            override fun onResults(results: Bundle?) {
                if (id != activeId.get()) return
                finish(id)
                val text = results.bestText()
                if (text.isNotBlank()) onFinal(text)
                else onError(ERROR_NO_SPEECH_HEARD)
            }

            override fun onError(error: Int) {
                if (id != activeId.get()) return
                finish(id)
                // 审计 C §3.3 意见：保留错误码以便诊断，用户侧统一映射文案。
                Log.w(TAG, "recognition error code=$error")
                onError(mapError(error))
            }

            override fun onEvent(eventType: Int, params: Bundle?) = Unit
        }

        val recognizer = runCatching {
            SpeechRecognizer.createSpeechRecognizer(appContext).also {
                it.setRecognitionListener(listener)
            }
        }.getOrElse {
            Log.w(TAG, "createSpeechRecognizer failed", it)
            onError(ERROR_NO_SPEECH_HEARD)
            return
        }
        this.recognizer = recognizer

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, LANGUAGE)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        runCatching {
            recognizer.startListening(intent)
        }.onFailure {
            Log.w(TAG, "startListening failed", it)
            finish(id)
            onError(ERROR_NO_SPEECH_HEARD)
        }
        // 首段静音同样 3 秒收尾，避免无声时无限等待。
        scheduleSilenceStop(id)
    }

    /** 停止录音，等待最终识别结果（对齐 iOS stop()）。 */
    fun stop() {
        silenceJob?.cancel()
        silenceJob = null
        runCatching { recognizer?.stopListening() }
    }

    /** 取消当前识别并释放识别器（对齐 iOS cancel()）。 */
    fun cancel() {
        activeId.incrementAndGet()
        silenceJob?.cancel()
        silenceJob = null
        runCatching { recognizer?.cancel() }
        runCatching { recognizer?.destroy() }
        recognizer = null
    }

    /** 彻底释放（ViewModel.onCleared 调用）。 */
    fun release() {
        cancel()
        scope.cancel()
    }

    /** 3 秒静音自动结束：每次有效 partial 重置计时（对齐 iOS scheduleSilenceFinish）。 */
    private fun scheduleSilenceStop(id: Int) {
        silenceJob?.cancel()
        silenceJob = scope.launch {
            delay(SILENCE_TIMEOUT_MS)
            if (id == activeId.get()) {
                runCatching { recognizer?.stopListening() }
            }
        }
    }

    private fun finish(id: Int) {
        if (activeId.get() != id) return
        activeId.incrementAndGet()
        silenceJob?.cancel()
        silenceJob = null
        runCatching { recognizer?.destroy() }
        recognizer = null
    }

    private fun mapError(error: Int): String = when (error) {
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> ERROR_PERMISSION_DENIED
        else -> ERROR_NO_SPEECH_HEARD
    }

    private fun Bundle?.bestText(): String =
        this?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
}
