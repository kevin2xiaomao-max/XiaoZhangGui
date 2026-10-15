package com.xiaozhanggui.app.ui.poc.droplet

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.motion.DurationTier
import com.xiaozhanggui.app.ui.motion.FrameRateMonitor
import com.xiaozhanggui.app.ui.motion.FrameRateSampling
import com.xiaozhanggui.app.ui.motion.MotionContext
import com.xiaozhanggui.app.ui.motion.PerfTier
import com.xiaozhanggui.app.ui.poc.PocMotionMath.lerp
import com.xiaozhanggui.app.ui.poc.PocMotionMath.phaseProgress
import com.xiaozhanggui.app.ui.poc.PocSpeed
import com.xiaozhanggui.app.ui.poc.PocSpeedMode
import com.xiaozhanggui.app.ui.theme.rememberReduceMotion
import com.xiaozhanggui.app.ui.theme.v371.V371Radius
import kotlin.math.roundToInt

/**
 * PoC-1 液滴按钮菜单（Design System §2.2 六层动作；合入标准见 Roadmap §3 PoC-1）。
 *
 * 本文件 = 交互 Demo + 确定性静态渲染器（Paparazzi 用）：
 * - [DropletMenuScreen]：真机/模拟器交互入口。锚点按钮经 onGloballyPositioned
 *   实测（Phase A）；点击后按 [resolveDropletMenu] 决议跑六层相位或降级淡入；
 *   展开/收起全程经 [FrameRateSampling] 喂给 [FrameRateMonitor]
 *   （连续 1s <55fps 自动降档，具名 `frame-rate-below-55fps`）。
 * - [DropletMenuOverlay]：纯渲染器。输入 (anchor, container, progress) →
 *   确定性输出；交互屏与 [DropletMenuStatic] 共用，截图与真机同构。
 * - [DropletMenuStatic]：给定 master 进度渲染（Paparazzi：展开中途 0.45 / 稳定态 1.0）。
 *
 * 调试图（PoC 专用，非生产语义）：降级覆盖 NORMAL / NO_ANCHOR /
 * REDUCE_MOTION / ESSENTIAL + 慢放 ×4（慢放逐帧核验相位顺序用）。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DropletMenuScreen(onBack: () -> Unit) {
    val density = LocalDensity.current
    val systemReduceMotion = rememberReduceMotion()

    var demoOverride by remember { mutableStateOf(DemoOverride.NORMAL) }
    var expanded by remember { mutableStateOf(false) }

    val progress = remember { Animatable(0f) }
    val downgradeEvents = remember { mutableStateListOf<FrameRateMonitor.DowngradeEvent>() }
    val monitor = remember { FrameRateMonitor(onDowngrade = { downgradeEvents.add(it) }) }

    // ── Phase A 锚点测量（窗口坐标 → 舞台坐标）──
    var stageOrigin by remember { mutableStateOf(Offset.Zero) }
    var anchorPx by remember { mutableStateOf<AnchorRect?>(null) }
    val anchor: AnchorRect? = if (demoOverride == DemoOverride.NO_ANCHOR) null else anchorPx

    val ctx = MotionContext(
        reduceMotion = demoOverride == DemoOverride.REDUCE_MOTION || systemReduceMotion,
        perfTier = if (demoOverride == DemoOverride.ESSENTIAL) PerfTier.ESSENTIAL else PerfTier.FULL,
        runtimeMaxTransitionKind = monitor.currentMaxTransitionKind(),
    )
    // downgradeEvents.size 参与 key：帧率降档后决议重算（单向降级）。
    val resolution = remember(anchor, ctx, downgradeEvents.size) {
        resolveDropletMenu(anchor, ctx)
    }

    // ── 展开/收起驱动：同一 master 进度正/反播（收起反向执行各相位）──
    // 时长走全局 PocSpeed 缩放（launcher 分段控件 / 深链 ?speed= 切换；
    // 慢放 ×4 便于逐帧核验相位顺序）。档位切换不中断进行中的动画，
    // 下次开启动画生效（PocSpeed.mode 非 LaunchedEffect key）。
    LaunchedEffect(expanded, resolution) {
        val target = if (expanded) 1f else 0f
        if (progress.value == target) return@LaunchedEffect
        val base = if (!resolution.runDropletPhases) {
            resolution.durationTier.ms
        } else {
            DurationTier.STANDARD.ms // 280ms（Phase C 纵向档）
        }
        val ms = PocSpeed.scale(base)
        val stopSampling = FrameRateSampling.start(monitor)
        try {
            progress.animateTo(target, tween(durationMillis = ms))
        } finally {
            stopSampling()
        }
    }

    val p = progress.value
    val settled = p >= 1f && !progress.isRunning
    val showOverlay = p > 0f || expanded

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("PoC-1 液滴按钮菜单") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
            )
        },
    ) { inner ->
        Column(Modifier.fillMaxSize().padding(inner)) {
            // ── PoC 调试图 ──
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                DemoOverride.entries.forEach { o ->
                    OutlinedButton(
                        onClick = { demoOverride = o },
                        modifier = Modifier.weight(1f),
                    ) {
                        Text(
                            when (o) {
                                DemoOverride.NORMAL -> "正常"
                                DemoOverride.NO_ANCHOR -> "无锚点"
                                DemoOverride.REDUCE_MOTION -> "RM"
                                DemoOverride.ESSENTIAL -> "低端档"
                            },
                            style = MaterialTheme.typography.labelSmall,
                            maxLines = 1,
                        )
                    }
                }
                FilterChip(
                    selected = PocSpeed.mode == PocSpeedMode.SLOW,
                    onClick = {
                        PocSpeed.mode =
                            if (PocSpeed.mode == PocSpeedMode.SLOW) {
                                PocSpeedMode.NORMAL
                            } else {
                                PocSpeedMode.SLOW
                            }
                    },
                    label = { Text("慢放", style = MaterialTheme.typography.labelSmall) },
                )
            }
            Text(
                "决议 kind=${resolution.transitionKind} " +
                    "tier=${resolution.durationTier.ms}ms " +
                    "overshoot=${resolution.overshoot} " +
                    "reason=${resolution.downgradeReason ?: "无"} " +
                    "droplet=${resolution.runDropletPhases}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
            )
            Text(
                "帧率采样 downgrade=${downgradeEvents.size}" +
                    (downgradeEvents.lastOrNull()?.let {
                        " 末次 ${it.from}→${it.to} reason=${it.reason}"
                    } ?: "（真机实测，非 CI 环境）"),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 16.dp),
            )

            // ── 舞台 ──
            BoxWithConstraints(
                modifier = Modifier
                    .fillMaxSize()
                    .onGloballyPositioned { stageOrigin = it.boundsInWindow().topLeft },
            ) {
                val cw = constraints.maxWidth.toFloat()
                val ch = constraints.maxHeight.toFloat()

                // 锚点按钮（真实控件；位置与静态截图一致：50% x / 68% y）
                val anchorW = with(density) { ANCHOR_WIDTH_DP.dp.toPx() }
                val anchorH = with(density) { ANCHOR_HEIGHT_DP.dp.toPx() }
                val anchorScale = if (showOverlay && resolution.runDropletPhases) {
                    DropletPhases.anchorScale(p) // Phase B-1
                } else {
                    1f
                }
                Box(Modifier.fillMaxSize()) {
                    AnchorButtonVisual(
                        scale = anchorScale,
                        onClick = { expanded = true },
                        modifier = Modifier
                            .align(Alignment.TopStart)
                            .offset {
                                IntOffset(
                                    (cw * 0.5f - anchorW / 2f).roundToInt(),
                                    (ch * 0.68f - anchorH / 2f).roundToInt(),
                                )
                            }
                            .onGloballyPositioned { coords ->
                                val b = coords.boundsInWindow()
                                val corner = with(density) { V371Radius.control.toPx() }
                                anchorPx = AnchorRect(
                                    left = b.left - stageOrigin.x,
                                    top = b.top - stageOrigin.y,
                                    right = b.right - stageOrigin.x,
                                    bottom = b.bottom - stageOrigin.y,
                                    cornerRadiusPx = corner,
                                )
                            }
                            .testTag("poc_anchor"),
                    )
                }

                // 浮层：液滴六层相位 / 降级标准淡入
                if (showOverlay) {
                    if (resolution.runDropletPhases && anchor != null) {
                        DropletMenuOverlay(
                            anchor = anchor,
                            containerW = cw,
                            containerH = ch,
                            progress = p,
                            settled = settled,
                            density = density,
                            onDismiss = { expanded = false },
                            onItemClick = { expanded = false },
                        )
                    } else {
                        FadeMenuOverlay(
                            progress = p,
                            onDismiss = { expanded = false },
                            onItemClick = { expanded = false },
                        )
                    }
                }
            }
        }
    }
}

/** PoC 调试图的降级覆盖（演示用）。 */
private enum class DemoOverride { NORMAL, NO_ANCHOR, REDUCE_MOTION, ESSENTIAL }

private const val ANCHOR_WIDTH_DP = 160
private const val ANCHOR_HEIGHT_DP = 52

/** 演示菜单项（纯展示数据，无业务语义）。 */
private data class DropletMenuItem(val icon: ImageVector, val label: String)

private val DEMO_ITEMS = listOf(
    DropletMenuItem(Icons.Filled.Add, "新建待办"),
    DropletMenuItem(Icons.Filled.Edit, "快速记账"),
    DropletMenuItem(Icons.Filled.Search, "查找记录"),
    DropletMenuItem(Icons.Filled.Mic, "语音输入"),
)

/** 液滴目标菜单几何（px）。target 圆角 = 标准圆角 token [V371Radius.group]。 */
private data class MenuTarget(
    val centerX: Float,
    val centerY: Float,
    val width: Float,
    val height: Float,
    val cornerPx: Float,
)

private fun computeMenuTarget(
    anchor: AnchorRect,
    cw: Float,
    ch: Float,
    density: Density,
): MenuTarget = with(density) {
    val panelW = 240.dp.toPx()
    val panelH = 16.dp.toPx() + DEMO_ITEMS.size * 56.dp.toPx()
    val margin = 16.dp.toPx()
    val gap = 12.dp.toPx()
    val cx = anchor.centerX.coerceIn(margin + panelW / 2f, cw - margin - panelW / 2f)
    var top = anchor.top - gap - panelH // 优先放锚点上方
    if (top < margin) top = anchor.bottom + gap
    top = top.coerceIn(margin, (ch - margin - panelH).coerceAtLeast(margin))
    MenuTarget(
        centerX = cx,
        centerY = top + panelH / 2f,
        width = panelW,
        height = panelH,
        cornerPx = V371Radius.group.toPx(), // 标准圆角 token（稳定态必须回到此值）
    )
}

/**
 * 液滴浮层纯渲染器（Phase B–F）。
 *
 * 输入 (anchor, container, progress) → 确定性输出；交互屏与 Paparazzi
 * 静态截图共用同一渲染路径（截图与真机同构）。
 *
 * @param settled 稳定态：Phase F"释放临时形变"——用 token 常量绘制，
 *   不再持有中间态 scale/圆角/裁切（p=1 时各纯函数本就精确回到终值，
 *   此处是显式的释放语义 + 浮点漂移兜底）。
 */
@Composable
private fun DropletMenuOverlay(
    anchor: AnchorRect,
    containerW: Float,
    containerH: Float,
    progress: Float,
    settled: Boolean,
    density: Density,
    onDismiss: () -> Unit,
    onItemClick: (DropletMenuItem) -> Unit,
) {
    val p = progress.coerceIn(0f, 1f)
    val target = remember(anchor, containerW, containerH, density) {
        computeMenuTarget(anchor, containerW, containerH, density)
    }

    // ── 六层相位（纯函数；边界精确，见 DropletPhases）──
    val moveP = DropletPhases.moveProgress(p) // B-2（与收缩同起）
    val hFrac = DropletPhases.heightFraction(p) // C 纵向先行
    val wFrac = DropletPhases.widthFraction(p) // C 横向滞后 1/4 相位
    val cT = DropletPhases.cornerT(p) // D 圆角延迟插值
    val alpha = DropletPhases.contentAlpha(p) // E 内容 1/4–3/4 淡入
    val surfAlpha = DropletPhases.surfaceAlpha(p) // 液滴体淡入（几何层）
    val over = DropletPhases.panelOvershoot(p) // F 末段一次过冲
    val taperT = DropletPhases.leadingTaperT(p) // D 前缘锥度

    // ── 几何合成 ──
    val cx = lerp(anchor.centerX, target.centerX, moveP)
    val cy = lerp(anchor.centerY, target.centerY, moveP)
    val w = lerp(anchor.width, target.width, wFrac)
    val h = lerp(anchor.height, target.height, hFrac)
    // Phase F 释放：稳定态直接用 token 常量（与 cT(1)=1 的 lerp 结果一致）
    val cornerPx = if (settled) target.cornerPx else lerp(anchor.cornerRadiusPx, target.cornerPx, cT)
    val taperMaxPx = with(density) { 6.dp.toPx() } // 前缘锥度上限（独立标定）
    val taperPx = if (settled) 0f else taperMaxPx * taperT
    val scale = if (settled) 1f else over

    // 遮罩：随液滴体出现（p∈[0,0.35]），p>0.5 可点收起
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.32f * phaseProgress(p, 0f, 0.35f)))
            .testTag("poc_droplet_scrim")
            .then(if (p > 0.5f) Modifier.clickable { onDismiss() } else Modifier),
    )

    // 液滴体（单一连通主体：从锚点连续生长，无第二个分离主体）
    val shape = with(density) {
        RoundedCornerShape(
            topStart = (cornerPx + taperPx).toDp(), // 前缘（顶部，面板向上生长）
            topEnd = (cornerPx + taperPx).toDp(),
            bottomStart = cornerPx.toDp(),
            bottomEnd = cornerPx.toDp(),
        )
    }
    Box(
        modifier = Modifier
            .offset { IntOffset((cx - w / 2f).roundToInt(), (cy - h / 2f).roundToInt()) }
            .size(with(density) { w.toDp() }, with(density) { h.toDp() })
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
                this.alpha = surfAlpha
                transformOrigin = TransformOrigin.Center
            }
            .shadow(6.dp, shape)
            .clip(shape)
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .testTag("poc_droplet_panel"),
    ) {
        // 内容：Phase E 区间淡入（禁止内容先出现再展开）
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(vertical = 8.dp)
                .graphicsLayer { this.alpha = alpha },
        ) {
            DEMO_ITEMS.forEach { item ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp)
                        .then(
                            if (p > 0.95f) Modifier.clickable { onItemClick(item) }
                            else Modifier,
                        )
                        .padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(item.icon, contentDescription = null)
                    Text(item.label, style = MaterialTheme.typography.bodyLarge)
                }
            }
        }
    }
}

/**
 * 降级路径：标准淡入（no-anchor / reduce-motion / perf-tier-essential /
 * frame-rate）。居中面板，alpha=progress，无位移/无过冲/无锥度。
 */
@Composable
private fun FadeMenuOverlay(
    progress: Float,
    onDismiss: () -> Unit,
    onItemClick: (DropletMenuItem) -> Unit,
) {
    val p = progress.coerceIn(0f, 1f)
    val shape = RoundedCornerShape(V371Radius.group)
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.32f * p))
            .then(if (p > 0.5f) Modifier.clickable { onDismiss() } else Modifier),
    )
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        Surface(
            shape = shape,
            tonalElevation = 6.dp,
            modifier = Modifier
                .graphicsLayer { this.alpha = p }
                .testTag("poc_droplet_panel_fade"),
        ) {
            Column(Modifier.padding(vertical = 8.dp)) {
                DEMO_ITEMS.forEach { item ->
                    Row(
                        modifier = Modifier
                            .size(240.dp, 56.dp)
                            .then(if (p > 0.95f) Modifier.clickable { onItemClick(item) } else Modifier)
                            .padding(horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Icon(item.icon, contentDescription = null)
                        Text(item.label, style = MaterialTheme.typography.bodyLarge)
                    }
                }
            }
        }
    }
}

/** 锚点按钮视觉（圆角 = V371Radius.control token；Phase B-1 缩放由调用方传入）。 */
@Composable
private fun AnchorButtonVisual(
    scale: Float,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(V371Radius.control),
        color = MaterialTheme.colorScheme.primaryContainer,
        modifier = modifier
            .size(ANCHOR_WIDTH_DP.dp, ANCHOR_HEIGHT_DP.dp)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
                transformOrigin = TransformOrigin.Center
            },
    ) {
        Box(contentAlignment = Alignment.Center) {
            Text(
                "快捷操作",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onPrimaryContainer,
            )
        }
    }
}

/**
 * Paparazzi 静态渲染：给定 master 进度确定性绘制（与交互屏同渲染器）。
 *
 * - progress=0.45：展开中途（纵向已 ≈90%、横向滞后、内容半显）；
 * - progress=1.0 + settled：稳定态（几何 == 标准 token）。
 * 调用方用 XzgTheme 包裹（Light/Dark 各一）。
 */
@Composable
fun DropletMenuStatic(progress: Float) {
    val density = LocalDensity.current
    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        val cw = constraints.maxWidth.toFloat()
        val ch = constraints.maxHeight.toFloat()
        // 伪锚点：与交互屏同款位置/尺寸（50% x，68% y，160×52dp）
        val anchor = with(density) {
            val w = ANCHOR_WIDTH_DP.dp.toPx()
            val h = ANCHOR_HEIGHT_DP.dp.toPx()
            val cx = cw * 0.5f
            val cy = ch * 0.68f
            AnchorRect(
                cx - w / 2f, cy - h / 2f, cx + w / 2f, cy + h / 2f,
                V371Radius.control.toPx(),
            )
        }
        Box(Modifier.fillMaxSize()) {
            AnchorButtonVisual(
                scale = DropletPhases.anchorScale(progress),
                onClick = {},
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .offset {
                        IntOffset(
                            (cw * 0.5f - with(density) { ANCHOR_WIDTH_DP.dp.toPx() } / 2f).roundToInt(),
                            (ch * 0.68f - with(density) { ANCHOR_HEIGHT_DP.dp.toPx() } / 2f).roundToInt(),
                        )
                    },
            )
        }
        DropletMenuOverlay(
            anchor = anchor,
            containerW = cw,
            containerH = ch,
            progress = progress,
            settled = progress >= 1f,
            density = density,
            onDismiss = {},
            onItemClick = {},
        )
    }
}
