package com.xiaozhanggui.app.ui.poc.droplet

/**
 * 液滴锚点：可见的出发控件的几何（Design System §2.2 Phase A）。
 *
 * 坐标单位为 px（调用方经 `onGloballyPositioned`/`boundsInRoot` 取得）；
 * 纯数据类，可 JVM 单测。
 *
 * @param left/top/right/bottom 锚点在容器坐标系下的边界（px）
 * @param cornerRadiusPx 锚点圆角（px）：Phase D 圆角插值的起点
 */
data class AnchorRect(
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
    val cornerRadiusPx: Float,
) {
    val width: Float get() = right - left
    val height: Float get() = bottom - top
    val centerX: Float get() = (left + right) / 2f
    val centerY: Float get() = (top + bottom) / 2f

    /**
     * Phase A 可见性判定：零尺寸/负尺寸锚点视为"无可见锚点"，
     * 与 null 锚点走同一条具名降级（`no-anchor`）。
     */
    val isVisible: Boolean get() = width > 0f && height > 0f
}
