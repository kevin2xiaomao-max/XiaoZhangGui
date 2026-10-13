package com.xiaozhanggui.app.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Home
import androidx.compose.ui.graphics.vector.ImageVector
import com.xiaozhanggui.app.ui.theme.v371.V371TestTags

/**
 * 4 Tab（V3.7.1）。对应 iOS `App/RootView.swift` 的原生 TabView：
 * home/todo/calendar/business（首页/待办/日历/经营）。
 *
 * - AI 不再是 Tab：首页 [AICommandEntry][com.xiaozhanggui.app.ui.components.AICommandEntry]
 *   → AI Sheet（见 [com.xiaozhanggui.app.ui.screens.ai.AISheet]）。
 * - 「我的」不再是 Tab：首页右上角头像 → navigationDestination 进 Profile（路由 "profile"）。
 * - 「日程」改名「日历」：Tab 内容即 iOS 日历 Tab 下的 ScheduleView 对应屏
 *  （[com.xiaozhanggui.app.ui.screens.schedule.ScheduleScreen]）；完整月历为二级页（路由 "calendar_month"）。
 *
 * iOS 图标为 SF Symbols：house.fill / checkmark.circle / calendar / chart.bar.fill。
 * 当前用 Material Icons 占位；Phase 5 替换为 SF Symbols 逐一对照的自绘图标。
 *
 * [tag] 取自 [V371TestTags.TAB_HOME]/[V371TestTags.TAB_TODO]/
 * [V371TestTags.TAB_CALENDAR]/[V371TestTags.TAB_BUSINESS]，
 * 与 iOS `V371AccessibilityID.tab*` 逐一对齐（tab.home/tab.todo/tab.calendar/tab.business），供 E2E 定位。
 */
enum class XzgTab(
    val route: String,
    val label: String,
    val icon: ImageVector,
    val selectedIcon: ImageVector,
    val tag: String
) {
    HOME(
        route = "home",
        label = "首页",
        icon = Icons.Outlined.Home,
        selectedIcon = Icons.Filled.Home,
        tag = V371TestTags.TAB_HOME
    ),
    TODO(
        route = "todo",
        label = "待办",
        icon = Icons.Outlined.CheckCircle,
        selectedIcon = Icons.Filled.CheckCircle,
        tag = V371TestTags.TAB_TODO
    ),
    CALENDAR(
        route = "calendar",
        label = "日历",
        icon = Icons.Outlined.CalendarMonth,
        selectedIcon = Icons.Filled.CalendarMonth,
        tag = V371TestTags.TAB_CALENDAR
    ),
    BUSINESS(
        route = "business",
        label = "经营",
        icon = Icons.Outlined.BarChart,
        selectedIcon = Icons.Filled.BarChart,
        tag = V371TestTags.TAB_BUSINESS
    );

    companion object {
        fun fromRoute(route: String?): XzgTab =
            values().find { it.route == route } ?: HOME
    }
}
