package com.xiaozhanggui.app.ui.screens.todo

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.repository.MemoRepository
import com.xiaozhanggui.app.ui.components.ConfirmDeleteDialog
import com.xiaozhanggui.app.ui.components.V32EmptyState
import com.xiaozhanggui.app.ui.components.V32PillBar
import com.xiaozhanggui.app.ui.components.V32SearchField
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** 备忘筛选，对应 iOS MemoFilter：全部 / 文字（无图）/ 图片（有图）/ 语音（恒为空）。 */
enum class MemoFilterTab(val label: String) {
    ALL("全部"),
    TEXT("文字"),
    IMAGE("图片"),
    VOICE("语音")
}

/** 备忘页 ViewModel：memoRepository.observeAll（DAO 已按 updatedAt 倒序）。 */
class MemoViewModel(
    private val memoRepo: MemoRepository
) : ViewModel() {

    val memos: StateFlow<List<MemoEntity>> = memoRepo.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val _error = MutableStateFlow<ScreenError?>(null)
    val error: StateFlow<ScreenError?> = _error.asStateFlow()

    fun clearError() {
        _error.value = null
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
 * 搜索 + 筛选，对应 iOS MemoSearch.filtered：
 * 标题/内容大小写不敏感匹配；语音恒为空；结果按 updatedAt 倒序（DAO 层已排）。
 */
private fun filterMemos(
    memos: List<MemoEntity>,
    query: String,
    filter: MemoFilterTab
): List<MemoEntity> {
    val q = query.trim()
    return memos.filter { memo ->
        val passFilter = when (filter) {
            MemoFilterTab.ALL -> true
            MemoFilterTab.TEXT -> memo.imagePath.isNullOrBlank()
            MemoFilterTab.IMAGE -> !memo.imagePath.isNullOrBlank()
            MemoFilterTab.VOICE -> false
        }
        val passQuery = q.isEmpty() ||
            memo.title.contains(q, ignoreCase = true) ||
            memo.content.contains(q, ignoreCase = true)
        passFilter && passQuery
    }
}

/**
 * 备忘页（导航标题"记录"）。对应 iOS MemoView：
 * V32SearchField（"搜索记录…"）+ V32PillBar（全部/文字/图片/语音）+ MemoCard 垂直列表。
 * 右上 + 打开 MemoEditorSheet；空状态文案照搬 iOS："暂无记录，点击右下角添加"。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MemoScreen() {
    val palettes = LocalXzgPalettes.current
    val vm: MemoViewModel = viewModel(
        factory = XzgGraph.vmFactory { MemoViewModel(XzgGraph.memoRepository) }
    )

    val memos by vm.memos.collectAsStateWithLifecycle()
    val error by vm.error.collectAsStateWithLifecycle()

    var query by remember { mutableStateOf("") }
    var filter by remember { mutableStateOf(MemoFilterTab.ALL) }
    var showEditor by remember { mutableStateOf(false) }
    var editingMemo by remember { mutableStateOf<MemoEntity?>(null) }
    var deletingMemo by remember { mutableStateOf<MemoEntity?>(null) }

    val visible = remember(memos, query, filter) { filterMemos(memos, query, filter) }

    Scaffold(
        containerColor = palettes.background.pageBG,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "记录",
                        style = XzgType.pageTitle,
                        color = palettes.background.textPrimary
                    )
                },
                actions = {
                    IconButton(onClick = {
                        editingMemo = null
                        showEditor = true
                    }) {
                        Icon(
                            imageVector = Icons.Filled.Add,
                            contentDescription = "新增备忘",
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
                .padding(horizontal = XzgDimens.pageMargin)
        ) {
            V32SearchField(
                value = query,
                onValueChange = { query = it },
                placeholder = "搜索记录…",
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(12.dp))
            V32PillBar(
                options = MemoFilterTab.entries.map { it.label },
                selectedIndex = filter.ordinal,
                onSelect = { filter = MemoFilterTab.entries[it] },
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(12.dp))

            if (visible.isEmpty()) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth(),
                    contentAlignment = Alignment.Center
                ) {
                    V32EmptyState(
                        icon = Icons.Filled.EditNote,
                        title = "暂无记录，点击右下角添加"
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth(),
                    contentPadding = PaddingValues(bottom = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(visible, key = { it.id }) { memo ->
                        MemoCard(
                            memo = memo,
                            onClick = {
                                editingMemo = memo
                                showEditor = true
                            },
                            onDeleteClick = { deletingMemo = memo }
                        )
                    }
                }
            }
        }
    }

    if (showEditor) {
        MemoEditorSheet(
            memo = editingMemo,
            onDismiss = {
                showEditor = false
                editingMemo = null
            },
            onSave = { title, content, imagePath ->
                vm.saveMemo(title, content, imagePath, editingMemo)
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
