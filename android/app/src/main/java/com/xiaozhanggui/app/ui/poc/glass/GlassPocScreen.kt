package com.xiaozhanggui.app.ui.poc.glass

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.xiaozhanggui.app.ui.motion.PerfTier
import com.xiaozhanggui.app.ui.poc.PocAutodrive
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.rememberReduceMotion
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

/**
 * PoC-2 隔离演示页（独立 navigation route `poc/glass`，与生产页物理隔离）。
 *
 * 内容：
 * 1. 本机真实能力解析（API / 低内存 / Reduce Motion → 档位 + 具名原因）；
 * 2. 三档展示卡（[GlassTierShowcase] × 3，同一背景域/几何/文字）；
 * 3. 降级模拟：API 29 / 低内存 / Reduce Motion / 低帧率 → 具名降级日志
 *    （只记档位变化，不记业务正文）；
 * 4. T1 帧率采样记录（Choreographer 喂帧 → [GlassFrameSampler]）。
 *
 * release 构建下本 route 不注册（`PocGate.enabled` / `BuildConfig.POC_ENABLED` 门控，
 * 见 `ui.poc.PocNav.pocGraph`）。
 */
@Composable
fun GlassPocScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val palettes = LocalXzgPalettes.current
    val geometry = GlassGeometry.Default

    // ── 本机真实能力 ──
    val apiLevel = Build.VERSION.SDK_INT
    val lowMemory = remember(context) {
        (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).isLowRamDevice
    }
    val reduceMotion = rememberReduceMotion()

    // ── 降级模拟覆盖（null = 用本机真实值）──
    var simApiLevel by remember { mutableStateOf<Int?>(null) }
    var simLowMemory by remember { mutableStateOf<Boolean?>(null) }
    var simReduceMotion by remember { mutableStateOf<Boolean?>(null) }

    // ── T1 帧率采样 ──
    val sampler = remember { GlassFrameSampler() }
    LaunchedEffect(sampler) {
        while (isActive) {
            // 等待下一帧 VSync 再采样；回调内只记时间戳，不做重型工作
            withFrameNanos { sampler.onFrame() }
        }
    }
    DisposableEffect(sampler) { onDispose { sampler.reset() } }
    var simFrameDowngraded by remember { mutableStateOf(false) }

    // ── 具名降级日志（只记档位变化）──
    val resolver = remember {
        GlassTierResolver(
            onDowngrade = { event ->
                // 具名日志：档位变化 + 原因 + 时间戳；绝不含业务正文
                Log.d(
                    "GlassPoC",
                    "downgrade ${event.from.tierId}->${event.to.tierId} " +
                        "reason=${event.reason} at=${event.atMs}",
                )
            },
        )
    }
    val logLines = remember { mutableStateListOf<String>() }

    fun currentParams() = PocParams(
        apiLevel = simApiLevel ?: apiLevel,
        lowMemory = simLowMemory ?: lowMemory,
        reduceMotion = simReduceMotion ?: reduceMotion,
        frameDowngraded = simFrameDowngraded || sampler.isDowngraded,
    )

    fun reResolve() {
        val p = currentParams()
        val resolution = resolver.resolve(
            requested = GlassTier.T1_FIDELITY,
            reduceMotion = p.reduceMotion,
            perfTier = PerfTier.FULL,
            capability = probeGlassTierCapability(
                apiLevel = p.apiLevel,
                lowMemory = p.lowMemory,
            ),
            frameRateDowngraded = p.frameDowngraded,
        )
        // 降级事件快照 → 界面日志行（只含档位变化）
        logLines.clear()
        resolver.downgradeEvents().forEach { event ->
            logLines.add("${event.from.tierId} → ${event.to.tierId}｜${event.reason}")
        }
        if (resolution.downgradeReason == null && logLines.isEmpty()) {
            logLines.add("T1（未降级）")
        }
    }

    // 初次进入解析一次（建立 lastTier 基线，不记事件）
    LaunchedEffect(apiLevel, lowMemory, reduceMotion) { reResolve() }

    // ── autodrive 自动交互驱动（V3.8 真机验收补强；debug only）──
    // ?autodrive=true 深链进入后：三档 T1/T2/T3 循环聚焦切换（显隐只改 alpha，
    // GlassSurface 内 animateFloatAsState 产生真实动画帧），无需触摸。
    // 离屏（composition 销毁）即取消；enabled=false 时手动模式行为零变化。
    val tiers = GlassTier.values()
    val autodrive = PocAutodrive.enabled
    var focusIndex by remember { mutableStateOf(0) }
    LaunchedEffect(autodrive) {
        if (!autodrive) return@LaunchedEffect
        delay(PocAutodrive.WARMUP_MS.toLong())
        while (true) {
            delay(PocAutodrive.GLASS_FOCUS_MS.toLong())
            focusIndex = (focusIndex + 1) % tiers.size
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(geometry.interCardSpacing),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(text = "PoC-2 玻璃三档", fontSize = 20.sp, color = palettes.background.textPrimary)
            TextButton(onClick = onBack) { Text("返回") }
        }

        Text(
            text = "本机：API $apiLevel｜低内存=$lowMemory｜ReduceMotion=$reduceMotion｜" +
                "采样帧=${sampler.sampledFrames().size}｜帧率降档=${sampler.isDowngraded}",
            fontSize = 12.sp,
            color = palettes.background.textSecondary,
        )

        // ── 降级模拟 ──
        Text(text = "降级模拟（具名原因）", fontSize = 14.sp, color = palettes.background.textPrimary)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { simApiLevel = 29; reResolve() }) { Text("API 29") }
            Button(onClick = { simLowMemory = true; reResolve() }) { Text("低内存") }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { simReduceMotion = true; reResolve() }) { Text("ReduceMotion") }
            Button(onClick = { simFrameDowngraded = true; reResolve() }) { Text("低帧率") }
            Button(
                onClick = {
                    simApiLevel = null; simLowMemory = null
                    simReduceMotion = null; simFrameDowngraded = false
                    sampler.reset(); reResolve()
                },
            ) { Text("重置") }
        }

        // ── 具名降级日志 ──
        Text(text = "降级日志（只记档位变化）", fontSize = 14.sp, color = palettes.background.textPrimary)
        logLines.forEach { line ->
            Text(text = line, fontSize = 12.sp, color = palettes.background.textSecondary)
        }

        Spacer(modifier = Modifier.height(4.dp))
        Text(text = "三档展示（同一背景域 / 同一几何 / 同一文字）", fontSize = 14.sp, color = palettes.background.textPrimary)
        if (autodrive) {
            Text(
                text = "autodrive 自动循环中（三档轮切，当前=${tiers[focusIndex].tierId}，无需触摸）",
                fontSize = 12.sp,
                color = palettes.background.textSecondary,
            )
        }
        tiers.forEachIndexed { index, tier ->
            // autodrive 时非聚焦档 alpha 淡出（真实显隐动画帧）；手动模式全显。
            GlassTierShowcase(tier = tier, visible = !autodrive || index == focusIndex)
        }
        Spacer(modifier = Modifier.height(16.dp))
    }
}

/** 降级模拟参数（PoC 屏内部使用） */
private data class PocParams(
    val apiLevel: Int,
    val lowMemory: Boolean,
    val reduceMotion: Boolean,
    val frameDowngraded: Boolean,
)
