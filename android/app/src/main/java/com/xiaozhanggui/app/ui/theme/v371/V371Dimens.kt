package com.xiaozhanggui.app.ui.theme.v371

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * V371 Spacing（对应 iOS `V371.Space`）。
 */
object V371Space {
    val page: Dp = 16.dp
    val section: Dp = 20.dp
    val rowGap: Dp = 12.dp
    val rowPadding: Dp = 14.dp
}

/**
 * V371 Semantic Radius（对应 iOS `V371.Radius`；禁止各页面自写随机 radius）。
 */
object V371Radius {
    /** 小控件 / badge 内圆角 */
    val control: Dp = 12.dp

    /** 图标圆 / 小 tile */
    val tile: Dp = 20.dp

    /** S1 分组面 */
    val group: Dp = 24.dp

    /** S2 Hero */
    val hero: Dp = 28.dp

    /** 胶囊：调用方用 CircleShape */
    const val PILL = 999
}

/**
 * V371 Shadow（对应 iOS `V371.Shadow`：柔软浮层感，不厚重；行不加 shadow）。
 *
 * iOS 用 color/radius/y 描述；Compose 的 Modifier.shadow 是 elevation 制，
 * 这里用 elevation + spotColor 近似（已知实现差异）。
 */
object V371Shadow {
    /** hero 蓝：蓝 0.25 alpha，elevation 近似 */
    const val HERO_ALPHA = 0.25f
    val heroElevation: Dp = 10.dp

    /** floating：黑 0.10 alpha，elevation 近似 */
    val floatingColor: Color = Color.Black.copy(alpha = 0.10f)
    val floatingElevation: Dp = 6.dp
    val floatingOffsetY: Dp = 6.dp
}
