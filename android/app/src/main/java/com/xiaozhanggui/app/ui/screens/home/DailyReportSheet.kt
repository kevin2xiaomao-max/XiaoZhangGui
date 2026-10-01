package com.xiaozhanggui.app.ui.screens.home

import android.content.Intent
import android.view.HapticFeedbackConstants
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.CustomerStatus
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.ReturnStatus
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.data.repository.ExpiryRepository
import com.xiaozhanggui.app.data.repository.PerformanceRepository
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.ui.components.V32PrimaryButton
import com.xiaozhanggui.app.ui.components.V32SecondaryButton
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlin.math.abs

/**
* 今日经营日报 Sheet。对应 iOS `Features/DailyReport/DailyReportSheet.swift`
* + `DailyReportBuilder.swift`（D_crud.md D9）。
*
* 内容：今日营业额大字 + changeText + 4 行明细（已完成待办/未完成待办/
* 配送待处理/临期待处理）+ 底部「复制文本」「分享」。
* changeText 口径：昨日为 0 → "昨日暂无营业额，无法对比"；
* |change|<0.05 → "与昨日基本持平"；否则 "较昨日增长/下降 x.x%"。
* 分享文本临期行文案照搬 iOS：「临时商品待处理」。
*
* 数据自包含（内部从 XzgGraph 收集 4 个 Flow 构建），shell 层只需
* `DailyReportSheet(onDismiss = …)` 即可展示（抽屉"今日经营报告"→ onOpenSheet("report")）。
*/
data class DailyReport(
val dateMillis: Long,
val todayRevenue: Double,
val yesterdayRevenue: Double,
val completedTodos: Int,
val pendingTodos: Int,
val deliveries: Int,
val pendingExpiry: Int
) {
val changeText: String
get() {
if (yesterdayRevenue <= 0) return "昨日暂无营业额，无法对比"
val change = (todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100
if (abs(change) < 0.05) return "与昨日基本持平"
return "较昨日${if (change >= 0) "增长" else "下降"} ${"%.1f".format(abs(change))}%"
}

val shareText: String
get() = buildString {
appendLine("${Format.formatDate(dateMillis)}")
appendLine("今日营业额：${Format.money(todayRevenue)}")
appendLine(changeText)
appendLine("待办：完成 $completedTodos 件，未完成 $pendingTodos 件")
appendLine("配送：待处理 $deliveries 单")
// 注意：iOS 原文即「临时商品待处理」，parity 照搬
append("临时商品待处理：$pendingExpiry 件")
}

companion object {
fun build(
nowMillis: Long,
performances: List<PerformanceEntity>,
todos: List<TodoEntity>,
customers: List<CustomerRequestEntity>,
expiryItems: List<ExpiryItemEntity>
): DailyReport {
val todayStart = DateExt.startOfDay(nowMillis)
val yesterdayStart = todayStart - 24 * 3600 * 1000L
val todayRevenue = performances
.filter { it.date in todayStart until todayStart + 24 * 3600 * 1000L}
.sumOf { it.amount}
val yesterdayRevenue = performances
.filter { it.date in yesterdayStart until todayStart}
.sumOf { it.amount}
// completedAt 同日计数（缺失 completedAt → 不计）
val completed = todos.count {
it.completedAt!= null && DateExt.isSameDay(it.completedAt, nowMillis)
}
val pending = todos.count {
!it.isCompleted && (it.dueDate == null || DateExt.isSameDay(it.dueDate, nowMillis))
}
val deliveries = customers.count { it.status!= CustomerStatus.DONE}
val expiry = expiryItems.count { it.returnStatus == ReturnStatus.PENDING}
return DailyReport(
dateMillis = nowMillis,
todayRevenue = todayRevenue,
yesterdayRevenue = yesterdayRevenue,
completedTodos = completed,
pendingTodos = pending,
deliveries = deliveries,
pendingExpiry = expiry
)
}

fun empty(nowMillis: Long = System.currentTimeMillis()): DailyReport =
build(nowMillis, emptyList(), emptyList(), emptyList(), emptyList())
}
}

class DailyReportViewModel(
performanceRepository: PerformanceRepository = XzgGraph.performanceRepository,
todoRepository: TodoRepository = XzgGraph.todoRepository,
customerRepository: CustomerRepository = XzgGraph.customerRepository,
expiryRepository: ExpiryRepository = XzgGraph.expiryRepository
): ViewModel() {
val report: StateFlow<DailyReport> = combine(
performanceRepository.observeAll(),
todoRepository.observeAll(),
customerRepository.observeAll(),
expiryRepository.observeAll()
) { performances, todos, customers, expiryItems ->
DailyReport.build(System.currentTimeMillis(), performances, todos, customers, expiryItems)
}.stateIn(
viewModelScope,
SharingStarted.WhileSubscribed(5000),
DailyReport.empty()
)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DailyReportSheet(
onDismiss: () -> Unit,
viewModel: DailyReportViewModel = viewModel(factory = XzgGraph.vmFactory { DailyReportViewModel()})
) {
val palettes = LocalXzgPalettes.current
val bg = palettes.background
val report by viewModel.report.collectAsStateWithLifecycle()
val context = LocalContext.current
val clipboard = LocalClipboardManager.current
val view = LocalView.current

ModalBottomSheet(
onDismissRequest = onDismiss,
containerColor = bg.pageBG,
shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
) {
Column(
modifier = Modifier
.verticalScroll(rememberScrollState())
.padding(horizontal = 22.dp)
.padding(bottom = 28.dp)
) {
// header：「今日经营日报」居中 + 左上「关闭」
Box(
modifier = Modifier
.fillMaxWidth()
.padding(top = 14.dp)
) {
Text(
"今日经营日报",
style = XzgType.headline,
color = bg.textPrimary,
modifier = Modifier.align(Alignment.Center)
)
TextButton(
onClick = onDismiss,
modifier = Modifier.align(Alignment.CenterStart),
contentPadding = PaddingValues(0.dp)
) {
Text("关闭", style = XzgType.body, color = bg.textTertiary)
}
}
Spacer(modifier = Modifier.height(16.dp))

// summary：今日营业额（heroMoney 大字）+ changeText
Column(
modifier = Modifier
.fillMaxWidth()
.padding(vertical = 8.dp),
verticalArrangement = Arrangement.spacedBy(10.dp)
) {
Text("今日营业额", style = XzgType.subhead, color = bg.textSecondary)
Text(Format.money(report.todayRevenue), style = XzgType.heroMoney, color = bg.textPrimary)
Text(report.changeText, style = XzgType.caption, color = bg.textSecondary)
}
Spacer(modifier = Modifier.height(16.dp))

// 4 行明细（每行 48 高，分隔线）
Column {
ReportRow("已完成待办", "${report.completedTodos}")
HorizontalDivider(color = bg.divider, modifier = Modifier.padding(start = 12.dp))
ReportRow("未完成待办", "${report.pendingTodos}")
HorizontalDivider(color = bg.divider, modifier = Modifier.padding(start = 12.dp))
ReportRow("配送待处理", "${report.deliveries}")
HorizontalDivider(color = bg.divider, modifier = Modifier.padding(start = 12.dp))
ReportRow("临期待处理", "${report.pendingExpiry}")
}
Spacer(modifier = Modifier.height(16.dp))

// 底部按钮行：复制文本 + 分享
Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
V32SecondaryButton(
text = "复制文本",
onClick = {
clipboard.setText(AnnotatedString(report.shareText))
view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
},
modifier = Modifier.weight(1f)
)
V32PrimaryButton(
text = "分享",
onClick = {
val intent = Intent(Intent.ACTION_SEND).apply {
type = "text/plain"
putExtra(Intent.EXTRA_TEXT, report.shareText)
}
context.startActivity(Intent.createChooser(intent, "分享今日经营日报"))
},
modifier = Modifier.weight(1f)
)
}
}
}
}

@Composable
private fun ReportRow(label: String, value: String) {
val bg = LocalXzgPalettes.current.background
Row(
modifier = Modifier
.fillMaxWidth()
.heightIn(min = 48.dp),
verticalAlignment = Alignment.CenterVertically
) {
Text(label, style = XzgType.body, color = bg.textSecondary)
Spacer(modifier = Modifier.weight(1f))
Text(
value,
style = XzgType.headline.copy(fontFeatureSettings = "tnum"),
color = bg.textPrimary
)
}
}
