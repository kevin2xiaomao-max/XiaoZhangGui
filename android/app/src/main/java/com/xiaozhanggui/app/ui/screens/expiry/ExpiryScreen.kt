package com.xiaozhanggui.app.ui.screens.expiry

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Redo
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Inventory
import androidx.compose.material.icons.filled.Undo
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.ReturnStatus
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.repository.ExpiryRepository
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.ExpiryGroup
import com.xiaozhanggui.app.domain.ExpiryStats
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.ui.components.BubbleTone
import com.xiaozhanggui.app.ui.components.ConfirmDeleteDialog
import com.xiaozhanggui.app.ui.components.PillTone
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32EmptyState
import com.xiaozhanggui.app.ui.components.V32IconBubble
import com.xiaozhanggui.app.ui.components.V32StatusPill
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/**
 * 临期提醒页。对应 iOS Expiry/ExpiryView.swift。
 *
 * - statCard 三格：3天内到期(danger) / 7天内到期(amber) / 30天内到期(brand)，仅待处理计数
 * - 分组（ExpiryGroup.of）：已过期 / 紧急·3天内 / 注意·7天内 / 安全·30天内 / 较远·30天外 / 已退货；
 *   待处理按 expiryDate 升序，已退货按 (returnedAt ?: expiryDate) 倒序
 * - 行：图标泡 +「名称 ×数量」+「到期 M月d日」+ 状态胶囊 + 退货/恢复按钮（无确认直接切换）+ 删除按钮
 * - 点行 → 编辑 Sheet；右上 + → 新增 Sheet；空状态 + 新增按钮
 */

class ExpiryViewModel(private val repo: ExpiryRepository) : ViewModel() {
    val items: StateFlow<List<ExpiryItemEntity>> =
        repo.observeAll().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    suspend fun toggleReturn(item: ExpiryItemEntity) {
        repo.toggleReturn(item)
    }

    suspend fun delete(item: ExpiryItemEntity) {
        repo.delete(item)
    }
}

/** 剩余天数：到期日 0 点 - 参考日 0 点 */
private fun daysLeft(item: ExpiryItemEntity, nowMillis: Long): Long =
    DateExt.daysBetween(
        DateExt.startOfDay(nowMillis),
        DateExt.startOfDay(item.expiryDate)
    )

private data class ExpiryBucket(
    val group: ExpiryGroup,
    val items: List<ExpiryItemEntity>
)

private fun ExpiryGroup.label(): String = when (this) {
    ExpiryGroup.EXPIRED -> "已过期"
    ExpiryGroup.URGENT_3 -> "紧急 · 3天内"
    ExpiryGroup.URGENT_7 -> "注意 · 7天内"
    ExpiryGroup.SAFE_30 -> "安全 · 30天内"
    ExpiryGroup.LATER -> "较远 · 30天外"
    ExpiryGroup.RETURNED -> "已退货"
}

private fun ExpiryGroup.bubbleTone(): BubbleTone = when (this) {
    ExpiryGroup.EXPIRED, ExpiryGroup.URGENT_3 -> BubbleTone.DANGER
    ExpiryGroup.URGENT_7 -> BubbleTone.AMBER
    ExpiryGroup.SAFE_30 -> BubbleTone.BRAND
    ExpiryGroup.LATER, ExpiryGroup.RETURNED -> BubbleTone.NEUTRAL
}

private fun ExpiryGroup.pillTone(): PillTone = when (this) {
    ExpiryGroup.EXPIRED, ExpiryGroup.URGENT_3, ExpiryGroup.URGENT_7 -> PillTone.EXPIRY
    ExpiryGroup.SAFE_30, ExpiryGroup.RETURNED -> PillTone.DONE
    ExpiryGroup.LATER -> PillTone.PENDING
}

/** 徽标文案：已退货 / 还剩 N 天 / 已过期 N 天 */
private fun badgeText(item: ExpiryItemEntity, nowMillis: Long): String {
    if (item.returnStatus == ReturnStatus.RETURNED) return "已退货"
    val d = daysLeft(item, nowMillis)
    return if (d >= 0) "还剩 $d 天" else "已过期 ${-d} 天"
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExpiryScreen() {
    val palettes = LocalXzgPalettes.current
    val vm: ExpiryViewModel = viewModel(
        factory = XzgGraph.vmFactory { ExpiryViewModel(XzgGraph.expiryRepository) }
    )
    val items by vm.items.collectAsStateWithLifecycle()
    var showNewEditor by remember { mutableStateOf(false) }
    var editingItem by remember { mutableStateOf<ExpiryItemEntity?>(null) }
    var deletingItem by remember { mutableStateOf<ExpiryItemEntity?>(null) }
    var deleteFailed by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    val stats = remember(items) { ExpiryStats.compute(items) }
    val buckets = remember(items) {
        val now = System.currentTimeMillis()
        val pending = items
            .filter { it.returnStatus != ReturnStatus.RETURNED }
            .sortedBy { it.expiryDate }
        val returned = items
            .filter { it.returnStatus == ReturnStatus.RETURNED }
            .sortedByDescending { it.returnedAt ?: it.expiryDate }
        fun inRange(range: IntRange) = pending.filter { daysLeft(it, now) in range }
        listOf(
            ExpiryBucket(ExpiryGroup.EXPIRED, pending.filter { daysLeft(it, now) < 0 }),
            ExpiryBucket(ExpiryGroup.URGENT_3, inRange(0..3)),
            ExpiryBucket(ExpiryGroup.URGENT_7, inRange(4..7)),
            ExpiryBucket(ExpiryGroup.SAFE_30, inRange(8..30)),
            ExpiryBucket(ExpiryGroup.LATER, pending.filter { daysLeft(it, now) > 30 }),
            ExpiryBucket(ExpiryGroup.RETURNED, returned)
        ).filter { it.items.isNotEmpty() }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palettes.background.pageBG)
    ) {
        CenterAlignedTopAppBar(
            title = {
                Text(
                    text = "临期提醒",
                    style = XzgType.headline,
                    color = palettes.background.textPrimary
                )
            },
            actions = {
                IconButton(onClick = { showNewEditor = true }) {
                    Icon(
                        imageVector = Icons.Filled.Add,
                        contentDescription = "新增临期商品",
                        tint = palettes.background.textPrimary
                    )
                }
            },
            colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                containerColor = palettes.background.pageBG
            )
        )
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = XzgDimens.pageMargin)
        ) {
            // 三格统计（仅待处理）
            V32Card(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    StatCell(
                        count = stats.urgentCount,
                        label = "3天内到期",
                        color = palettes.fixed.danger,
                        modifier = Modifier.weight(1f)
                    )
                    Box(
                        modifier = Modifier
                            .width(1.dp)
                            .height(36.dp)
                            .background(palettes.background.divider)
                    )
                    StatCell(
                        count = stats.warningCount,
                        label = "7天内到期",
                        color = palettes.fixed.amber,
                        modifier = Modifier.weight(1f)
                    )
                    Box(
                        modifier = Modifier
                            .width(1.dp)
                            .height(36.dp)
                            .background(palettes.background.divider)
                    )
                    StatCell(
                        count = stats.safeCount,
                        label = "30天内到期",
                        color = palettes.accent.accent,
                        modifier = Modifier.weight(1f)
                    )
                }
            }
            Spacer(modifier = Modifier.height(18.dp))

            if (items.isEmpty()) {
                V32Card(modifier = Modifier.fillMaxWidth()) {
                    V32EmptyState(
                        icon = Icons.Filled.Inventory,
                        title = "暂无临期商品",
                        message = "可以新增一条临期记录",
                        actionText = "新增临期商品",
                        onAction = { showNewEditor = true }
                    )
                }
            } else {
                buckets.forEach { bucket ->
                    Text(
                        text = bucket.group.label(),
                        style = XzgType.caption,
                        color = palettes.background.textTertiary,
                        modifier = Modifier.padding(start = 4.dp, bottom = 10.dp)
                    )
                    V32Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            bucket.items.forEachIndexed { index, item ->
                                if (index > 0) {
                                    HorizontalDivider(
                                        color = palettes.background.divider,
                                        thickness = 1.dp,
                                        modifier = Modifier.padding(start = 48.dp)
                                    )
                                }
                                ExpiryRow(
                                    item = item,
                                    group = bucket.group,
                                    onEdit = { editingItem = item },
                                    onToggleReturn = {
                                        scope.launch {
                                            runCatching { vm.toggleReturn(item) }
                                        }
                                    },
                                    onDelete = { deletingItem = item }
                                )
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(18.dp))
                }
            }
            Spacer(modifier = Modifier.height(XzgDimens.bottomPad))
        }
    }

    if (showNewEditor) {
        ExpiryEditorSheet(item = null, onDismiss = { showNewEditor = false })
    }
    editingItem?.let { item ->
        ExpiryEditorSheet(item = item, onDismiss = { editingItem = null })
    }
    if (deletingItem != null) {
        ConfirmDeleteDialog(
            title = "删除这条临期记录？",
            onConfirm = {
                val target = deletingItem
                deletingItem = null
                if (target != null) {
                    scope.launch {
                        runCatching { vm.delete(target) }
                            .onFailure { deleteFailed = true }
                    }
                }
            },
            onDismiss = { deletingItem = null }
        )
    }
    if (deleteFailed) {
        AlertDialog(
            onDismissRequest = { deleteFailed = false },
            title = { Text(text = "删除失败", style = XzgType.headline) },
            text = { Text(text = "临期记录未删除，请重试。", style = XzgType.body) },
            confirmButton = {
                TextButton(onClick = { deleteFailed = false }) { Text(text = "知道了") }
            }
        )
    }
}

@Composable
private fun StatCell(
    count: Int,
    label: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    val palettes = LocalXzgPalettes.current
    Column(
        modifier = modifier.padding(start = 4.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = count.toString(),
            style = XzgType.metric,
            color = color
        )
        Text(
            text = label,
            style = XzgType.caption,
            color = palettes.background.textTertiary
        )
    }
}

@Composable
private fun ExpiryRow(
    item: ExpiryItemEntity,
    group: ExpiryGroup,
    onEdit: () -> Unit,
    onToggleReturn: () -> Unit,
    onDelete: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val isReturned = item.returnStatus == ReturnStatus.RETURNED
    val now = System.currentTimeMillis()

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 10.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            V32IconBubble(
                icon = Icons.Filled.Alarm,
                tone = group.bubbleTone(),
                size = 34.dp
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column(
                modifier = Modifier
                    .weight(1f)
                    .clickable(onClick = onEdit)
            ) {
                Text(
                    text = "${item.name} ×${item.quantity}",
                    style = XzgType.title,
                    color = palettes.background.textPrimary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = "到期 ${Format.monthDay(item.expiryDate)}",
                    style = XzgType.caption,
                    color = palettes.background.textTertiary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Spacer(modifier = Modifier.width(12.dp))
            V32StatusPill(
                text = badgeText(item, now),
                tone = group.pillTone()
            )
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Spacer(modifier = Modifier.width(46.dp))
            Spacer(modifier = Modifier.weight(1f))
            Row(
                modifier = Modifier
                    .clickable(onClick = onToggleReturn)
                    .padding(horizontal = 8.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = if (isReturned) Icons.AutoMirrored.Filled.Redo else Icons.Filled.Undo,
                    contentDescription = null,
                    tint = palettes.fixed.amber,
                    modifier = Modifier.size(14.dp)
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = if (isReturned) "恢复" else "退货",
                    style = XzgType.pill,
                    color = palettes.fixed.amber
                )
            }
            IconButton(
                onClick = onDelete,
                modifier = Modifier.size(44.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.Delete,
                    contentDescription = "删除",
                    tint = palettes.background.textQuaternary,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}
