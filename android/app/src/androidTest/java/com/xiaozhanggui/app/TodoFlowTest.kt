package com.xiaozhanggui.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.espresso.Espresso
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.repository.MemoRepository
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.ui.components.ConfirmDeleteDialog
import com.xiaozhanggui.app.ui.screens.todo.TodoContent
import com.xiaozhanggui.app.ui.screens.todo.TodoEditorSheet
import com.xiaozhanggui.app.ui.screens.todo.TodoViewModel
import com.xiaozhanggui.app.ui.theme.XzgTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 待办全流程 UI 测试（Phase 6 Worker A）：新建 → 标记完成 → 删除。
 *
 * - [TodoTestHarness] 与生产 [TodoScreen] 同构接线（TodoContent + TodoEditorSheet +
 *   ConfirmDeleteDialog），ViewModel 注入假 DAO 支撑的真实 Repository；
 * - 不碰真数据库 / AlarmManager（通知走 [FakeNotifications] 空实现）。
 */
@RunWith(AndroidJUnit4::class)
class TodoFlowTest {

    @get:Rule
    val rule = createComposeRule()

    private lateinit var dao: FakeTodoDao
    private lateinit var vm: TodoViewModel

    @Before
    fun setup() {
        dao = FakeTodoDao()
        vm = TodoViewModel(
            TodoRepository(dao, FakeNotifications),
            MemoRepository(FakeMemoDao())
        )
    }

    /** 与 TodoScreen 同构的测试接线：假 Repository 驱动的真实 ViewModel + 真实 UI。 */
    @Composable
    private fun TodoTestHarness(viewModel: TodoViewModel) {
        val todos by viewModel.todos.collectAsStateWithLifecycle()
        val memos by viewModel.memos.collectAsStateWithLifecycle()
        var showEditor by remember { mutableStateOf(false) }
        var deleting by remember { mutableStateOf<TodoEntity?>(null) }

        TodoContent(
            todos = todos,
            memos = memos,
            togglingIds = emptySet(),
            onToggleTodo = { viewModel.toggleComplete(it) },
            onDeleteTodo = { deleting = it },
            onAddTodo = { showEditor = true }
        )
        if (showEditor) {
            TodoEditorSheet(
                todo = null,
                onDismiss = { showEditor = false },
                onSave = { title, detail, dueDate, priority, imagePath ->
                    viewModel.saveTodo(title, detail, dueDate, priority, imagePath, null)
                }
            )
        }
        val target = deleting
        if (target != null) {
            ConfirmDeleteDialog(
                title = "删除这条待办？",
                onDismiss = { deleting = null },
                onConfirm = {
                    deleting = null
                    viewModel.deleteTodo(target)
                }
            )
        }
    }

    @Test
    fun todo_fullFlow_addToggleDelete() {
        rule.setContent {
            XzgTheme { TodoTestHarness(vm) }
        }

        // ---- 新建 ----
        rule.onNodeWithContentDescription("新增待办").performClick()
        rule.onNodeWithText("新增待办").assertExists() // Sheet 标题
        // 用确定性 testTag 定位标题框：onAllNodes(hasSetTextAction())[0] 的顺序不保证，
        // 文本若误落到补充说明框会导致标题为空 → 保存按钮 disabled → 落库超时。
        rule.onNodeWithTag("todo.titleInput").performTextInput("买两箱可乐")
        // 收起软键盘：Compose performClick 不做遮挡检查，键盘遮挡会导致点击落到键盘上。
        Espresso.closeSoftKeyboard()
        rule.onNodeWithTag("todo.saveButton").performScrollTo().performClick()
        rule.waitUntil(timeoutMillis = 5_000) { dao.current.size == 1 }
        assertEquals("买两箱可乐", dao.current[0].title)
        // Sheet 关闭，列表出现该行（今天 tab：默认 dueDate 为今日 9:00）。
        // 注意：待办行标题 Column 带 clickable（mergeDescendants），标题与副标题会合并为一个语义节点，
        // 精确匹配找不到，必须用 substring=true。
        rule.waitUntil(timeoutMillis = 5_000) {
            rule.onAllNodesWithText("买两箱可乐", substring = true)
                .fetchSemanticsNodes().isNotEmpty()
        }

        // ---- 标记完成 ----
        rule.onAllNodesWithTag("todo.toggle").assertCountEquals(1)[0].performClick()
        rule.waitUntil(timeoutMillis = 5_000) {
            dao.current.firstOrNull()?.isCompleted == true
        }
        assertTrue(dao.current.first().completedAt != null)

        // 切到「已完成」tab：分段选项可点，统计卡的「已完成」文案不可点，以此区分
        rule.onNode(hasText("已完成") and hasClickAction()).performClick()
        rule.onNodeWithText("买两箱可乐", substring = true).assertExists()

        // ---- 删除 ----
        rule.onNodeWithContentDescription("删除待办").performClick()
        rule.onNodeWithText("删除这条待办？").assertExists()
        rule.onNodeWithText("删除").performClick()
        rule.waitUntil(timeoutMillis = 5_000) { dao.current.isEmpty() }
        rule.onNodeWithText("还没有已完成的任务").assertExists()
    }

    @Test
    fun todo_addEmptyTitle_doesNotSave() {
        rule.setContent {
            XzgTheme { TodoTestHarness(vm) }
        }
        rule.onNodeWithContentDescription("新增待办").performClick()
        rule.onNodeWithText("新增待办").assertExists()
        // 空标题时保存按钮禁用（生产：TodoEditorSheet canSave=false → V32PrimaryButton enabled=false，
        // 且 doSave 有空标题守卫）。注意 Compose 的 Modifier.clickable(enabled=false) 仍会在语义树中
        // 保留 OnClick action（仅标记 Disabled），故不断言 action 缺失，而断言禁用态。
        rule.onNodeWithText("保存").assertIsNotEnabled()
        rule.waitForIdle()
        assertTrue(dao.current.isEmpty())
    }
}
