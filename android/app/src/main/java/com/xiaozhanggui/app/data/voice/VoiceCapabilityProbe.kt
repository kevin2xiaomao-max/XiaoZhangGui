package com.xiaozhanggui.app.data.voice

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * 语音识别能力探测：具名失败诊断。
 *
 * 对应验收文档 `ANDROID_V371_OPPO_VERIFICATION.md` §9.2 的分类要求，
 * 在小掌柜内**独立实现**（未复制 SleepDown 任何代码，仅借用"具名失败原因"
 * 的分类思路；许可证红线见验收文档 §9 开头）。
 *
 * 失败原因与 §9.2 分类的映射：
 * - [VoiceFailureReason.serviceMissing]：无识别服务；§9.2 `runtimeClassMissing`
 *  （运行时类不存在）归此类；
 * - [VoiceFailureReason.noNetwork]：云端识别无网络；§9.2 `sourceNotReady`
 *  （能力源未就绪）归此类——云端 ASR 无网络即源未就绪；
 * - [VoiceFailureReason.permissionDenied]：RECORD_AUDIO 被拒；
 * - [VoiceFailureReason.unsupportedVersion] / [VoiceFailureReason.requiredApiMissing]：
 *   保留占位，供 §9.2 要求的通知（通知渠道新特性 / 全屏 Intent）、
 *   精确闹钟（AlarmManager API）等能力探测复用同一分类体系。
 *
 * 约定（§9.2 要求）：
 * - 探测结果只用于**降级与诊断提示**，不得静默关闭功能；
 * - 诊断日志**脱敏**：只记录具名原因，禁止输出语音原文、API Key 等敏感信息；
 * - 探测在真机验证前结论一律视为未验证，不对外宣称 PASS。
 */
enum class VoiceFailureReason {
    /** 无识别服务 / 运行时类缺失 */
    serviceMissing,

    /** 云端识别无网络；能力源未就绪归此类 */
    noNetwork,

    /** RECORD_AUDIO 被拒 */
    permissionDenied,

    /** 系统/固件版本不满足 —— 保留占位 */
    unsupportedVersion,

    /** 所需 API 缺失 —— 保留占位 */
    requiredApiMissing,
}

/** 语音能力探测结果：可用 / 具名不可用（携带用户可读提示）。 */
sealed interface VoiceCapability {
    data object Available : VoiceCapability

    data class Unavailable(
        val reason: VoiceFailureReason,
        val userHint: String,
    ) : VoiceCapability
}

object VoiceCapabilityProbe {

    private const val TAG = "VoiceCapability"
    private const val SPEECH_RECOGNIZER_CLASS = "android.speech.SpeechRecognizer"

    /**
     * 纯决策核心（JVM 可测）：按固定优先级给出具名分类。
     *
     * 优先级：类缺失 → 权限 → 网络 → 服务可用性。网络先于
     * `isRecognitionAvailable` 检查，是为了把"云端识别无网络"从笼统的
     * serviceMissing 中分离为具名 [VoiceFailureReason.noNetwork]。
     */
    fun classify(
        speechClassPresent: Boolean,
        hasAudioPermission: Boolean,
        networkAvailable: Boolean,
        recognitionAvailable: Boolean,
    ): VoiceCapability = when {
        !speechClassPresent ->
            VoiceCapability.Unavailable(
                VoiceFailureReason.serviceMissing,
                VoiceSpeechService.ERROR_NOT_AVAILABLE,
            )
        !hasAudioPermission ->
            VoiceCapability.Unavailable(
                VoiceFailureReason.permissionDenied,
                VoiceSpeechService.ERROR_PERMISSION_DENIED,
            )
        !networkAvailable ->
            VoiceCapability.Unavailable(
                VoiceFailureReason.noNetwork,
                "无网络连接，云端语音识别暂不可用，可直接打字",
            )
        !recognitionAvailable ->
            VoiceCapability.Unavailable(
                VoiceFailureReason.serviceMissing,
                VoiceSpeechService.ERROR_NOT_AVAILABLE,
            )
        else -> VoiceCapability.Available
    }

    /**
     * 真机探测：读取 Android 运行时状态后走 [classify]。
     * 所有系统调用均用 runCatching 包裹，任一环节异常按"不可用"处理，
     * 绝不抛异常打断调用方。
     */
    fun probe(context: Context): VoiceCapability {
        val speechClassPresent = runCatching {
            Class.forName(SPEECH_RECOGNIZER_CLASS)
        }.isSuccess
        val hasAudioPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
        val networkAvailable = isNetworkAvailable(context)
        val recognitionAvailable = if (speechClassPresent) {
            runCatching { SpeechRecognizer.isRecognitionAvailable(context) }
                .getOrDefault(false)
        } else {
            false
        }
        val result = classify(
            speechClassPresent = speechClassPresent,
            hasAudioPermission = hasAudioPermission,
            networkAvailable = networkAvailable,
            recognitionAvailable = recognitionAvailable,
        )
        // 脱敏日志：只记录具名原因；禁止语音原文、API Key 等敏感信息。
        when (result) {
            VoiceCapability.Available -> Log.i(TAG, "voice capability: available")
            is VoiceCapability.Unavailable ->
                Log.w(TAG, "voice capability unavailable: reason=${result.reason}")
        }
        return result
    }

    private fun isNetworkAvailable(context: Context): Boolean = runCatching {
        val manager =
            context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return false
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }.getOrDefault(false)
}
