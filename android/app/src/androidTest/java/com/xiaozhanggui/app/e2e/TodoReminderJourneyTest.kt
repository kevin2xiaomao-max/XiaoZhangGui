package com.xiaozhanggui.app.e2e

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.View
import android.widget.DatePicker
import android.widget.TimePicker
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso
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
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.notification.XzgAlarmReceiver
import com.xiaozhanggui.app.data.repository.TodoRepository
import java.io.File
import java.util.Calendar
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.hamcrest.Matcher
import org.junit.Assert.assertEquals
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
        private const val TAG = "TodoReminderJourney"

        @JvmStatic
        @BeforeClass
        fun setupClass() {
            E2EBase.disableAnimations()
        }
    }

    /**
     * 轮询等待平台对话框出现。
     *
     * 根因：DatePickerDialog/TimePickerDialog 是平台 View 系统的 dialog，
     * Compose 的 performClick 返回只保证 Compose idle，不保证 dialog 已 attach；
     * Espresso onView 的默认 idle 等待也不覆盖"dialog 尚未出现"的情况。
     * 直接 inRoot(isDialog()) 查找会在 dialog 出现前抛 NoMatchingRootException，
     * 故先轮询等 dialog root 出现再操作。
     */
    private fun waitForDialogRoot(viewMatcher: Matcher<View>, timeoutMillis: Long = 10_000) {
        val deadline = System.currentTimeMillis() + timeoutMillis
        var lastError: Throwable? = null
        while (System.currentTimeMillis() < deadline) {
            try {
                onView(viewMatcher).inRoot(isDialog()).check(matches(isDisplayed()))
                return
            } catch (e: Throwable) {
                lastError = e
                Thread.sleep(200)
            }
        }
        throw AssertionError("平台对话框在 ${timeoutMillis}ms 内未出现", lastError)
    }

    @Test
    fun createTodoWithReminder_schedulesAlarmPendingIntent() {
        val context: Context = ApplicationProvider.getApplicationContext()
        val todoRepo = XzgGraph.todoRepository
        // Phase 6 诊断基线：实例身份 + DB 文件状态（与保存后的诊断对比）。
        dumpDbState(context, "start", todoRepo)
        val title = "E2E待办-${System.currentTimeMillis()}"
        // 快照已有行 ID：之后用"新 ID"定位新建行，不依赖标题字符串匹配。
        // 根因（Phase 6 第三轮）：sheet 关闭（waitUntil 通过）但按标题查库报
        // NoSuchElementException。insert 在 onSave 的 suspend 链内先于 onDismiss
        // 完成，理论上行必存在；改用 ID 差集可区分"行不存在"与"标题被改写"两种
        // 情况，并配合下面的 fail-fast 断言与 Log 诊断定位。
        val beforeIds = runBlocking { todoRepo.observeAll().first() }.map { it.id }.toSet()

        try {
            // 待办 Tab（底部栏 contentDescription 精确匹配，避免与首页"今天待办N项"混淆；
            // 底部栏图标语义在未合并树中，需 useUnmergedTree）
            rule.onNodeWithContentDescription("待办", useUnmergedTree = true).performClick()
            rule.onNodeWithContentDescription("新增待办").performClick()

            // 标题
            rule.waitUntil(10_000) {
                rule.onAllNodesWithTag("todo.titleInput")
                    .fetchSemanticsNodes().isNotEmpty()
            }
            rule.onNodeWithTag("todo.titleInput").performTextInput(title)
            // fail-fast：确认输入确实落进标题框。若文本被改写/丢失，在此报明错，
            // 而不是最后在库查询处报含糊的 NoSuchElementException。
            rule.onNodeWithTag("todo.titleInput").assertTextEquals(title)
            // 收起软键盘：键盘若遮挡日期行，Compose performClick 不做遮挡检查，
            // 点击会落到键盘上导致 DatePickerDialog 根本没弹出来
            //（NoMatchingRootException 的主因）。
            Espresso.closeSoftKeyboard()

            // 日期 → 明天（平台 DatePickerDialog，Espresso 编程设置日期，与语言/布局无关）
            rule.onNodeWithTag("todo.dateRow").performClick()
            val tomorrow = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
            waitForDialogRoot(isAssignableFrom(DatePicker::class.java))
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
            // （DatePicker 点确定后 TimePickerDialog 在 onDateSet 回调里 show，需等待出现）
            waitForDialogRoot(isAssignableFrom(TimePicker::class.java))
            onView(isAssignableFrom(TimePicker::class.java))
                .inRoot(isDialog())
                .check(matches(isDisplayed()))
            onView(withId(android.R.id.button1)).inRoot(isDialog()).perform(click())

            // 保存（fail-fast：V32PrimaryButton 禁用态点击会静默落空，
            // 见 RevenueJourneyTest 同类注释；先断言可点，免得在库查询处报含糊的错）
            rule.onNodeWithTag("todo.saveButton").assertIsEnabled()
            rule.onNodeWithTag("todo.saveButton").performClick()
            rule.waitUntil(10_000) {
                rule.onAllNodesWithTag("todo.titleInput")
                    .fetchSemanticsNodes().isEmpty()
            }

            // Phase 6 诊断：保存点击后、查库前 —— DB 文件级诊断，定位"行到底去哪了"。
            // 文件路径/存在/大小 + Room 实际打开的路径 + 绕过 DAO/Flow 的原始 SQL
            // + 实例 identityHashCode（验证测试与 UI 是否同一 DB/同一 Repository）。
            dumpDbState(context, "afterSave", todoRepo)

            // 等待新行落库：轮询 ID 差集（insert 在 onSave suspend 链内先于
            // onDismiss 完成，轮询只为防极端调度延迟）。无论成功失败都打 Log，
            // 供 CI logcat 诊断库内到底有什么。
            var newTodo: TodoEntity? = null
            val deadline = System.currentTimeMillis() + 10_000
            while (System.currentTimeMillis() < deadline && newTodo == null) {
                newTodo = runBlocking { todoRepo.observeAll().first() }
                    .firstOrNull { it.id !in beforeIds }
                if (newTodo == null) Thread.sleep(200)
            }
            val rows = runBlocking { todoRepo.observeAll().first() }
            Log.d(
                TAG,
                "落库等待结束，找到新行=${newTodo != null}，库内共 ${rows.size} 行，" +
                    "标题列表=${rows.map { it.title }}"
            )
            // 轮询结束仍无行：再打一次 DB 级诊断（与 afterSave 对比，看轮询期间有无变化）。
            dumpDbState(context, "afterPoll", todoRepo)
            val created = requireNotNull(newTodo) {
                "保存后 10s 内库里没有出现新待办行（库内标题=${rows.map { it.title }}；" +
                    "DB 文件级诊断见 logcat tag=$TAG stage=start/afterSave/afterPoll）"
            }
            // 标题一致性校验：确认输入链路无改写
            assertEquals("落库标题与输入不一致", title, created.title)

            // 验证：AlarmManager 的 PendingIntent 已调度
            // （tag/requestCode 规则与 AlarmNotificationScheduler 完全一致）
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
                    .firstOrNull { it.id !in beforeIds }
                if (created != null) todoRepo.delete(created)
            }
        }
    }

    /**
     * Phase 6 诊断：DB 文件级状态快照（logcat tag=[TAG]，stage 区分调用点）。
     *
     * 逐层排除"保存后库里没行"的可能原因：
     * 1. DB 文件：路径/存在/大小（+wal/shm）——确认文件本身；
     * 2. Room 实际打开的路径（openHelper.readableDatabase.path）——
     *    确认没有第二个 DB 文件；
     * 3. 原始 SQL `SELECT id, title FROM todos`（绕过 Repository/DAO/Flow）——
     *    若此处有行而 observeAll() 为空，则是 Flow/DAO 读取问题；
     *    若此处也为空，则 insert 真没落到这个文件；
     * 4. identityHashCode ——确认测试与 UI 用的是同一个 XzgGraph.database /
     *    同一个 todoRepository（XzgGraph 为单例 object，理论上必相同，打出来实证）。
     */
    private fun dumpDbState(context: Context, stage: String, todoRepo: TodoRepository) {
        val dbFile = context.getDatabasePath("xzg.db")
        val walLen = File(dbFile.absolutePath + "-wal").length()
        val shmLen = File(dbFile.absolutePath + "-shm").length()
        val db = XzgGraph.database
        val roomPath = try {
            db.openHelper.readableDatabase.path
        } catch (e: Exception) {
            "ERR:${e::class.java.simpleName}:${e.message}"
        }
        val rawRows = mutableListOf<String>()
        var rawCount = -1
        try {
            db.openHelper.readableDatabase.query("SELECT id, title FROM todos").use { c ->
                rawCount = c.count
                val idIdx = c.getColumnIndex("id")
                val titleIdx = c.getColumnIndex("title")
                while (c.moveToNext()) {
                    rawRows.add("${c.getString(idIdx)}|${c.getString(titleIdx)}")
                }
            }
        } catch (e: Exception) {
            rawRows.add("RAW_QUERY_FAILED:${e::class.java.simpleName}:${e.message}")
        }
        Log.d(
            TAG,
            "[$stage] dbFile=${dbFile.absolutePath} exists=${dbFile.exists()} " +
                "size=${dbFile.length()} wal=$walLen shm=$shmLen roomPath=$roomPath"
        )
        Log.d(
            TAG,
            "[$stage] identity database=${System.identityHashCode(db)} " +
                "todoRepoArg=${System.identityHashCode(todoRepo)} " +
                "todoRepoFresh=${System.identityHashCode(XzgGraph.todoRepository)}"
        )
        Log.d(TAG, "[$stage] rawSQL SELECT id,title FROM todos -> count=$rawCount rows=$rawRows")
    }
}
