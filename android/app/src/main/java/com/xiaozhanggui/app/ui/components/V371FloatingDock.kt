package com.xiaozhanggui.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.DateRange
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.xiaozhanggui.app.ui.theme.v371.LocalV371Colors
import com.xiaozhanggui.app.ui.theme.v371.V371Haptic
import com.xiaozhanggui.app.ui.theme.v371.V371Shadow
import com.xiaozhanggui.app.ui.theme.v371.V371TestTags

/**
 * 悬浮 Dock 的 Tab 项（与导航层的 Tab 枚举解耦；导航 worker 接线时映射即可）。
 */
data class DockTab(
    val id: String,
    val label: String,
    val icon: ImageVector,
    val selectedIcon: ImageVector = icon,
    val testTag: String
)

/**
 * V3.7.1 四 Tab（对应 iOS `FloatingDock.swift` 的 `AppTab`：首页/待办/日历/经营）。
 * 图标为 Material 对照：house.fill→Home / checkmark.circle→CheckCircle /
 * calendar→DateRange / chart.bar.fill→BarChart。
 */
fun v371DockTabs(): List<DockTab> = listOf(
    DockTab("home", "首页", Icons.Outlined.Home, Icons.Filled.Home, V371TestTags.TAB_HOME),
    DockTab("todo", "待办", Icons.Outlined.CheckCircle, Icons.Filled.CheckCircle, V371TestTags.TAB_TODO),
    DockTab("calendar", "日历", Icons.Outlined.DateRange, Icons.Filled.DateRange, V371TestTags.TAB_CALENDAR),
    DockTab("business", "经营", Icons.Outlined.BarChart, Icons.Filled.BarChart, V371TestTags.TAB_BUSINESS)
)

/**
 * S3 FloatingTabDock（对应 iOS `FloatingTabDock`）。
 *
 * 悬浮奶白 dock：S3 允许的半透明面（Android 用 frosted 近似，禁用于内容区）+
 * floating shadow。选中项为胶囊高亮 + 蓝色，点击触发 [V371Haptic.selection]。
 *
 * 注：iOS 基线中 RootView 实际用原生 TabView（悬浮 dock 已退役）；
 * 按设计稿形态实现，是否启用由导航 worker 决定。
 */
@Composable
fun FloatingTabDock(
    tabs: List<DockTab>,
    selectedId: String,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = LocalV371Colors.current
    val haptic = LocalHapticFeedback.current
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(bottom = 10.dp)
            .shadow(
                elevation = V371Shadow.floatingElevation,
                shape = CircleShape,
                spotColor = V371Shadow.floatingColor
            )
            .clip(CircleShape)
            .background(colors.frostedFill)
            .padding(horizontal = 6.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        tabs.forEach { tab ->
            val isSelected = tab.id == selectedId
            val interactionSource = remember { MutableInteractionSource() }
            Column(
                modifier = Modifier
                    .weight(1f)
                    .heightIn(min = 52.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(
                        if (isSelected) colors.gray.copy(alpha = 0.16f) else Color.Transparent
                    )
                    .clickable(
                        interactionSource = interactionSource,
                        indication = null,
                        role = Role.Tab,
                        onClick = {
                            V371Haptic.selection(haptic)
                            onSelect(tab.id)
                        }
                    )
                    .testTag(tab.testTag)
                    .semantics {
                        contentDescription = tab.label
                        selected = isSelected
                    }
                    .padding(vertical = 6.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(3.dp, Alignment.CenterVertically)
            ) {
                Icon(
                    if (isSelected) tab.selectedIcon else tab.icon,
                    contentDescription = null,
                    tint = if (isSelected) colors.blue else colors.textTertiary,
                    modifier = Modifier.padding(top = 0.dp)
                )
                Text(
                    tab.label,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (isSelected) colors.blue else colors.textTertiary
                )
            }
        }
    }
}
