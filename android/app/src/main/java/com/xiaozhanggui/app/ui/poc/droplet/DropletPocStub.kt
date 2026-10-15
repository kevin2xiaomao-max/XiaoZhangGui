package com.xiaozhanggui.app.ui.poc.droplet

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * PoC-1 液滴按钮菜单占位。
 *
 * route 已在 `ui.poc.PocNav` 注册（`poc/droplet`）。
 * **Worker A 交付真实实现后替换本文件**；生产页禁止引用。
 */
@Composable
fun DropletPocStub(onBack: () -> Unit) {
    PocStubBody(
        title = "PoC-1 液滴按钮菜单",
        note = "占位：Worker A 交付真实实现后替换。合入标准见 ANDROID_V38_ROADMAP §3 PoC-1。",
        onBack = onBack,
    )
}

@Composable
internal fun PocStubBody(title: String, note: String, onBack: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(title, style = MaterialTheme.typography.headlineSmall)
        Text(note, style = MaterialTheme.typography.bodyMedium)
        Button(onClick = onBack) { Text("返回") }
    }
}
