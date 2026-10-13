package com.xiaozhanggui.app.voice

import com.xiaozhanggui.app.data.voice.VoiceCapability
import com.xiaozhanggui.app.data.voice.VoiceCapabilityProbe
import com.xiaozhanggui.app.data.voice.VoiceFailureReason
import com.xiaozhanggui.app.data.voice.VoiceSpeechService
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * VoiceCapabilityProbe.classify 决策矩阵测试（纯逻辑，JVM 可跑）。
 *
 * 对应验收文档 `ANDROID_V371_OPPO_VERIFICATION.md` §9.2 具名失败诊断分类：
 * serviceMissing / noNetwork / permissionDenied / unsupportedVersion /
 * requiredApiMissing。真机探测（probe）本身依赖 Android 运行时，按验收要求
 * 在真机执行前结论一律 NOT VERIFIED，此处只锁定分类决策逻辑。
 */
class VoiceCapabilityProbeTest {

    private fun classify(
        speechClassPresent: Boolean = true,
        hasAudioPermission: Boolean = true,
        networkAvailable: Boolean = true,
        recognitionAvailable: Boolean = true,
    ): VoiceCapability = VoiceCapabilityProbe.classify(
        speechClassPresent = speechClassPresent,
        hasAudioPermission = hasAudioPermission,
        networkAvailable = networkAvailable,
        recognitionAvailable = recognitionAvailable,
    )

    @Test
    fun `all signals good yields available`() {
        assertEquals(VoiceCapability.Available, classify())
    }

    @Test
    fun `missing recognizer class yields serviceMissing`() {
        val result = classify(speechClassPresent = false)
        assertTrue(result is VoiceCapability.Unavailable)
        result as VoiceCapability.Unavailable
        assertEquals(VoiceFailureReason.serviceMissing, result.reason)
        assertEquals(VoiceSpeechService.ERROR_NOT_AVAILABLE, result.userHint)
    }

    @Test
    fun `recognition service unavailable yields serviceMissing`() {
        val result = classify(recognitionAvailable = false)
        assertTrue(result is VoiceCapability.Unavailable)
        result as VoiceCapability.Unavailable
        assertEquals(VoiceFailureReason.serviceMissing, result.reason)
        assertEquals(VoiceSpeechService.ERROR_NOT_AVAILABLE, result.userHint)
    }

    @Test
    fun `audio permission denied yields permissionDenied`() {
        val result = classify(hasAudioPermission = false)
        assertTrue(result is VoiceCapability.Unavailable)
        result as VoiceCapability.Unavailable
        assertEquals(VoiceFailureReason.permissionDenied, result.reason)
        assertEquals(VoiceSpeechService.ERROR_PERMISSION_DENIED, result.userHint)
    }

    @Test
    fun `no network yields noNetwork even when service reports ready`() {
        val result = classify(networkAvailable = false)
        assertTrue(result is VoiceCapability.Unavailable)
        result as VoiceCapability.Unavailable
        assertEquals(VoiceFailureReason.noNetwork, result.reason)
    }

    @Test
    fun `noNetwork takes precedence over service unavailability`() {
        // 网络先于 isRecognitionAvailable 检查：云端识别无网络必须具名为
        // noNetwork，而不是笼统的 serviceMissing。
        val result = classify(networkAvailable = false, recognitionAvailable = false)
        assertTrue(result is VoiceCapability.Unavailable)
        result as VoiceCapability.Unavailable
        assertEquals(VoiceFailureReason.noNetwork, result.reason)
    }

    @Test
    fun `permission denied takes precedence over noNetwork`() {
        val result = classify(hasAudioPermission = false, networkAvailable = false)
        assertTrue(result is VoiceCapability.Unavailable)
        result as VoiceCapability.Unavailable
        assertEquals(VoiceFailureReason.permissionDenied, result.reason)
    }

    @Test
    fun `reserved reasons exist for notification and exact alarm probing`() {
        // §9.2 要求同一分类体系复用于通知/精确闹钟能力探测：
        // unsupportedVersion / requiredApiMissing 为保留占位。
        assertEquals(
            "unsupportedVersion",
            VoiceFailureReason.unsupportedVersion.name,
        )
        assertEquals(
            "requiredApiMissing",
            VoiceFailureReason.requiredApiMissing.name,
        )
    }
}
