package com.xiaozhanggui.app.ui.screens.todo

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.DisplayLogic
import com.xiaozhanggui.app.ui.components.ConfirmDeleteDialog
import com.xiaozhanggui.app.ui.components.EmptyState
import com.xiaozhanggui.app.ui.components.GroupSurface
import com.xiaozhanggui.app.ui.components.SectionHeader
import com.xiaozhanggui.app.ui.components.V371Divider
import com.xiaozhanggui.app.ui.theme.v371.LocalV371Colors
import com.xiaozhanggui.app.ui.theme.v371.V371Space
import com.xiaozhanggui.app.ui.theme.v371.V371Theme
import com.xiaozhanggui.app.ui.theme.v371.V371Type
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/**
 * 通用错误弹窗数据（标题 + 消息），待办/备忘两屏共用。
 */
data class ScreenError(val title: String, val message: String)

/** 待办 4 个 tab，对应 iOS TodoModel.TodoFilter。emptyText 逐字对应 iOS TodoFilter.emptyText。
 * V3.7.1：备忘入口迁至经营 Tab menu →「记录」（R13），此处不再保留备忘 segment。 */
enum class TodoTab(val label: String, val emptyText: String) {
    TODAY("今天", "今天没有待办，去休息一下吧"),
    TOMORROW("明天", "明天暂无待办"),
    OVERDUE("逾期", "没有逾期事项，真棒"),
    DONE("已完成", "还没有已完成的任务")
}

/** 优先级文案，对应 iOS TodoPriority.label。 */
private val priorityLabels = listOf("低优先级", "中优先级", "高优先级")

/**
 * 待办页 ViewModel。对应 iOS TodoView 的 @State 数据 + TodoRepository 调用。
 * V3.7.1：备忘改走经营 Tab「记录」独立页（R13），本 ViewModel 不再持有备忘数据。
 */
class TodoViewModel(
    private val todoRepo: TodoRepository
) : ViewModel() {

    val todos: StateFlow<List<TodoEntity>> = todoRepo.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    /**
     * 正在切换完成态的 id：300ms 内忽略重复点击，对应 iOS togglingIDs。
     * UI 侧用它禁用 V32Checkbox。
     */
    private val _togglingIds = MutableStateFlow<Set<String>>(emptySet())
    val togglingIds: StateFlow<Set<String>> = _togglingIds.asStateFlow()

    private val _error = MutableStateFlow<ScreenError?>(null)
    val error: StateFlow<ScreenError?> = _error.asStateFlow()

    fun clearError() {
        _error.value = null
    }

    /**
     * 切换完成态：立即写库（对应 iOS TodoRepository.toggleComplete，
     * 完成时 completedAt=now，取消完成时 completedAt=nil）。
     */
    fun toggleComplete(todo: TodoEntity) {
        if (_togglingIds.value.contains(todo.id)) return
        _togglingIds.value = _togglingIds.value + todo.id
        viewModelScope.launch {
            try {
                todoRepo.toggleComplete(todo)
            } catch (e: Exception) {
                _error.value = ScreenError("操作失败", "待办状态未改变，请重试。")
            }
            delay(300)
            _togglingIds.value = _togglingIds.value - todo.id
        }
    }

    suspend fun saveTodo(
        title: String,
        detail: String,
        dueDate: Long?,
        priority: Int,
        imagePath: String?,
        editing: TodoEntity?
    ) {
        if (editing == null) {
            todoRepo.add(
                title = title,
                detail = detail,
                dueDate = dueDate,
                priority = priority,
                imagePath = imagePath
            )
        } else {
            todoRepo.update(
                editing.copy(
                    title = title,
                    detail = detail,
                    dueDate = dueDate,
                    priority = priority,
                    imagePath = imagePath
                )
            )
        }
    }

    fun deleteTodo(todo: TodoEntity) {
        viewModelScope.launch {
            try {
                todoRepo.delete(todo)
            } catch (e: Exception) {
                _error.value = ScreenError("删除失败", "待办未删除，请重试。")
            }
        }
    }
}

/**
 * Tab 过滤规则，逐字对应 iOS TodoModel.TodoFilter.todos：
 * - 今天：未完成 且（dueDate 为 nil 或落在今天起止内）；dueDate 升序（nil 排最后）
 * - 明天：未完成 且 dueDate 落在明天起止内；dueDate 升序
 * - 逾期：未完成 且 dueDate 非空 且早于今天 0 点；dueDate 升序
 * - 已完成：isCompleted；按 (completedAt ?: createdAt) 倒序
 *
 * internal 可见性供口径一致性测试锁定（语义不变）。
 */
internal fun filterTodos(todos: List<TodoEntity>, tab: TodoTab): List<TodoEntity> {
    val now = System.currentTimeMillis()
    val startToday = DateExt.startOfDay(now)
    val startTomorrow = startToday + 24 * 3600 * 1000L
    val startDayAfter = startTomorrow + 24 * 3600 * 1000L
    return when (tab) {
        TodoTab.TODAY -> todos
            .filter { !it.isCompleted && (it.dueDate == null || (it.dueDate >= startToday && it.dueDate < startTomorrow)) }
            .sortedBy { it.dueDate ?: Long.MAX_VALUE }
        TodoTab.TOMORROW -> todos
            .filter { !it.isCompleted && it.dueDate != null && it.dueDate >= startTomorrow && it.dueDate < startDayAfter }
            .sortedBy { it.dueDate ?: Long.MAX_VALUE }
        TodoTab.OVERDUE -> todos
            .filter { !it.isCompleted && it.dueDate != null && it.dueDate < startToday }
            .sortedBy { it.dueDate ?: Long.MAX_VALUE }
        TodoTab.DONE -> todos
            .filter { it.isCompleted }
            .sortedByDescending { it.completedAt ?: it.createdAt }
    }
}

/**
 * 时间轴分组，逐字对应 iOS TodoModel.TodoFilter.grouped：
 * 按 dueDate 小时分 上午（<12）/ 下午（<18）/ 晚上 / 待安排（nil）；非空组才显示。
 */
private fun groupTodos(todos: List<TodoEntity>): List<Pair<String, List<TodoEntity>>> {
    val order = listOf("上午", "下午", "晚上", "待安排")
    val grouped = todos.groupBy { todo ->
        val due = todo.dueDate
        if (due == null) "待安排" else DateExt.dayPeriod(due)
    }
    return order.mapNotNull { key ->
        val list = grouped[key]
        if (list.isNullOrEmpty()) null else key to list
    }
}

/**
 * 待办页。对应 iOS TodoView（导航标题"待办"）。
 *
 * 结构：V371 胶囊分段选择器（4 tab）+ 平面统计行 + SectionHeader/GroupSurface 分组列表
 *（上午/下午/晚上/待安排）。
 * 右上 + 按钮打开 TodoEditorSheet。
 * V3.7.1：备忘入口迁至经营 Tab menu →「记录」（R13），本页不再含备忘。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodoScreen() {
    val haptic = LocalHapticFeedback.current
    val vm: TodoViewModel = viewModel(
        factory = XzgGraph.vmFactory { TodoViewModel(XzgGraph.todoRepository) }
    )

    val todos by vm.todos.collectAsStateWithLifecycle()
    val togglingIds by vm.togglingIds.collectAsStateWithLifecycle()
    val error by vm.error.collectAsStateWithLifecycle()

    var showTodoEditor by remember { mutableStateOf(false) }
    var editingTodo by remember { mutableStateOf<TodoEntity?>(null) }
    var deletingTodo by remember { mutableStateOf<TodoEntity?>(null) }

    TodoContent(
        todos = todos,
        togglingIds = togglingIds,
        onToggleTodo = { todo ->
            val completing = !todo.isCompleted
            haptic.performHapticFeedback(
                if (completing) HapticFeedbackType.LongPress
                else HapticFeedbackType.TextHandleMove
            )
            vm.toggleComplete(todo)
        },
        onEditTodo = {
            editingTodo = it
            showTodoEditor = true
        },
        onDeleteTodo = { deletingTodo = it },
        onAddTodo = {
            editingTodo = null
            showTodoEditor = true
        }
    )

    if (showTodoEditor) {
        TodoEditorSheet(
            todo = editingTodo,
            onDismiss = {
                showTodoEditor = false
                editingTodo = null
            },
            onSave = { title, detail, dueDate, priority, imagePath ->
                vm.saveTodo(title, detail, dueDate, priority, imagePath, editingTodo)
            }
        )
    }
    if (deletingTodo != null) {
        ConfirmDeleteDialog(
            title = "删除这条待办？",
            onDismiss = { deletingTodo = null },
            onConfirm = {
                val target = deletingTodo
                deletingTodo = null
                if (target != null) vm.deleteTodo(target)
            }
        )
    }
    error?.let { ScreenErrorDialog(error = it, onDismiss = vm::clearError) }
}

/**
 * 待办页纯渲染内容（Paparazzi 截图入口）。
 * tab 为内部状态（截图默认「今天」），编辑 Sheet / 删除确认 / 错误弹窗保留在 [TodoScreen]。
 * V3.7.1：备忘入口迁至经营 Tab menu →「记录」（R13），不再接收备忘数据。
 *
 * V371 视觉（对应 iOS `TodoView`）：胶囊分段选择器 + 平面统计行（非卡片）
 * + SectionHeader / GroupSurface 分组列表。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodoContent(
    todos: List<TodoEntity>,
    initialTab: TodoTab = TodoTab.TODAY,
    togglingIds: Set<String> = emptySet(),
    onToggleTodo: (TodoEntity) -> Unit = {},
    onEditTodo: (TodoEntity) -> Unit = {},
    onDeleteTodo: (TodoEntity) -> Unit = {},
    onAddTodo: () -> Unit = {}
) {
    V371Theme {
        val colors = LocalV371Colors.current
        var tab by remember { mutableStateOf(initialTab) }

        val visibleTodos = remember(todos, tab) { filterTodos(todos, tab) }
        val groups = remember(visibleTodos) { groupTodos(visibleTodos) }
        val todayCount = remember(todos) { filterTodos(todos, TodoTab.TODAY).size }
        val doneCount = remember(todos) { filterTodos(todos, TodoTab.DONE).size }
        val overdueCount = remember(todos) { filterTodos(todos, TodoTab.OVERDUE).size }

        Scaffold(
            // E2E 依赖 "todo.screen"（NavSmokeTest / DeepLinkTodoJourneyTest），保持不动
            modifier = Modifier.testTag("todo.screen"),
            containerColor = colors.canvas,
            topBar = {
                TopAppBar(
                    title = {
                        Text(
                            text = "待办",
                            style = V371Type.sectionTitle,
                            color = colors.textPrimary
                        )
                    },
                    actions = {
                        IconButton(onClick = { onAddTodo() }) {
                            Icon(
                                imageVector = Icons.Filled.Add,
                                contentDescription = "新增待办",
                                tint = colors.blue
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = colors.canvas
                    )
                )
            }
        ) { padding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
            ) {
                TodoSegmentedPicker(
                    options = TodoTab.entries.map { it.label },
                    selectedIndex = tab.ordinal,
                    onSelect = { tab = TodoTab.entries[it] },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = V371Space.page)
                        .testTag("todo.tabPicker")
                )
                Spacer(Modifier.height(12.dp))

                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth(),
                    contentPadding = PaddingValues(
                        start = V371Space.page,
                        end = V371Space.page,
                        top = 4.dp,
                        bottom = 24.dp
                    ),
                    verticalArrangement = Arrangement.spacedBy(V371Space.section)
                ) {
                    item(key = "stats") {
                        TodoStatsRow(
                            todayCount = todayCount,
                            doneCount = doneCount,
                            overdueCount = overdueCount
                        )
                    }
                    if (visibleTodos.isEmpty()) {
                        item(key = "empty") {
                            EmptyState(
                                icon = Icons.Filled.CheckCircle,
                                title = tab.emptyText,
                                message = "新的安排会清晰地出现在这里"
                            )
                        }
                    } else {
                        groups.forEach { (groupTitle, groupTodos) ->
                            item(key = "group-$groupTitle") {
                                Column(
                                    verticalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    SectionHeader(title = groupTitle)
                                    GroupSurface {
                                        groupTodos.forEachIndexed { index, todo ->
                                            if (index > 0) {
                                                V371Divider()
                                            }
                                            TodoListRow(
                                                todo = todo,
                                                timeAmber = tab == TodoTab.OVERDUE,
                                                toggleEnabled = !togglingIds.contains(todo.id),
                                                onToggle = { onToggleTodo(todo) },
                                                onEdit = { onEditTodo(todo) },
                                                onDelete = { onDeleteTodo(todo) }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * V371 胶囊分段选择器（对应 iOS `TodoSegmentedPicker`）：
 * groupSecondary 胶囊底，选中段 group 实心胶囊；文字 13 semibold，
 * 选中 textPrimary / 未选中 textTertiary。
 */
@Composable
private fun TodoSegmentedPicker(
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = LocalV371Colors.current
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(CircleShape)
            .background(colors.groupSecondary)
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        options.forEachIndexed { index, option ->
            val selected = index == selectedIndex
            Box(
                modifier = Modifier
                    .weight(1f)
                    .heightIn(min = 44.dp)
                    .clip(CircleShape)
                    .background(if (selected) colors.group else Color.Transparent)
                    .clickable(onClick = { onSelect(index) })
                    .semantics {
                        contentDescription = option
                    },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = option,
                    style = V371Type.rowSubtitle.copy(fontWeight = FontWeight.SemiBold),
                    color = if (selected) colors.textPrimary else colors.textTertiary,
                    maxLines = 1
                )
            }
        }
    }
}

/**
 * 平面统计行（对应 iOS `TodoView.statsRow`）：非卡片，三格数字 + hairline 分隔。
 * 数字 24 semibold 等宽；label 13 regular 三级文本。
 * 留白收紧：卡片内边距改为平面行（P1 留白检查）。
 */
@Composable
private fun TodoStatsRow(todayCount: Int, doneCount: Int, overdueCount: Int) {
    val colors = LocalV371Colors.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp)
            .semantics(mergeDescendants = true) {
                contentDescription = "待办 $todayCount，已完成 $doneCount，逾期 $overdueCount"
            },
        verticalAlignment = Alignment.CenterVertically
    ) {
        TodoStatCell(
            value = todayCount,
            label = "待办",
            tint = colors.blue,
            modifier = Modifier.weight(1f)
        )
        TodoStatDivider()
        TodoStatCell(
            value = doneCount,
            label = "已完成",
            tint = colors.green,
            modifier = Modifier.weight(1f)
        )
        TodoStatDivider()
        TodoStatCell(
            value = overdueCount,
            label = "逾期",
            tint = if (overdueCount > 0) colors.orange else colors.textTertiary,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun TodoStatCell(value: Int, label: String, tint: Color, modifier: Modifier = Modifier) {
    val colors = LocalV371Colors.current
    Column(
        modifier = modifier
            .padding(vertical = 2.dp)
            .padding(start = 12.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp)
    ) {
        Text(
            text = value.toString(),
            style = V371Type.rowTitle.copy(
                fontSize = 24.sp,
                fontWeight = FontWeight.SemiBold,
                fontFeatureSettings = "tnum"
            ),
            color = if (value > 0) tint else colors.textPrimary
        )
        Text(
            text = label,
            style = V371Type.rowSubtitle,
            color = colors.textTertiary
        )
    }
}

@Composable
private fun TodoStatDivider() {
    val colors = LocalV371Colors.current
    Box(
        modifier = Modifier
            .width(0.5.dp)
            .height(30.dp)
            .background(colors.divider)
    )
}

/**
 * 待办行（对应 iOS `TodoListRow` 的 Android 形态）：
 * 完成圈（完成=绿实心 / 未完成=优先级色描边）+ 标题（17 semibold，完成则灰+删除线）
 * + 副标题（13 regular；高优先级未完成时 amber）+ 右侧时间列（13 semibold 等宽）
 * + 删除按钮。
 *
 * 行结构/交互保持 Android 现有（checkbox 语义 + 整列点击编辑 + trash 删除），
 * 仅视觉向 V371 对齐。E2E 依赖 "todo.toggle"，保持不动。
 */
@Composable
private fun TodoListRow(
    todo: TodoEntity,
    timeAmber: Boolean,
    toggleEnabled: Boolean,
    onToggle: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = LocalV371Colors.current
    val subtitle = todo.detail.trim().ifEmpty {
        priorityLabels[todo.priority.coerceIn(0, 2)]
    }
    val subtitleAmber = todo.priority == 2 && !todo.isCompleted
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 10.dp, vertical = 10.dp)
            .heightIn(min = 48.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        TodoToggleCircle(
            checked = todo.isCompleted,
            priority = todo.priority,
            // 300ms 防抖窗口内的点击在回调里直接忽略（原 V32Checkbox 语义）
            onCheckedChange = { if (toggleEnabled) onToggle() },
            modifier = Modifier.testTag("todo.toggle")
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 12.dp)
                .clickable(onClick = onEdit)
        ) {
            Text(
                text = DisplayLogic.visible(todo.title, "待办事项"),
                style = V371Type.sectionTitle,
                color = if (todo.isCompleted) colors.textTertiary
                else colors.textPrimary,
                textDecoration = if (todo.isCompleted) TextDecoration.LineThrough else null,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = subtitle,
                style = V371Type.rowSubtitle,
                color = if (subtitleAmber) colors.orange
                else colors.textSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Text(
            text = DisplayLogic.dayTimeLabel(todo.dueDate, "待安排"),
            style = V371Type.time,
            color = if (timeAmber) colors.orange
            else colors.textTertiary
        )
        IconButton(
            onClick = onDelete,
            modifier = Modifier.size(36.dp)
        ) {
            Icon(
                imageVector = Icons.Filled.Delete,
                contentDescription = "删除待办",
                tint = colors.textTertiary,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

/**
 * V371 待办完成圈（对应 iOS `TodoListRow.toggleButton`）：
 * 完成 = 绿实心圆 + 白对勾；未完成 = 优先级色描边圆
 *（高=红 / 中=橙 / 低=灰，对应 iOS rowColor）。
 */
@Composable
private fun TodoToggleCircle(
    checked: Boolean,
    priority: Int,
    onCheckedChange: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = LocalV371Colors.current
    val ringColor = when (priority.coerceIn(0, 2)) {
        2 -> colors.red
        1 -> colors.orange
        else -> colors.gray
    }
    Box(
        modifier = modifier
            .size(26.dp)
            .clip(CircleShape)
            .background(if (checked) colors.green else Color.Transparent)
            .then(
                if (checked) Modifier
                else Modifier.border(1.6.dp, ringColor.copy(alpha = 0.8f), CircleShape)
            )
            .clickable(onClick = onCheckedChange),
        contentAlignment = Alignment.Center
    ) {
        if (checked) {
            Icon(
                imageVector = Icons.Filled.Check,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(13.dp)
            )
        }
    }
}

/** 通用错误弹窗（删除/状态切换失败等），视觉向 V371 对齐。 */
@Composable
internal fun ScreenErrorDialog(error: ScreenError, onDismiss: () -> Unit) {
    val colors = LocalV371Colors.current
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = error.title,
                style = V371Type.sectionTitle,
                color = colors.textPrimary
            )
        },
        text = {
            Text(
                text = error.message,
                style = V371Type.rowTitle,
                color = colors.textSecondary
            )
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("好", color = colors.blue) }
        },
        containerColor = colors.group
    )
}
