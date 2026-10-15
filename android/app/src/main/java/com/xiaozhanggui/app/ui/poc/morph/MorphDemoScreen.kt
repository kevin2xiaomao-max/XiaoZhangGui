package com.xiaozhanggui.app.ui.poc.morph

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.poc.PocMotionMath.phaseProgress
import com.xiaozhanggui.app.ui.poc.PocSpeed
import com.xiaozhanggui.app.ui.theme.v371.V371Radius
import kotlin.math.abs
import kotlin.math.sign
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * PoC-3 连续形变 Demo（Roadmap §3 PoC-3）。
 *
 * 两个独立 Demo（同一包络数学 [MorphEnvelope]）：
 * 1. **拖拽形变**：卡片横向拖拽中圆角跟随运动包络（中段隆起）、
 *    运动方向前缘加轻微锥度；松手回弹带末段一次过冲（<3%）；
 * 2. **展开形变**：点击卡片展开/收起（STANDARD 280ms），圆角包络+
 *    末段一次过冲；动画结束后 200ms 释放临时形变。
 *
 * 稳定态语义（合入标准第 2 条）：`tempMorphActive=false` 后，
 * 卡片形状**直接**用 `RoundedCornerShape(V371Radius.group)` token 常量绘制，
 * 不再持有任何中间态圆角/裁切；包络函数在 p=0/1 时本就精确归零，
 * 此处是显式的释放语义。
 *
 * 无快照残留：状态经 [MorphRuntimeState] 持有纯标量；
 * `MorphEnvelopeTest` 反射断言无 Bitmap 字段。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MorphDemoScreen(onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("PoC-3 连续形变") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
            )
        },
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            Text(
                "圆角跟随运动包络 · 前缘锥度 · 末段一次过冲(<3%) · " +
                    "稳定态 200ms 后回到 token（${V371Radius.group}）",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            DragMorphDemo()
            ExpandMorphDemo()
        }
    }
}

/** Demo 1：拖拽形变。 */
@Composable
private fun DragMorphDemo() {
    val density = LocalDensity.current
    val maxDragPx = with(density) { 160.dp.toPx() }
    val scope = rememberCoroutineScope()

    val offsetX = remember { Animatable(0f) }
    var dragging by remember { mutableStateOf(false) }
    var returning by remember { mutableStateOf(false) }
    var cooling by remember { mutableStateOf(false) }
    var returnStartPx by remember { mutableStateOf(0f) }

    val dragP = (abs(offsetX.value) / maxDragPx).coerceIn(0f, 1f)
    val morphActive = dragging || returning || cooling || offsetX.value != 0f

    // 回弹进度 0→1（末段过冲用）；运动方向：回弹时指向中心
    val returnP = if (returning && returnStartPx != 0f) {
        1f - abs(offsetX.value) / abs(returnStartPx)
    } else {
        1f
    }
    val motionSign = when {
        returning && returnStartPx != 0f -> -returnStartPx.sign
        else -> offsetX.value.sign
    }

    val bulge = MorphEnvelope.cornerBulge(dragP)
    val taperT = MorphEnvelope.leadingTaperT(dragP)
    val scale = if (returning) MorphEnvelope.overshootScale(returnP) else 1f

    // ── 形状：活跃态=包络插值；释放态=token 常量（精确）──
    val restR: Dp = V371Radius.group
    val shape = if (!morphActive) {
        RoundedCornerShape(restR)
    } else {
        val r = restR + 8.dp * bulge
        val t = 6.dp * taperT // 前缘锥度上限（独立标定）
        RoundedCornerShape(
            topStart = if (motionSign < 0f) r + t else r,
            bottomStart = if (motionSign < 0f) r + t else r,
            topEnd = if (motionSign > 0f) r + t else r,
            bottomEnd = if (motionSign > 0f) r + t else r,
        )
    }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("拖拽形变", style = MaterialTheme.typography.titleMedium)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp)
                .graphicsLayer {
                    translationX = offsetX.value
                    scaleX = scale
                    scaleY = scale
                    transformOrigin = TransformOrigin.Center
                }
                .clip(shape)
                .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                .draggable(
                    state = rememberDraggableState { delta ->
                        scope.launch {
                            offsetX.snapTo(
                                (offsetX.value + delta).coerceIn(-maxDragPx, maxDragPx),
                            )
                        }
                    },
                    orientation = Orientation.Horizontal,
                    onDragStarted = { dragging = true; cooling = false },
                    onDragStopped = {
                        dragging = false
                        returning = true
                        returnStartPx = offsetX.value
                        // 回弹：位移→0（220ms tween，走全局 PocSpeed 缩放），
                        // scale 经 overshootScale 做单次过冲
                        offsetX.animateTo(0f, tween(durationMillis = PocSpeed.scale(220)))
                        returning = false
                        // 稳定态 200ms 后释放临时形变
                        cooling = true
                        delay(MorphEnvelope.SETTLE_RELEASE_MS)
                        cooling = false
                    },
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text("← 拖拽我 →", style = MaterialTheme.typography.bodyLarge)
        }
        MorphReadout(
            radiusDp = if (morphActive) restR + 8.dp * bulge else restR,
            taperDp = 6.dp * taperT,
            tempMorphActive = morphActive,
        )
    }
}

/** Demo 2：展开形变（点击展开/收起）。 */
@Composable
private fun ExpandMorphDemo() {
    var expanded by remember { mutableStateOf(false) }
    val expandP = remember { Animatable(0f) }
    var cooling by remember { mutableStateOf(false) }

    LaunchedEffect(expanded) {
        // 收起反向执行同一包络（1→0）；时长走全局 PocSpeed 缩放
        expandP.animateTo(if (expanded) 1f else 0f, tween(durationMillis = PocSpeed.scale(280)))
        cooling = true
        delay(MorphEnvelope.SETTLE_RELEASE_MS) // 稳定态 200ms 后释放
        cooling = false
    }

    val ep = expandP.value.coerceIn(0f, 1f)
    val morphActive = expandP.isRunning || cooling
    val bulge = MorphEnvelope.cornerBulge(ep)
    // 末段一次过冲：只作用于尾部 15%（q∈[0,1]→单峰 2.5%）
    val scale = MorphEnvelope.overshootScale(phaseProgress(ep, 0.85f, 1f))
    val contentAlpha = phaseProgress(ep, 0.25f, 0.75f)

    val restR: Dp = V371Radius.group
    val shape = if (!morphActive) {
        RoundedCornerShape(restR) // 释放态：token 常量
    } else {
        RoundedCornerShape(restR + 8.dp * bulge)
    }
    val cardH = 120.dp + (264.dp - 120.dp) * ep

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("展开形变（点击卡片）", style = MaterialTheme.typography.titleMedium)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(cardH)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                    transformOrigin = TransformOrigin.Center
                }
                .clip(shape)
                .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                .clickable { expanded = !expanded },
            contentAlignment = Alignment.TopCenter,
        ) {
            Column(
                Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(if (expanded) "收起" else "展开", style = MaterialTheme.typography.bodyLarge)
                if (contentAlpha > 0f) {
                    Text(
                        "展开内容随几何 1/4→3/4 淡入；末段一次过冲 2.5%。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.graphicsLayer { alpha = contentAlpha },
                    )
                }
            }
        }
        MorphReadout(
            radiusDp = if (morphActive) restR + 8.dp * bulge else restR,
            taperDp = 0.dp,
            tempMorphActive = morphActive,
        )
    }
}

/** PoC 调试图读数：当前圆角/锥度/临时形变持有状态 + token 对照。 */
@Composable
private fun MorphReadout(radiusDp: Dp, taperDp: Dp, tempMorphActive: Boolean) {
    Text(
        "radius=${radiusDp.value.toString().take(5)}dp " +
            "taper=${taperDp.value.toString().take(5)}dp " +
            "tempMorph=$tempMorphActive token=${V371Radius.group}",
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

/**
 * Paparazzi 静态渲染：给定拖拽进度确定性绘制（与交互屏同包络）。
 *
 * - progress=0.5, settled=false：拖拽中途（圆角隆起+前缘锥度可见）；
 * - progress=0.0, settled=true：稳定态（几何 == V371Radius.group token）。
 * 调用方用 XzgTheme 包裹（Light/Dark 各一）。
 */
@Composable
fun MorphCardStatic(progress: Float, settled: Boolean) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(24.dp),
        contentAlignment = Alignment.Center,
    ) {
        val p = progress.coerceIn(0f, 1f)
        val restR: Dp = V371Radius.group
        val shape = if (settled) {
            RoundedCornerShape(restR) // 稳定态：token 精确几何
        } else {
            val r = restR + 8.dp * MorphEnvelope.cornerBulge(p)
            val t = 6.dp * MorphEnvelope.leadingTaperT(p)
            RoundedCornerShape(
                topStart = r,
                bottomStart = r,
                topEnd = r + t, // 前缘（右）锥度
                bottomEnd = r + t,
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp)
                .clip(shape)
                .background(MaterialTheme.colorScheme.surfaceContainerHigh),
            contentAlignment = Alignment.Center,
        ) {
            Text("形变卡片", style = MaterialTheme.typography.bodyLarge)
        }
    }
}
