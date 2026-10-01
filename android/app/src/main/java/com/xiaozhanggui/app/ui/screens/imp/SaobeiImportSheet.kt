package com.xiaozhanggui.app.ui.screens.imp

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.repository.SaobeiImportCommitResult
import com.xiaozhanggui.app.data.repository.SaobeiParsedRow
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.components.V32SecondaryButton
import com.xiaozhanggui.app.ui.components.V32SectionHeader
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 扫呗导入。对应 iOS `SaobeiImportSheet`。
 *
 * - 选择扫呗导出文件（CSV / XLSX；旧版 XLS 拒绝并提示另存）
 * - 解析 → 文件概览（文件/文件记录/有效交易/重复/新增/新增金额）+ 错误行 + 将写入业绩（前 5）
 * - 确认导入 → PerformanceRepository.importSaobei（fingerprint 去重）→ 导入结果
 *
 * 说明：iOS 的 Demo 预览分支与截图 OCR 分支（Vision）在 Android 无对应依赖，不实现。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SaobeiImportSheet(onDismiss: () -> Unit) {
    val palettes = LocalXzgPalettes.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var parseResult by remember { mutableStateOf<SaobeiParseResult?>(null) }
    var errorText by remember { mutableStateOf<String?>(null) }
    var commitResult by remember { mutableStateOf<SaobeiImportCommitResult?>(null) }
    var isParsing by remember { mutableStateOf(false) }

    val performances by remember { XzgGraph.performanceRepository.observeAll() }
        .collectAsStateWithLifecycle(initialValue = emptyList())
    val existing = remember(performances) {
        performances.map { it.fingerprint }.filter { it.isNotEmpty() }.toSet()
    }

    val result = parseResult
    val newRows = remember(result, existing) {
        (result?.rows ?: emptyList()).filter { it.fingerprint !in existing }
    }
    val duplicateCount = remember(result, existing) {
        (result?.rows ?: emptyList()).count { it.fingerprint in existing }
    }
    val fileCount = (result?.rows?.size ?: 0) + (result?.skipped?.size ?: 0)
    val validCount = result?.rows?.count { it.isSuccess } ?: 0
    val displayAmount = newRows.sumOf { it.amount }

    val pickerLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        errorText = null
        commitResult = null
        isParsing = true
        scope.launch {
            try {
                val bytes = withContext(Dispatchers.IO) {
                    context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                        ?: byteArrayOf()
                }
                val fileName = queryDisplayName(context.contentResolver, uri)
                val parsed = withContext(Dispatchers.IO) {
                    SaobeiImportWorker.parse(bytes, fileName)
                }
                parseResult = parsed
                errorText = null
            } catch (e: SaobeiImportError) {
                parseResult = null
                errorText = e.userMessage
            } catch (e: Exception) {
                parseResult = null
                errorText = e.message?.takeIf { it.isNotBlank() } ?: "解析失败，请重试。"
            }
            isParsing = false
        }
    }

    fun commit() {
        val rows = newRows
        val skippedFailed = parseResult?.skipped?.size ?: 0
        scope.launch {
            try {
                val committed = withContext(Dispatchers.IO) {
                    XzgGraph.performanceRepository.importSaobei(rows, skippedFailed)
                }
                commitResult = committed
                parseResult = null
            } catch (e: Exception) {
                errorText = e.message?.takeIf { it.isNotBlank() } ?: "导入失败，请重试。"
            }
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = palettes.background.pageBG
    ) {
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(horizontal = XzgDimens.pageMargin)
                .padding(top = 14.dp, bottom = XzgDimens.bottomPad),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // 头部：左上"关闭" + 居中标题
            Box(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = "扫呗导入",
                    style = XzgType.headline,
                    color = palettes.background.textPrimary,
                    modifier = Modifier.align(Alignment.Center)
                )
                TextButton(
                    onClick = onDismiss,
                    modifier = Modifier.align(Alignment.CenterStart)
                ) {
                    Text(
                        text = "关闭",
                        style = XzgType.body,
                        color = palettes.background.textTertiary
                    )
                }
            }

            // 选择文件卡
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                V32SecondaryButton(
                    text = "选择扫呗导出文件",
                    onClick = { pickerLauncher.launch(arrayOf("*/*")) }
                )
                Text(
                    text = "支持 CSV / XLSX。旧版 XLS 请另存为 XLSX 或 CSV。",
                    style = XzgType.caption,
                    color = palettes.background.textTertiary
                )
            }

            if (isParsing) {
                V32Card {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            color = palettes.accent.accent,
                            strokeWidth = 2.dp
                        )
                        Text(
                            text = "正在解析…",
                            style = XzgType.body,
                            color = palettes.background.textSecondary
                        )
                    }
                }
            }

            errorText?.let { text ->
                V32Card {
                    Row(
                        verticalAlignment = Alignment.Top,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Warning,
                            contentDescription = null,
                            tint = palettes.fixed.danger,
                            modifier = Modifier.size(20.dp)
                        )
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                text = "无法导入",
                                style = XzgType.headline,
                                color = palettes.background.textPrimary
                            )
                            Text(
                                text = text,
                                style = XzgType.subhead,
                                color = palettes.background.textSecondary
                            )
                        }
                    }
                }
            }

            result?.let { parsed ->
                // 文件概览
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    V32SectionHeader("文件概览")
                    V32Card {
                        Column {
                            OverviewRow("文件", parsed.sourceFileName)
                            OverviewRow("文件记录", "$fileCount 笔")
                            OverviewRow("有效交易", "$validCount 笔")
                            OverviewRow("重复", "$duplicateCount 笔")
                            OverviewRow("新增", "${newRows.size} 笔")
                            OverviewRow("新增金额", Format.money(displayAmount), highlight = true)
                            if (parsed.errors.isNotEmpty()) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 10.dp)
                                ) {
                                    Text(
                                        text = "${parsed.errors.size} 行无法解析",
                                        style = XzgType.subhead,
                                        color = palettes.fixed.amber
                                    )
                                }
                            }
                        }
                    }
                }

                // 错误行
                if (parsed.errors.isNotEmpty()) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        V32SectionHeader("错误行")
                        V32Card {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                parsed.errors.take(20).forEach { line ->
                                    Text(
                                        text = line,
                                        style = XzgType.caption,
                                        color = palettes.background.textSecondary,
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                }
                            }
                        }
                    }
                }

                // 将写入业绩
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    V32SectionHeader("将写入业绩")
                    V32Card {
                        if (newRows.isEmpty()) {
                            Text(
                                text = "没有新的成功交易。重复导入不会让营业额翻倍。",
                                style = XzgType.subhead,
                                color = palettes.background.textTertiary,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 8.dp)
                            )
                        } else {
                            Column {
                                newRows.take(5).forEach { row ->
                                    NewRowPreview(row = row)
                                }
                            }
                        }
                    }
                }
            }

            commitResult?.let { committed ->
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    V32SectionHeader("导入结果")
                    V32Card {
                        Column {
                            OverviewRow("新增", "${committed.inserted}")
                            OverviewRow("重复", "${committed.duplicates}")
                            OverviewRow("未计入", "${committed.skippedFailed}")
                        }
                    }
                }
            }

            V32PrimaryButton(
                text = if (commitResult == null) "确认导入" else "完成",
                onClick = { if (commitResult == null) commit() else onDismiss() },
                enabled = !(commitResult == null && newRows.isEmpty())
            )
        }
    }
}

@Composable
private fun OverviewRow(label: String, value: String, highlight: Boolean = false) {
    val palettes = LocalXzgPalettes.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.Bottom
    ) {
        Text(
            text = label,
            style = XzgType.subhead,
            color = palettes.background.textTertiary
        )
        Spacer(Modifier.weight(1f))
        Text(
            text = value,
            style = if (highlight) XzgType.headline else XzgType.body,
            color = if (highlight) palettes.accent.accent else palettes.background.textPrimary,
            modifier = Modifier.padding(start = 12.dp)
        )
    }
}

@Composable
private fun NewRowPreview(row: SaobeiParsedRow) {
    val palettes = LocalXzgPalettes.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp)
    ) {
        Text(
            text = Format.money(row.amount),
            style = XzgType.headline,
            color = palettes.background.textPrimary
        )
        Text(
            text = listOf(
                Format.dateTime(row.date),
                row.paymentMethod,
                row.orderNo
            ).filter { it.isNotEmpty() }.joinToString(" · "),
            style = XzgType.caption,
            color = palettes.background.textTertiary,
            maxLines = 1
        )
    }
}

private fun queryDisplayName(resolver: ContentResolver, uri: Uri): String {
    resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
        if (cursor.moveToFirst()) {
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0) {
                cursor.getString(index)?.takeIf { it.isNotBlank() }?.let { return it }
            }
        }
    }
    return uri.lastPathSegment?.takeIf { it.isNotBlank() } ?: "导入文件"
}
