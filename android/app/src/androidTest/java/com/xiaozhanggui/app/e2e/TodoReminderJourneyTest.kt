package com.xiaozhanggui.app.e2e

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.widget.DatePicker
import android.widget.TimePicker
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.contrib.PickerActions
import androidx.test.espresso.matcher.RootMatchers.isDialog
import androidx.test.espresso.matcher.ViewMatchers.isAssignableFrom
import androidx.test.espresso.matcher.ViewMatchers.isDisplayed
import androidx.test.espresso.matcher.ViewMatchers.withId
import androidx.test.filters.LargeTest
import com.xiaozhanggui.app.MainActivity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.notification.XzgAlarmReceiver
import java.util.Calendar
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertNotNull
import org.junit.BeforeClass
import org.junit.Rule
import org.junit.Test

/**
 * 旅程 2：新建待办（带提醒时间）→ 验证 AlarmManager 的 PendingIntent 已调度（Phase 6 Worker B）。
 *
 * 待办 Tab → 新增待办 → 填标题 → 日期设为「明天」（平台 DatePickerDialog，
 * 经 Espresso PickerActions.setDate 编程设置，不依赖日历格子点击）→
 * 时间保持默认 9:00 直接确定（TimePickerDialog）→ 保存 →
 * 从 Repository 查到新建实体，按 AlarmNotificationScheduler 的 tag 规则
 * （"todo-<notificationId>"，requestCode = tag.hashCode()）用
 * PendingIntent.getBroadcast(..., FLAG_NO_CREATE) 断言非空。
 *
 * 数据隔离：标题带唯一时间戳，旅程结束经 Repository 删除
 * （delete 会连带 cancelTodo，不留野闹钟）。
 */
@LargeTest
class TodoReminderJourneyTest {

    @get:Rule
    val rule = createAndroidComposeRule<MainActivity>()

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

        try {
            // 待办 Tab（底部栏 contentDescription 精确匹配，避免与首页"今天待办N项"混淆）
            rule.onNodeWithContentDescription("待办").performClick()
            rule.onNodeWithContentDescription("新增待办").performClick()

            // 标题
            rule.waitUntil(10_000) {
                rule.onAllNodesWithTag("todo.titleInput")
                    .fetchSemanticsNodes().isNotEmpty()
            }
            rule.onNodeWithTag("todo.titleInput").performTextInput(title)

            // 日期 → 明天（平台 DatePickerDialog，Espresso 编程设置日期，与语言/布局无关）
            rule.onNodeWithTag("todo.dateRow").performClick()
            val tomorrow = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
            onView(isAssignableFrom(DatePicker::class.java))
                .inRoot(isDialog())
                .perform(
                    PickerActions.setDate(
                        tomorrow.get(Calendar.YEAR),
                        tomorrow.get(Calendar.MONTH) + 1,
                        tomorrow.get(Calendar.DAY_OF_MONTH)
                    )
                )
            // 平台对话框确定按钮：用 android.R.id.button1，不依赖中英文文案
            onView(withId(android.R.id.button1)).inRoot(isDialog()).perform(click())

            // 时间 → 保持默认 9:00（编辑器默认即今日 9:00），直接确定
            onView(isAssignableFrom(TimePicker::class.java))
                .inRoot(isDialog())
                .check(matches(isDisplayed()))
            onView(withId(android.R.id.button1)).inRoot(isDialog()).perform(click())

            // 保存
            rule.onNodeWithTag("todo.saveButton").performClick()
            rule.waitUntil(10_000) {
                rule.onAllNodesWithTag("todo.titleInput")
                    .fetchSemanticsNodes().isEmpty()
            }

            // 验证：AlarmManager 的 PendingIntent 已调度
            // （tag/requestCode 规则与 AlarmNotificationScheduler 完全一致）
            val created = runBlocking { todoRepo.observeAll().first() }
                .first { it.title == title }
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
                val created = todoRepo.observeAll().first()
                    .firstOrNull { it.title == title }
                if (created != null) todoRepo.delete(created)
            }
        }
    }
}
