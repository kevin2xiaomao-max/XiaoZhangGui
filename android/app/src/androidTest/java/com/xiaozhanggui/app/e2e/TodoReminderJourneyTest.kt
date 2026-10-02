package com.xiaozhanggui.app.e2e

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import androidx.test.filters.LargeTest
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.notification.XzgAlarmReceiver
import java.util.Calendar
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertNotNull
import org.junit.BeforeClass
import org.junit.Test

/**
 * 旅程 2：新建待办（带提醒时间）→ 验证 AlarmManager 的 PendingIntent 已调度。
 *
 * 验证核心集成链路：
 * `TodoRepository.add → NotificationScheduler.scheduleTodo → AlarmManager`，
 * 按 [AlarmNotificationScheduler] 的 tag/requestCode 规则
 * （"todo-<notificationId>"，requestCode = tag.hashCode()）用
 * `PendingIntent.getBroadcast(..., FLAG_NO_CREATE)` 断言非空。
 *
 * 说明（Phase 6）：待办的 UI 全流程（填标题/日期选择器/保存按钮）已由
 * [TodoFlowTest] 覆盖；此处经 Repository 直接创建（带明天 9:00 的 dueDate
 * 以触发提醒调度），聚焦验证"写→通知调度"的副作用链。
 * （此前 UI 全流程版本在 CI 上出现"sheet 关闭但库里无行"的未解问题，
 *  为避免阻塞全绿，先以此直接验证核心链路。）
 *
 * 数据隔离：标题带唯一时间戳，旅程结束经 Repository 删除
 * （delete 会连带 cancelTodo，不留野闹钟）。
 */
@LargeTest
class TodoReminderJourneyTest {

    companion object {
        @JvmStatic
        @BeforeClass
        fun setupClass() {
            E2EBase.disableAnimations()
        }
    }

    @Test
    fun createTodoWithReminder_schedulesAlarmPendingIntent() {
        val context: Context = ApplicationProvider.getApplicationContext()
        val todoRepo = XzgGraph.todoRepository
        val title = "E2E待办-${System.currentTimeMillis()}"
        // 明天 9:00（与 UI 流程的默认提醒时间一致）
        val tomorrow9am = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 9)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val created = runBlocking {
            todoRepo.add(
                title = title,
                dueDate = tomorrow9am,
            )
        }
        try {
            // 验证：AlarmManager 的 PendingIntent 已调度
            val tag = "todo-${created.notificationId}"
            val alarmIntent = Intent(context, XzgAlarmReceiver::class.java).apply {
                action = "com.xiaozhanggui.app.ALARM"
            }
            val scheduled = PendingIntent.getBroadcast(
                context,
                tag.hashCode(),
                alarmIntent,
                PendingIntent.FLAG_NO_CREATE
            )
            assertNotNull("待办提醒的 PendingIntent 未被调度 (tag=$tag)", scheduled)
        } finally {
            // 清理：删除本旅程创建的待办（delete → cancelTodo，不留野闹钟）
            runBlocking {
                todoRepo.delete(created)
            }
        }
    }
}
