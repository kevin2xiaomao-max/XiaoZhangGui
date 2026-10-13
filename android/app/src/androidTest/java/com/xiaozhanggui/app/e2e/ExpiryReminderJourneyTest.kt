package com.xiaozhanggui.app.e2e

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import androidx.test.filters.LargeTest
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.notification.XzgAlarmReceiver
import com.xiaozhanggui.app.domain.DateExt
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertNotNull
import org.junit.BeforeClass
import org.junit.Test

/**
 * 旅程：新建临期商品（带提醒）→ 验证 AlarmManager 的 PendingIntent 已调度。
 *
 * 验证核心集成链路：
 * `ExpiryRepository.add → NotificationScheduler.scheduleExpiry → AlarmManager`，
 * 按 [AlarmNotificationScheduler] 的 tag/requestCode 规则
 * （"expiry-<notificationId>"，requestCode = tag.hashCode()）用
 * `PendingIntent.getBroadcast(..., FLAG_NO_CREATE)` 断言非空。
 *
 * 触发时机（对应 iOS 语义）：(expiryDate - remindDaysBefore) 当天 9:00。
 * 本用例 expiryDate = 3 天后 0 点、remindDaysBefore = 1 → 2 天后 9:00（必 > now）。
 *
 * 数据隔离：名称带唯一时间戳，旅程结束经 Repository 删除
 * （delete 会连带 cancelExpiry，不留野闹钟）。
 */
@LargeTest
class ExpiryReminderJourneyTest {

    companion object {
        @JvmStatic
        @BeforeClass
        fun setupClass() {
            E2EBase.disableAnimations()
        }
    }

    @Test
    fun createExpiryItem_schedulesAlarmPendingIntent() {
        val context: Context = ApplicationProvider.getApplicationContext()
        val repo = XzgGraph.expiryRepository
        val name = "E2E临期-${System.currentTimeMillis()}"
        val expiryDate = DateExt.startOfDay(System.currentTimeMillis() + 3 * 24 * 3600 * 1000L)

        val created = runBlocking {
            repo.add(
                name = name,
                expiryDate = expiryDate,
                remindDaysBefore = 1,
            )
        }
        try {
            // 验证：AlarmManager 的 PendingIntent 已调度
            val tag = "expiry-${created.notificationId}"
            val alarmIntent = Intent(context, XzgAlarmReceiver::class.java).apply {
                action = "com.xiaozhanggui.app.ALARM"
            }
            val scheduled = PendingIntent.getBroadcast(
                context,
                tag.hashCode(),
                alarmIntent,
                // 注意：生产侧 pendingIntent() 带 FLAG_IMMUTABLE 创建，
                // 查询时必须带同样的 mutability flag，否则 FLAG_NO_CREATE 匹配不到。
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            assertNotNull("临期提醒的 PendingIntent 未被调度 (tag=$tag)", scheduled)
        } finally {
            // 清理：删除本旅程创建的临期商品（delete → cancelExpiry，不留野闹钟）
            runBlocking {
                repo.delete(created)
            }
        }
    }
}
