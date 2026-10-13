package com.xiaozhanggui.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.xiaozhanggui.app.ui.theme.v371.LocalV371Colors
import com.xiaozhanggui.app.ui.theme.v371.V371Haptic
import com.xiaozhanggui.app.ui.theme.v371.V371Motion
import com.xiaozhanggui.app.ui.theme.v371.V371Radius
import com.xiaozhanggui.app.ui.theme.v371.V371Shadow
import com.xiaozhanggui.app.ui.theme.v371.V371Space
import com.xiaozhanggui.app.ui.theme.v371.V371TestTags
import com.xiaozhanggui.app.ui.theme.v371.V371Type

/**
 * V371 Primitives（11 个，对应 iOS `DesignSystem/V371/V371Primitives.swift`）。
 *
 * HeroMetric / GroupSurface / SectionHeader / WorkRow / TimedRow /
 * StatusBadge / QuickAction / EmptyState / FloatingTabDock（见 V371FloatingDock.kt）/ AICommandEntry。
 * 禁止再新增小组件；调用形态按 iOS 基线实际调用为准，不照抄零调用的设计系统版。
 */

// MARK: - Hairline

/**
 * 行内分隔线（对应 iOS `V371Divider`）。
 * 默认与图标列对齐缩进（52dp），调用方可覆盖。
 */
@Composable
fun V371Divider(leading: Dp = 52.dp, modifier: Modifier = Modifier) {
    val colors = LocalV371Colors.current
    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(start = leading)
            .height(0.5.dp)
            .background(colors.divider)
    )
}

// MARK: - S2 HeroMetric（蓝色能量 Hero）

/**
 * S2 蓝色能量 Hero（对应 iOS `HeroMetric`）。
 *
 * **仅天气详情 sheet 使用**，首页/日历禁用（V3.7.1 口径）。
 * 已知差异：iOS 有两处静态柔光圆（白 16%/10% + blur）；Android 只保留蓝渐变 + 蓝 shadow。
 */
@Composable
fun HeroMetric(
    title: String,
    value: String,
    onClick: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
    info: @Composable () -> Unit = {}
) {
    val colors = LocalV371Colors.current
    val haptic = LocalHapticFeedback.current
    val interactionSource = remember { MutableInteractionSource() }
    Box(
        modifier = modifier
            .fillMaxWidth()
            .shadow(
                elevation = V371Shadow.heroElevation,
                shape = RoundedCornerShape(V371Radius.hero),
                spotColor = colors.blue.copy(alpha = V371Shadow.HERO_ALPHA)
            )
            .clip(RoundedCornerShape(V371Radius.hero))
            .background(
                Brush.linearGradient(
                    colors = listOf(colors.heroTop, colors.heroBottom)
                )
            )
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                enabled = onClick != null,
                role = Role.Button,
                onClick = {
                    V371Haptic.light(haptic)
                    onClick?.invoke()
                }
            )
            .semantics { contentDescription = "$title：$value" }
            .padding(20.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = V371Type.heroTitle, color = Color.White.copy(alpha = 0.82f))
            Text(
                value,
                style = V371Type.heroNumber,
                color = Color.White,
                maxLines = 1
            )
            info()
        }
    }
}

// MARK: - S1 GroupSurface（1 个 section surface + 多行 editorial rows）

/**
 * S1 分组面（对应 iOS `GroupSurface`）：solid 分组色，圆角 24，禁用 material。
 */
@Composable
fun GroupSurface(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    val colors = LocalV371Colors.current
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(V371Radius.group))
            .background(colors.group),
        verticalArrangement = Arrangement.spacedBy(0.dp),
        content = content
    )
}

// MARK: - SectionHeader

/**
 * Section 标题（对应 iOS `SectionHeader`）：17 semibold + 可选 trailing。
 */
@Composable
fun SectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    trailing: @Composable RowScope.() -> Unit = {}
) {
    val colors = LocalV371Colors.current
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, style = V371Type.sectionTitle, color = colors.textPrimary)
        Spacer(modifier = Modifier.width(8.dp).weight(1f))
        trailing()
    }
}

// MARK: - WorkRow（图标圆 + 标题/副标题 + trailing）

/**
 * WorkRow（对应 iOS `WorkRow`）：36×36 图标圆 + 标题/副标题 + trailing，最小高 60dp。
 * 有 onClick 时点击触发 [V371Haptic.light]。
 */
@Composable
fun WorkRow(
    icon: ImageVector,
    iconColor: Color,
    title: String,
    subtitle: String? = null,
    onClick: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
    testTag: String? = null,
    trailing: @Composable RowScope.() -> Unit = {}
) {
    val colors = LocalV371Colors.current
    val haptic = LocalHapticFeedback.current
    val interactionSource = remember { MutableInteractionSource() }
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 60.dp)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                enabled = onClick != null,
                role = Role.Button,
                onClick = {
                    V371Haptic.light(haptic)
                    onClick?.invoke()
                }
            )
            .then(if (testTag != null) Modifier.testTag(testTag) else Modifier)
            .padding(horizontal = V371Space.rowPadding, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(colors.tinted(iconColor)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = iconColor, modifier = Modifier.size(16.dp))
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(title, style = V371Type.rowTitle, color = colors.textPrimary, maxLines = 2)
            if (!subtitle.isNullOrEmpty()) {
                Text(
                    subtitle,
                    style = V371Type.rowSubtitle,
                    color = colors.textTertiary,
                    maxLines = 2
                )
            }
        }
        trailing()
    }
}

/** WorkRow 常用 trailing：chevron（对应 iOS `V371Chevron`） */
@Composable
fun V371Chevron(modifier: Modifier = Modifier) {
    val colors = LocalV371Colors.current
    Icon(
        Icons.Filled.ChevronRight,
        contentDescription = null,
        tint = colors.textTertiary,
        modifier = modifier.size(12.dp)
    )
}

// MARK: - TimedRow（时间列 + 事项，用于「接下来」/ 日程）

/**
 * TimedRow（对应 iOS `TimedRow`）：左侧 4dp 彩色条 + 时间列 + 标题/副标题。
 */
@Composable
fun TimedRow(
    time: String,
    title: String,
    subtitle: String? = null,
    accent: Color = LocalV371Colors.current.blue,
    onClick: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
    trailing: @Composable RowScope.() -> Unit = {}
) {
    val colors = LocalV371Colors.current
    val haptic = LocalHapticFeedback.current
    val interactionSource = remember { MutableInteractionSource() }
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 60.dp)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                enabled = onClick != null,
                role = Role.Button,
                onClick = {
                    V371Haptic.light(haptic)
                    onClick?.invoke()
                }
            )
            .padding(horizontal = V371Space.rowPadding, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // 左侧彩色 accent 条
        Box(
            modifier = Modifier
                .width(4.dp)
                .heightIn(min = 44.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(accent)
        )
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(time, style = V371Type.time, color = colors.textSecondary)
            Text(title, style = V371Type.rowTitle, color = colors.textPrimary, maxLines = 2)
            if (!subtitle.isNullOrEmpty()) {
                Text(
                    subtitle,
                    style = V371Type.rowSubtitle,
                    color = colors.textTertiary,
                    maxLines = 1
                )
            }
        }
        trailing()
    }
}

// MARK: - StatusBadge（彩色微状态胶囊）

/**
 * StatusBadge（对应 iOS `StatusBadge`）：彩色微状态胶囊，底为 13% tint。
 */
@Composable
fun StatusBadge(
    text: String,
    color: Color = LocalV371Colors.current.blue,
    modifier: Modifier = Modifier
) {
    val colors = LocalV371Colors.current
    Text(
        text,
        style = V371Type.badge,
        color = color,
        maxLines = 1,
        modifier = modifier
            .clip(CircleShape)
            .background(colors.tinted(color))
            .padding(horizontal = 10.dp, vertical = 5.dp)
            .semantics { contentDescription = text }
    )
}

// MARK: - QuickAction（快捷入口 tile）

data class QuickActionItem(
    val id: String,
    val icon: ImageVector,
    val title: String,
    val onClick: () -> Unit
)

/**
 * QuickAction（对应 iOS `QuickAction`）：52dp tile + 12sp medium label。
 * 按压缩放 0.97（[V371Motion.PRESS_SCALE]）。
 *
 * 注：iOS 基线中设计系统版 QuickActionRow 零调用；按设计稿形态实现供后续页面使用。
 */
@Composable
fun QuickAction(item: QuickActionItem, modifier: Modifier = Modifier) {
    val colors = LocalV371Colors.current
    val haptic = LocalHapticFeedback.current
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    Column(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 44.dp)
            .graphicsLayer {
                val s = if (pressed) V371Motion.PRESS_SCALE else 1f
                scaleX = s
                scaleY = s
            }
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                role = Role.Button,
                onClick = {
                    V371Haptic.light(haptic)
                    item.onClick()
                }
            )
            .semantics { contentDescription = item.title },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically)
    ) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .clip(RoundedCornerShape(V371Radius.tile))
                .background(colors.group),
            contentAlignment = Alignment.Center
        ) {
            Icon(item.icon, contentDescription = null, tint = colors.blue, modifier = Modifier.size(22.dp))
        }
        Text(item.title, style = V371Type.quickAction, color = colors.textPrimary, maxLines = 1)
    }
}

/** 等宽快捷入口行（对应 iOS `QuickActionRow`） */
@Composable
fun QuickActionRow(items: List<QuickActionItem>, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.Top
    ) {
        items.forEach { item ->
            QuickAction(item = item, modifier = Modifier.weight(1f))
        }
    }
}

// MARK: - EmptyState

/**
 * EmptyState（对应 iOS `EmptyState`）。
 */
@Composable
fun EmptyState(
    icon: ImageVector,
    title: String,
    message: String? = null,
    buttonTitle: String? = null,
    onButtonClick: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val colors = LocalV371Colors.current
    val haptic = LocalHapticFeedback.current
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 36.dp)
            .semantics { contentDescription = title },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = colors.textTertiary,
            modifier = Modifier
                .size(34.dp)
                .padding(bottom = 2.dp)
        )
        Text(
            title,
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold,
            color = colors.textPrimary
        )
        if (message != null) {
            Text(
                message,
                fontSize = 14.sp,
                color = colors.textSecondary
            )
        }
        if (buttonTitle != null && onButtonClick != null) {
            Text(
                buttonTitle,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
                modifier = Modifier
                    .padding(top = 4.dp)
                    .clip(CircleShape)
                    .background(colors.blue)
                    .clickable(
                        role = Role.Button,
                        onClick = {
                            V371Haptic.light(haptic)
                            onButtonClick()
                        }
                    )
                    .padding(horizontal = 20.dp, vertical = 10.dp)
            )
        }
    }
}

// MARK: - AICommandEntry（首页 AI 薄入口，非 Tab）

/**
 * AICommandEntry（对应 iOS `HomeView` 的私有 `AICommandEntry` 变体）。
 *
 * iOS 基线实际调用形态：✦ 图标 38dp 圆（蓝 tint）+ 「问小掌柜」headline +
 * 「查经营、找商品，或安排一件事」副标题 + chevron；S3 frosted 面 18dp 圆角 + hairline 边框。
 * 不照抄零调用的设计系统版（「✦ 问小掌柜…」+ mic 紧凑版）。
 * 点击行为由导航 worker 接线（弹 AI Sheet）。
 */
@Composable
fun AICommandEntry(onClick: () -> Unit, modifier: Modifier = Modifier) {
    val colors = LocalV371Colors.current
    val interactionSource = remember { MutableInteractionSource() }
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(colors.frostedFill)
            .border(0.5.dp, colors.divider.copy(alpha = 0.28f), RoundedCornerShape(18.dp))
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                role = Role.Button,
                onClick = onClick
            )
            .testTag(V371TestTags.HOME_AI)
            .semantics { contentDescription = "问小掌柜，AI 助手" }
            .padding(horizontal = 14.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(38.dp)
                .clip(CircleShape)
                .background(colors.tinted(colors.blue)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Filled.AutoAwesome,
                contentDescription = null,
                tint = colors.blue,
                modifier = Modifier.size(17.dp)
            )
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                "问小掌柜",
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = colors.textPrimary
            )
            Text(
                "查经营、找商品，或安排一件事",
                fontSize = 12.sp,
                color = colors.textSecondary,
                maxLines = 2
            )
        }
        Icon(
            Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = colors.textTertiary,
            modifier = Modifier.size(13.dp)
        )
    }
}
