package com.xiaozhanggui.app.ui.screens

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * Phase 1 占位页面。Phase 3 按 Parity Matrix §2–§14 实现真实页面。
 */
@Composable
private fun Placeholder(label: String) {
    val palettes = LocalXzgPalettes.current
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(
            text = label,
            style = XzgType.pageTitle,
            color = palettes.background.textPrimary
        )
    }
}

@Composable
fun HomePlaceholderScreen() = Placeholder("首页")

@Composable
fun SchedulePlaceholderScreen() = Placeholder("日程")

@Composable
fun AssistantPlaceholderScreen() = Placeholder("小掌柜")

@Composable
fun TodoPlaceholderScreen() = Placeholder("待办")

@Composable
fun ProfilePlaceholderScreen() = Placeholder("我的")
