package com.xiaozhanggui.app.notification

import com.xiaozhanggui.app.ui.notifications.ReminderCapability
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 提醒能力状态文案（Phase 3 Worker B）：UI 诚实性 ——
 * 降级必须明示，精确状态不得误报。
 */
class ReminderCapabilityTest {

    @Test
    fun allGranted_noDegradation_exactLineIsExact() {
        val cap = ReminderCapability(notificationsGranted = true, exactAlarmAvailable = true)
        assertTrue(cap.degradationLines().isEmpty())
        assertEquals("精确提醒", cap.exactnessLine())
    }

    @Test
    fun notificationDenied_showsInAppOnlyDegradation() {
        val cap = ReminderCapability(notificationsGranted = false, exactAlarmAvailable = true)
        val lines = cap.degradationLines()
        assertEquals(1, lines.size)
        assertEquals("通知未授权，提醒仅在应用内显示", lines[0])
    }

    @Test
    fun exactAlarmUnavailable_showsInexactDegradation_neverClaimsExact() {
        val cap = ReminderCapability(notificationsGranted = true, exactAlarmAvailable = false)
        val lines = cap.degradationLines()
        assertEquals(1, lines.size)
        assertTrue(lines[0].startsWith("非精确提醒"))
        // 精确行必须如实写非精确，不得误报"精确提醒"
        assertTrue(cap.exactnessLine().startsWith("非精确提醒"))
    }

    @Test
    fun bothDenied_notificationLineFirst_thenInexactLine() {
        val cap = ReminderCapability(notificationsGranted = false, exactAlarmAvailable = false)
        val lines = cap.degradationLines()
        assertEquals(2, lines.size)
        assertEquals("通知未授权，提醒仅在应用内显示", lines[0])
        assertTrue(lines[1].startsWith("非精确提醒"))
    }
}
