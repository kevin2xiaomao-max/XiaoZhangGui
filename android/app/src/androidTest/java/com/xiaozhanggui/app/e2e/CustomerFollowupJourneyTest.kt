package com.xiaozhanggui.app.e2e

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import androidx.test.filters.LargeTest
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.notification.XzgAlarmReceiver
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertNotNull
import org.junit.BeforeClass
import org.junit.Test

/**
 * 旅程：新建待处理客户需求 → 验证跟进提醒的 PendingIntent 已调度。
 *
 * 验证核心集成链路：
 * `CustomerRepository.add → NotificationScheduler.rescheduleCustomer → AlarmManager`，
 * tag = "customer-<notificationId>-followup"（新增/编辑后 3600 秒触发，仅 pending），
 * 用 `PendingIntent.getBroadcast(..., FLAG_NO_CREATE)` 断言非空。
 *
 * 数据隔离：内容带唯一时间戳，旅程结束经 Repository 删除
 * （delete 会连带 cancelCustomer，不留野闹钟）。
 */
@LargeTest
class CustomerFollowupJourneyTest {

    companion object {
        @JvmStatic
        @BeforeClass
        fun setupClass() {
            E2EBase.disableAnimations()
        }
    }

    @Test
    fun createPendingCustomerRequest_schedulesFollowupPendingIntent() {
        val context: Context = ApplicationProvider.getApplicationContext()
        val repo = XzgGraph.customerRepository
        val content = "E2E跟进-${System.currentTimeMillis()}"

        val created = runBlocking {
            repo.add(
                customer = "E2E测试客户",
                content = content,
            )
        }
        try {
            // 验证：跟进提醒的 PendingIntent 已调度
            val tag = "customer-${created.notificationId}-followup"
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
            assertNotNull("客户跟进提醒的 PendingIntent 未被调度 (tag=$tag)", scheduled)
        } finally {
            // 清理：删除本旅程创建的客户需求（delete → cancelCustomer，不留野闹钟）
            runBlocking {
                repo.delete(created)
            }
        }
    }
}
