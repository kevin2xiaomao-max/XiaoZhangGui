package com.xiaozhanggui.app.ui.screens.performance

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Inbox
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.SouthWest
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
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
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32EmptyState
import com.xiaozhanggui.app.ui.components.V32SearchField
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * 全部交易页。对应 iOS `TransactionHistoryView`：
 * - 全量交易（不限 30 天），按日期倒序，单 V32Card（insetGrouped），只读
 * - 顶部搜索：标题 / 来源（大小写不敏感）
 * - Empty：ContentUnavailableView（标题"暂无交易"）
 *
 * 注意：标题按任务要求用「交易记录」（iOS 原文为「全部交易」）。
 *
 * @param onBack 返回
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransactionHistoryScreen(onBack: () -> Unit) {
    val vm: PerformanceViewModel = viewModel(factory = remember { performanceViewModelFactory() })
    val performances by vm.performances.collectAsStateWithLifecycle(initialValue = emptyList())
    val expenses by vm.expenses.collectAsStateWithLifecycle(initialValue = emptyList())
    val palettes = LocalXzgPalettes.current

    var searchText by remember { mutableStateOf("") }

    val records = remember(performances, expenses, searchText) {
        val query = searchText.trim().lowercase()
        val all = (performances.map(::toRowItem) + expenses.map(::toExpenseRowItem))
            .sortedByDescending { it.date }
        if (query.isEmpty()) all
        else all.filter {
            it.title.lowercase().contains(query) || it.source.lowercase().contains(query)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("交易记录", style = XzgType.headline, color = palettes.background.textPrimary) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "返回",
                            tint = palettes.background.textPrimary
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = palettes.background.pageBG
                )
            )
        },
        containerColor = palettes.background.pageBG
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .padding(horizontal = XzgDimens.pageMargin, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            V32SearchField(
                value = searchText,
                onValueChange = { searchText = it },
                placeholder = "搜索交易或来源"
            )
            if (records.isEmpty()) {
                V32EmptyState(
                    icon = Icons.Filled.Inbox,
                    title = "暂无交易",
                    message = "导入或记录交易后会显示在这里。"
                )
            } else {
                LazyColumn(modifier = Modifier.weight(1f)) {
                    item(key = "card") {
                        V32Card {
                            Column {
                                records.forEachIndexed { index, record ->
                                    if (index > 0) {
                                        HorizontalDivider(
                                            color = palettes.background.divider,
                                            modifier = Modifier.padding(start = 44.dp)
                                        )
                                    }
                                    TransactionRow(record = record)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/** 对应 iOS TransactionHistoryRow：箭头图标 + 标题 + "dateTime · 来源" + 金额。 */
@Composable
private fun TransactionRow(record: PerformanceRowItem) {
    val palettes = LocalXzgPalettes.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = if (record.isIncome) Icons.Filled.SouthWest else Icons.Filled.NorthEast,
            contentDescription = null,
            tint = if (record.isIncome) palettes.accent.accent else palettes.fixed.danger,
            modifier = Modifier.size(18.dp)
        )
        Spacer(Modifier.width(12.dp))
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Text(
                text = record.title,
                style = XzgType.body,
                color = palettes.background.textPrimary,
                maxLines = 1
            )
            Text(
                text = "${Format.dateTime(record.date)} · ${record.source}",
                style = XzgType.caption,
                color = palettes.background.textTertiary,
                maxLines = 1
            )
        }
        Spacer(Modifier.width(8.dp))
        Text(
            text = (if (record.isIncome) "+" else "-") + Format.money(kotlin.math.abs(record.amount)),
            style = XzgType.body.copy(fontFeatureSettings = "tnum"),
            color = if (record.isIncome) palettes.accent.accent else palettes.fixed.danger,
            maxLines = 1
        )
    }
}
