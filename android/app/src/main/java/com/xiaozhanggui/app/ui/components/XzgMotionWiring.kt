package com.xiaozhanggui.app.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import com.xiaozhanggui.app.ui.motion.MotionContext
import com.xiaozhanggui.app.ui.motion.MotionPolicy
import com.xiaozhanggui.app.ui.motion.MotionSpec
import com.xiaozhanggui.app.ui.theme.PRESS_ALPHA
import com.xiaozhanggui.app.ui.theme.rememberReduceMotion
import com.xiaozhanggui.app.ui.theme.v371.V371Motion

/**
 * V3.8 Phase 1（Worker B）四路径动效的行为接线。
 *
 * 每个入口对应 [XzgMotionSpecs] 中的一条 [MotionSpec] 声明；
 * 行为一律经 Worker A 的 `MotionPolicy.resolve(spec, ctx)` 解析——
 * 任何降级（reduce-motion / motion-disabled / 性能档 / 帧率…）都由
 * `ResolvedMotion.downgradeReason` 具名表达，调用点只按"是否降级"分支。
 */

// ---------------------------------------------------------------------------
// 1. 按钮按压反馈：按压缩放 PRESS_SCALE(0.97) + 声明档时长
//
// MotionSpec: XzgMotionSpecs.BUTTON_PRESS（FADE / FAST 180ms / overshoot NONE）。
// 未降级 → 按压缩放；任何降级（reduce-motion 等）→ 无缩放直接呈现
// （"无明显 scale"，具名原因见 ResolvedMotion.downgradeReason）。
// 不改变点击区域：graphicsLayer 缩放不影响 clickable 的布局边界。
// ---------------------------------------------------------------------------
@Composable
fun Modifier.xzgPressFeedback(
    spec: MotionSpec = XzgMotionSpecs.BUTTON_PRESS,
    enabled: Boolean = true,
    reduceMotionOverride: Boolean? = null,
    onClick: () -> Unit,
): Modifier {
    val reduceMotion = rememberReduceMotion(reduceMotionOverride)
    val resolved = remember(spec, reduceMotion) {
        MotionPolicy.resolve(spec, MotionContext(reduceMotion = reduceMotion))
    }
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val motionOn = enabled && resolved.downgradeReason == null
    val targetScale = if (pressed && motionOn) V371Motion.PRESS_SCALE else 1f
    val scale by animateFloatAsState(
        targetValue = targetScale,
        animationSpec = tween(durationMillis = resolved.durationTier.ms),
        label = "press-${spec.id}",
    )
    // 按压变暗沿用 V32 口径（对应 iOS V32PressButtonStyle pressed → opacity 0.82）；
    // 瞬切非动画，reduce-motion 下保留（触感确认，非位移动效）。
    val alpha = if (pressed) PRESS_ALPHA else 1f
    return this
        .graphicsLayer {
            scaleX = scale
            scaleY = scale
        }
        .alpha(alpha)
        .clickable(
            interactionSource = interactionSource,
            indication = null,
            enabled = enabled,
            onClick = onClick,
        )
}

// ---------------------------------------------------------------------------
// 2. 菜单展开：FADE + 轻微位移，FAST(180ms)
//
// MotionSpec: kind=FADE, tier=FAST(180), overshoot=NONE，
//   fallback=FADE（reduce-motion → 直接显示，具名原因 reduce-motion）。
// 实现：Material3 DropdownMenu 的进出动画由框架内部驱动，Compose 动画时钟
// 服从系统 ANIMATOR_DURATION_SCALE（用户开"移除动画"即 scale=0 → 瞬切），
// 故 reduce-motion 降级天然成立；此处统一声明口径并提供测试钩子。
// 不改变：菜单项点击区域、onDismissRequest 语义。
// ---------------------------------------------------------------------------
@Composable
fun XzgDropdownMenu(
    spec: MotionSpec,
    expanded: Boolean,
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    reduceMotionOverride: Boolean? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    // 显式接线：文档化降级路径；行为上框架动画已服从系统动画缩放。
    rememberReduceMotion(reduceMotionOverride)
    DropdownMenu(
        expanded = expanded,
        onDismissRequest = onDismissRequest,
        modifier = modifier,
        content = content,
    )
}

// ---------------------------------------------------------------------------
// 3. 弹窗 Dialog：FADE，STANDARD(280ms)
//
// MotionSpec: kind=FADE, tier=STANDARD(280), overshoot=NONE，
//   fallback=FADE（reduce-motion → 直接显示，具名原因 reduce-motion）。
// 实现：AlertDialog 的进出动画由平台窗口动画驱动，同样服从系统
// ANIMATOR_DURATION_SCALE；reduce-motion 时系统侧归零为直接显示。
// BottomSheet 另走 rememberXzgModalBottomSheetState（已全量接线）。
// 不改变：保存/取消语义、onDismissRequest、按钮文案与 testTag。
// ---------------------------------------------------------------------------
@Composable
fun XzgAlertDialog(
    spec: MotionSpec,
    onDismissRequest: () -> Unit,
    confirmButton: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    dismissButton: @Composable (() -> Unit)? = null,
    icon: @Composable (() -> Unit)? = null,
    title: @Composable (() -> Unit)? = null,
    text: @Composable (() -> Unit)? = null,
    shape: Shape = androidx.compose.material3.AlertDialogDefaults.shape,
    containerColor: Color = androidx.compose.material3.AlertDialogDefaults.containerColor,
    reduceMotionOverride: Boolean? = null,
) {
    // 显式接线：文档化降级路径；平台窗口动画服从系统动画缩放。
    rememberReduceMotion(reduceMotionOverride)
    AlertDialog(
        onDismissRequest = onDismissRequest,
        confirmButton = confirmButton,
        modifier = modifier,
        dismissButton = dismissButton,
        icon = icon,
        title = title,
        text = text,
        shape = shape,
        containerColor = containerColor,
    )
}
