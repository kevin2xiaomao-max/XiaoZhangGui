package com.xiaozhanggui.app.ui.poc.transition

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.motion.CapabilityResult
import com.xiaozhanggui.app.ui.motion.OplusProbeItem

/**
 * PoC-4 转场能力探测报告页（`poc/transition`）。
 *
 * 本阶段只展示 [OplusProbeCollector] 的只读探测结果；
 * 无真机证据的项一律以报告文档为准标 **NOT VERIFIED**
 * （见 `docs/ANDROID_V38_OPLUS_PROBE_REPORT.md`）。
 *
 * 生产页禁止引用；仅 debug 构建经 `xzg://poc` 进入。
 */
@Composable
fun TransitionPocScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val items = remember { OplusProbeCollector.collect(context) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("PoC-4 转场能力探测", style = MaterialTheme.typography.headlineSmall)
        Text(
            "只读探测：Class.forName 存在性检查 + 公开 Build 字段；" +
                "未反射调用任何私有 API（无用户授权）。" +
                "无真机证据的项见探测报告，均标 NOT VERIFIED。",
            style = MaterialTheme.typography.bodySmall,
        )
        LazyColumn(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(items, key = { it.id }) { item ->
                ProbeRow(item)
            }
        }
        Button(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
            Text("返回")
        }
    }
}

@Composable
private fun ProbeRow(item: OplusProbeItem) {
    val (statusText, statusColor) = when (val r = item.result) {
        is CapabilityResult.Ok ->
            "OK" to MaterialTheme.colorScheme.primary
        is CapabilityResult.Unsupported ->
            "UNAVAILABLE · ${r.reason}" to MaterialTheme.colorScheme.error
    }
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(item.id, style = MaterialTheme.typography.bodyMedium)
            Text(statusText, style = MaterialTheme.typography.bodySmall, color = statusColor)
        }
        Text(
            "降级链：${item.fallback}",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
