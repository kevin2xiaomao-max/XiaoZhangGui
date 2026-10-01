package com.xiaozhanggui.app.ui.screens

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgType

/**
 * 占位页面。Phase 3 已接入真实页面的占位（首页/待办/我的）已删除；
 * 保留日程占位（Phase 3b 实现）与小掌柜 AI 桩（Phase 4 实现）。
 */
@Composable
private fun Placeholder(label: String) {
    val palettes = LocalXzgPalettes.current
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(
            text = label,
            style = XzgType.pageTitle,
            color = palettes.background.textPrimary,
            textAlign = TextAlign.Center
        )
    }
}

/** 日程页占位（Phase 3b 实现）。 */
@Composable
fun SchedulePlaceholderScreen(label: String = "日程") = Placeholder(label)

/**
 * 小掌柜 AI 对话桩（Phase 4 实现）。
 * 无任何按钮：避免用户误以为可用。
 */
@Composable
fun AssistantPhase4Stub() = Placeholder("小掌柜 AI 对话 Phase 4 实现")
