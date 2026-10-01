package com.xiaozhanggui.app.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.DateRange
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * 5 Tab。对应 iOS `DesignSystem/FloatingDock.swift` 的 AppTab：
 * home/schedule/assistant/todo/profile（首页/日程/小掌柜/待办/我的）。
 *
 * iOS 图标为 SF Symbols：house.fill / calendar / checkmark / sparkles / person.fill。
 * 当前用 Material Icons 占位；Phase 5 替换为 SF Symbols 逐一对照的自绘图标。
 */
enum class XzgTab(
    val route: String,
    val label: String,
    val icon: ImageVector,
    val selectedIcon: ImageVector
) {
    HOME(
        route = "home",
        label = "首页",
        icon = Icons.Outlined.Home,
        selectedIcon = Icons.Filled.Home
    ),
    SCHEDULE(
        route = "schedule",
        label = "日程",
        icon = Icons.Outlined.DateRange,
        selectedIcon = Icons.Filled.DateRange
    ),
    ASSISTANT(
        route = "assistant",
        label = "小掌柜",
        icon = Icons.Outlined.AutoAwesome,
        selectedIcon = Icons.Filled.AutoAwesome
    ),
    TODO(
        route = "todo",
        label = "待办",
        icon = Icons.Outlined.CheckCircle,
        selectedIcon = Icons.Filled.CheckCircle
    ),
    PROFILE(
        route = "profile",
        label = "我的",
        icon = Icons.Outlined.Person,
        selectedIcon = Icons.Filled.Person
    );

    companion object {
        fun fromRoute(route: String?): XzgTab =
            values().find { it.route == route } ?: HOME
    }
}
