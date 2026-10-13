package com.xiaozhanggui.app.voice

import com.xiaozhanggui.app.data.voice.VoicePermissionFlow
import com.xiaozhanggui.app.data.voice.VoicePermissionOutcome
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * RECORD_AUDIO 申请三路径决策测试（纯逻辑，JVM 可跑）。
 *
 * 对应验收文档 §2 验收项 4 / §6 权限矩阵：
 * 授权 / 拒绝（临时）/ 永久拒绝（不再询问）三条路径。
 * 真机行为（系统弹窗、shouldShowRequestPermissionRationale）在 OPPO 真机
 * 验收时按 PASS / FAIL / NOT RUN 记录，此处只锁定决策规则。
 */
class VoicePermissionFlowTest {

    @Test
    fun `granted yields GRANTED regardless of rationale`() {
        assertEquals(
            VoicePermissionOutcome.GRANTED,
            VoicePermissionFlow.decide(granted = true, shouldShowRationale = false),
        )
        assertEquals(
            VoicePermissionOutcome.GRANTED,
            VoicePermissionFlow.decide(granted = true, shouldShowRationale = true),
        )
    }

    @Test
    fun `denied with rationale yields DENIED_TRANSIENT`() {
        // 本次拒绝但系统仍会再次弹窗：降级文字输入，下次可重新申请。
        assertEquals(
            VoicePermissionOutcome.DENIED_TRANSIENT,
            VoicePermissionFlow.decide(granted = false, shouldShowRationale = true),
        )
    }

    @Test
    fun `denied without rationale yields DENIED_PERMANENT`() {
        // 拒绝且系统不再弹窗（不再询问）：降级文字输入 + 引导去系统设置。
        assertEquals(
            VoicePermissionOutcome.DENIED_PERMANENT,
            VoicePermissionFlow.decide(granted = false, shouldShowRationale = false),
        )
    }
}
