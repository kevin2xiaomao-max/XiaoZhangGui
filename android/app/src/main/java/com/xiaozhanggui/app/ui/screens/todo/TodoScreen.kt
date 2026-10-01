package com.xiaozhanggui.app.ui.screens.todo

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.repository.MemoRepository
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.DisplayLogic
import com.xiaozhanggui.app.ui.components.ConfirmDeleteDialog
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32Checkbox
import com.xiaozhanggui.app.ui.components.V32EmptyState
import com.xiaozhanggui.app.ui.components.V32SectionHeader
import com.xiaozhanggui.app.ui.components.V32SegmentedPicker
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
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

/** 待办 5 个 tab，对应 iOS TodoModel.TodoFilter。emptyText 逐字对应 iOS TodoFilter.emptyText。 */
enum class TodoTab(val label: String, val emptyText: String) {
    TODAY("今天", "今天没有待办，去休息一下吧"),
    TOMORROW("明天", "明天暂无待办"),
    OVERDUE("逾期", "没有逾期事项，真棒"),
    DONE("已完成", "还没有已完成的任务"),
    MEMO("备忘", "暂无备忘")
}

/** 优先级文案，对应 iOS TodoPriority.label。 */
private val priorityLabels = listOf("低优先级", "中优先级", "高优先级")

/**
 * 待办页 ViewModel。对应 iOS TodoView 的 @State 数据 + TodoRepository/MemoRepository 调用。
 */
class TodoViewModel(
    private val todoRepo: TodoRepository,
    private val memoRepo: MemoRepository
) : ViewModel() {

    val todos: StateFlow<List<TodoEntity>> = todoRepo.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val memos: StateFlow<List<MemoEntity>> = memoRepo.observeAll()
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

    suspend fun saveMemo(
        title: String,
        content: String,
        imagePath: String?,
        editing: MemoEntity?
    ) {
        if (editing == null) {
            memoRepo.add(title = title, content = content, imagePath = imagePath)
        } else {
            memoRepo.update(editing.copy(title = title, content = content, imagePath = imagePath))
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

    fun deleteMemo(memo: MemoEntity) {
        viewModelScope.launch {
            try {
                memoRepo.delete(memo)
            } catch (e: Exception) {
                _error.value = ScreenError("删除失败", "备忘未删除，请重试。")
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
 * - 备忘：返回空（内容独立渲染 Memo）
 */
private fun filterTodos(todos: List<TodoEntity>, tab: TodoTab): List<TodoEntity> {
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
        TodoTab.MEMO -> emptyList()
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
 * 结构：V32SegmentedPicker（5 tab）+ statsCard（备忘 tab 隐藏）+
 * 分组列表（上午/下午/晚上/待安排）或 备忘 tab 的 Memo 两列 grid。
 * 右上 + 按钮：备忘 tab 打开 MemoEditorSheet，否则打开 TodoEditorSheet。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodoScreen() {
    val palettes = LocalXzgPalettes.current
    val haptic = LocalHapticFeedback.current
    val vm: TodoViewModel = viewModel(
        factory = XzgGraph.vmFactory { TodoViewModel(XzgGraph.todoRepository, XzgGraph.memoRepository) }
    )

    val todos by vm.todos.collectAsStateWithLifecycle()
    val memos by vm.memos.collectAsStateWithLifecycle()
    val togglingIds by vm.togglingIds.collectAsStateWithLifecycle()
    val error by vm.error.collectAsStateWithLifecycle()

    var tab by remember { mutableStateOf(TodoTab.TODAY) }
    var showTodoEditor by remember { mutableStateOf(false) }
    var editingTodo by remember { mutableStateOf<TodoEntity?>(null) }
    var deletingTodo by remember { mutableStateOf<TodoEntity?>(null) }
    var showMemoEditor by remember { mutableStateOf(false) }
    var editingMemo by remember { mutableStateOf<MemoEntity?>(null) }
    var deletingMemo by remember { mutableStateOf<MemoEntity?>(null) }

    val visibleTodos = remember(todos, tab) { filterTodos(todos, tab) }
    val groups = remember(visibleTodos, tab) {
        if (tab == TodoTab.MEMO) emptyList() else groupTodos(visibleTodos)
    }
    val todayCount = remember(todos) { filterTodos(todos, TodoTab.TODAY).size }
    val doneCount = remember(todos) { filterTodos(todos, TodoTab.DONE).size }
    val overdueCount = remember(todos) { filterTodos(todos, TodoTab.OVERDUE).size }

    Scaffold(
        containerColor = palettes.background.pageBG,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "待办",
                        style = XzgType.pageTitle,
                        color = palettes.background.textPrimary
                    )
                },
                actions = {
                    IconButton(onClick = {
                        if (tab == TodoTab.MEMO) {
                            editingMemo = null
                            showMemoEditor = true
                        } else {
                            editingTodo = null
                            showTodoEditor = true
                        }
                    }) {
                        Icon(
                            imageVector = Icons.Filled.Add,
                            contentDescription = if (tab == TodoTab.MEMO) "新增备忘" else "新增待办",
                            tint = palettes.background.textPrimary
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = palettes.background.pageBG
                )
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            V32SegmentedPicker(
                options = TodoTab.entries.map { it.label },
                selectedIndex = tab.ordinal,
                onSelect = { tab = TodoTab.entries[it] },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = XzgDimens.pageMargin)
            )
            Spacer(Modifier.height(12.dp))

            if (tab == TodoTab.MEMO) {
                if (memos.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth(),
                        contentAlignment = Alignment.Center
                    ) {
                        V32EmptyState(
                            icon = Icons.Filled.CheckCircle,
                            title = TodoTab.MEMO.emptyText
                        )
                    }
                } else {
                    LazyVerticalGrid(
                        columns = GridCells.Fixed(2),
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth(),
                        contentPadding = PaddingValues(
                            start = XzgDimens.pageMargin,
                            end = XzgDimens.pageMargin,
                            bottom = 24.dp
                        ),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        items(memos, key = { it.id }) { memo ->
                            MemoCard(
                                memo = memo,
                                onClick = {
                                    editingMemo = memo
                                    showMemoEditor = true
                                },
                                onDeleteClick = { deletingMemo = memo }
                            )
                        }
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth(),
                    contentPadding = PaddingValues(
                        start = XzgDimens.pageMargin,
                        end = XzgDimens.pageMargin,
                        bottom = 24.dp
                    )
                ) {
                    item(key = "stats") {
                        TodoStatsCard(
                            todayCount = todayCount,
                            doneCount = doneCount,
                            overdueCount = overdueCount
                        )
                        Spacer(Modifier.height(12.dp))
                    }
                    if (visibleTodos.isEmpty()) {
                        item(key = "empty") {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 48.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                V32EmptyState(
                                    icon = Icons.Filled.CheckCircle,
                                    title = tab.emptyText
                                )
                            }
                        }
                    } else {
                        groups.forEach { (groupTitle, groupTodos) ->
                            item(key = "header-$groupTitle") {
                                V32SectionHeader(
                                    title = groupTitle,
                                    modifier = Modifier.padding(top = 4.dp, bottom = 4.dp)
                                )
                            }
                            itemsIndexed(groupTodos, key = { _, t -> t.id }) { index, todo ->
                                TodoListRow(
                                    todo = todo,
                                    timeAmber = tab == TodoTab.OVERDUE,
                                    toggleEnabled = !togglingIds.contains(todo.id),
                                    onToggle = {
                                        val completing = !todo.isCompleted
                                        haptic.performHapticFeedback(
                                            if (completing) HapticFeedbackType.LongPress
                                            else HapticFeedbackType.TextHandleMove
                                        )
                                        vm.toggleComplete(todo)
                                    },
                                    onEdit = {
                                        editingTodo = todo
                                        showTodoEditor = true
                                    },
                                    onDelete = { deletingTodo = todo }
                                )
                                if (index < groupTodos.lastIndex) {
                                    HorizontalDivider(color = palettes.background.divider)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

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
    if (showMemoEditor) {
        MemoEditorSheet(
            memo = editingMemo,
            onDismiss = {
                showMemoEditor = false
                editingMemo = null
            },
            onSave = { title, content, imagePath ->
                vm.saveMemo(title, content, imagePath, editingMemo)
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
    if (deletingMemo != null) {
        ConfirmDeleteDialog(
            title = "删除这条备忘？",
            onDismiss = { deletingMemo = null },
            onConfirm = {
                val target = deletingMemo
                deletingMemo = null
                if (target != null) vm.deleteMemo(target)
            }
        )
    }
    error?.let { ScreenErrorDialog(error = it, onDismiss = vm::clearError) }
}

/** 3 格统计卡：待办（品牌色）/ 已完成 / 逾期（>0 时 amber）。备忘 tab 时不显示。 */
@Composable
private fun TodoStatsCard(todayCount: Int, doneCount: Int, overdueCount: Int) {
    val palettes = LocalXzgPalettes.current
    V32Card {
        Row(modifier = Modifier.fillMaxWidth()) {
            TodoStatCell(
                icon = Icons.Filled.WbSunny,
                iconTint = palettes.accent.accent,
                count = todayCount,
                countColor = null,
                label = "待办",
                modifier = Modifier.weight(1f)
            )
            TodoStatCell(
                icon = Icons.Filled.CheckCircle,
                iconTint = palettes.background.neutral,
                count = doneCount,
                countColor = null,
                label = "已完成",
                modifier = Modifier.weight(1f)
            )
            TodoStatCell(
                icon = Icons.Filled.Error,
                iconTint = if (overdueCount > 0) palettes.fixed.amber else palettes.background.neutral,
                count = overdueCount,
                countColor = if (overdueCount > 0) palettes.fixed.amber else null,
                label = "逾期",
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun TodoStatCell(
    icon: ImageVector,
    iconTint: Color,
    count: Int,
    countColor: Color?,
    label: String,
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconTint,
            modifier = Modifier.size(22.dp)
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = count.toString(),
            style = XzgType.metric,
            color = countColor ?: palettes.background.textPrimary
        )
        Text(
            text = label,
            style = XzgType.caption,
            color = palettes.background.textTertiary
        )
    }
}

/**
 * 待办行，对应 iOS TodoListRow：
 * V32Checkbox（切换完成）+ 标题（2 行，完成则灰+删除线）+ 副标题
 * （detail 非空显示 detail，否则优先级 label；高优先级且未完成时 amber）+
 * 右侧 timeText（DisplayLogic.dayTimeLabel，nil→"待安排"）+ trash 删除按钮。
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
    val palettes = LocalXzgPalettes.current
    val subtitle = todo.detail.trim().ifEmpty {
        priorityLabels[todo.priority.coerceIn(0, 2)]
    }
    val subtitleAmber = todo.priority == 2 && !todo.isCompleted
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        V32Checkbox(
            checked = todo.isCompleted,
            // V32Checkbox 无 enabled 参数：300ms 防抖窗口内的点击在回调里直接忽略
            onCheckedChange = { if (toggleEnabled) onToggle() }
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 12.dp)
                .clickable(onClick = onEdit)
        ) {
            Text(
                text = todo.title,
                style = XzgType.headline,
                color = if (todo.isCompleted) palettes.background.textTertiary
                else palettes.background.textPrimary,
                textDecoration = if (todo.isCompleted) TextDecoration.LineThrough else null,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = subtitle,
                style = XzgType.subhead,
                color = if (subtitleAmber) palettes.fixed.amber
                else palettes.background.textSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Text(
            text = DisplayLogic.dayTimeLabel(todo.dueDate, "待安排"),
            style = XzgType.caption,
            color = if (timeAmber) palettes.fixed.amber
            else palettes.background.textTertiary
        )
        IconButton(
            onClick = onDelete,
            modifier = Modifier.size(36.dp)
        ) {
            Icon(
                imageVector = Icons.Filled.Delete,
                contentDescription = "删除待办",
                tint = palettes.background.textTertiary,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

/** 通用错误弹窗（删除/状态切换失败等）。 */
@Composable
internal fun ScreenErrorDialog(error: ScreenError, onDismiss: () -> Unit) {
    val palettes = LocalXzgPalettes.current
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = error.title,
                style = XzgType.headline,
                color = palettes.background.textPrimary
            )
        },
        text = {
            Text(
                text = error.message,
                style = XzgType.body,
                color = palettes.background.textSecondary
            )
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("好") }
        },
        containerColor = palettes.background.card
    )
}
