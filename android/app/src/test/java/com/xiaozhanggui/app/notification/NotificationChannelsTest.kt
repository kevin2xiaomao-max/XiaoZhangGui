package com.xiaozhanggui.app.notification

import com.xiaozhanggui.app.data.notification.NotificationChannels
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 通知渠道映射（Phase 3 Worker B）：闹钟 tag 前缀 → 三类独立渠道。
 * 纯逻辑，可 JVM 测试；ensureChannels 需 Android 框架，由 CI E2E 间接覆盖。
 */
class NotificationChannelsTest {

    @Test
    fun tagPrefix_mapsToCorrectChannel() {
        assertEquals(NotificationChannels.TODO, NotificationChannels.channelIdForTag("todo-abc-123"))
        assertEquals(NotificationChannels.EXPIRY, NotificationChannels.channelIdForTag("expiry-abc-123"))
        assertEquals(
            NotificationChannels.CUSTOMER,
            NotificationChannels.channelIdForTag("customer-abc-123-followup")
        )
    }

    @Test
    fun channelIds_areDistinct() {
        val ids = setOf(
            NotificationChannels.TODO,
            NotificationChannels.EXPIRY,
            NotificationChannels.CUSTOMER,
        )
        assertEquals(3, ids.size)
    }
}
