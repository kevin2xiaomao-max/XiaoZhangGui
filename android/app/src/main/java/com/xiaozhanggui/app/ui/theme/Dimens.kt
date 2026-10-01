package com.xiaozhanggui.app.ui.theme

import androidx.compose.ui.unit.dp

/**
 * V32 间距 / 圆角。对应 iOS `DesignSystem/V32/V32Layout.swift` + `V32Radius.swift`。
 * 数值与 iOS pt 1:1 对应为 dp。
 */
object XzgDimens {
    // Layout
    val pageMargin = 22.dp
    val sectionGap = 26.dp
    val cardGap = 12.dp
    val bottomPad = 28.dp
    val pageBottomBreathing = 12.dp
    val floatingTabBarReservation = 72.dp
    val cardPad = 16.dp
    val cardPadLarge = 18.dp
    val heroPad = 20.dp
    val rowMinHeight = 56.dp
    val bubbleSmall = 36.dp
    val bubbleRegular = 42.dp
    val iconSmall = 16.dp
    val iconRegular = 19.dp
    val checkbox = 26.dp
    val toolCircle = 40.dp
    val toolIcon = 18.dp
    val avatarSmall = 38.dp
    val avatarLarge = 64.dp

    // Radius
    val card = 18.dp
    val cardLarge = 24.dp
    val bubble = 12.dp
    val sheet = 28.dp
    val inset = 14.dp
    // pill = 999 → Compose 用 CircleShape
}
