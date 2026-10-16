package com.xiaozhanggui.app.ui.poc.perf

import android.app.Activity
import android.os.SystemClock
import android.widget.Toast
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.xiaozhanggui.app.ui.poc.PocSpeed
import com.xiaozhanggui.app.ui.poc.PocSpeedMode
import com.xiaozhanggui.app.ui.poc.droplet.DropletMenuStatic
import com.xiaozhanggui.app.ui.poc.glass.GlassTier
import com.xiaozhanggui.app.ui.poc.glass.GlassTierShowcase
import com.xiaozhanggui.app.ui.poc.morph.MorphCardStatic
import com.xiaozhanggui.app.ui.theme.rememberReduceMotion
import java.util.Locale
import kotlin.math.abs
import kotlinx.coroutines.delay

/**
 * PoC 真机性能测试屏（V3.8 真机验收补强 · Worker 3；debug only）。
 *
 * 目标：不接电脑，在真机上完成初步性能验收（≥55fps 判定）。
 *
 * 流程：
 * 1. 「开始测试」→ 依次对 droplet / glass / morph 跑固定时长动画序列
 *    （每段 [STAGE_SEC]s，动画内容复用各 PoC 的确定性渲染器：
 *    [DropletMenuStatic] / [GlassTierShowcase] / [MorphCardStatic]，
 *    程序化循环驱动，无需触摸）；
 * 2. 每段用 [PerfFrameCollector]（FrameMetrics 公开 API）采集真实帧，
 *    [PerfStats] 计算 p50 / p95 / 掉帧率并判定（p95 ≤ 18.18ms → PASS）；
 * 3. 「分享报告」/「保存到下载目录」导出 Markdown（含机型/系统/刷新率/
 *    各 PoC 统计/判定 + 原始分桶摘要）。
 *
 * 门控：只在 `PocGraph`（[PocGate.enabled]）注册；release 构建不可见。
 * 红线：生产业务零引用；只读设备信息，不写库；不碰 Room / Repository / AI。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PerfTestScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val activity = context as? Activity
    val reduceMotion = rememberReduceMotion()

    var phase by remember { mutableStateOf(PerfPhase.IDLE) }
    var runId by remember { mutableIntStateOf(0) }
    var currentStageIdx by remember { mutableIntStateOf(-1) }
    var results by remember { mutableStateOf<List<PerfStats.StageSummary>>(emptyList()) }
    var rawBuckets by remember { mutableStateOf<Map<String, Map<Int, Long>>>(emptyMap()) }

    val device = remember(context, reduceMotion) {
        PerfReport.collectDeviceInfo(context, reduceMotion)
    }

    // ── 测试编排：固定时长动画序列 + 逐段帧采集 ──
    if (phase == PerfPhase.RUNNING) {
        LaunchedEffect(runId) {
            // 真实速度下测量：慢放档临时关闭，结束后恢复
            val prevSpeed = PocSpeed.mode
            PocSpeed.mode = PocSpeedMode.NORMAL
            try {
                val acc = mutableListOf<PerfStats.StageSummary>()
                val bucketAcc = mutableMapOf<String, Map<Int, Long>>()
                PERF_STAGES.forEachIndexed { idx, stage ->
                    currentStageIdx = idx
                    val collector = PerfFrameCollector()
                    val started = activity?.let { collector.start(it) } == true
                    val t0 = SystemClock.elapsedRealtime()
                    delay(STAGE_MS) // 动画由 StageAnimation 自行循环驱动
                    val buckets = if (started) collector.stop() else emptyMap()
                    val durSec = (SystemClock.elapsedRealtime() - t0) / 1000.0
                    bucketAcc[stage.id] = buckets
                    acc.add(PerfStats.summarize(stage.id, stage.name, buckets, durSec))
                    results = acc.toList() // 逐段刷新
                }
                rawBuckets = bucketAcc
            } finally {
                PocSpeed.mode = prevSpeed
                currentStageIdx = -1
                phase = PerfPhase.DONE
            }
        }
    }

    val markdown = remember(results, rawBuckets, device) {
        PerfReport.buildMarkdown(device, results, rawBuckets)
    }
    val reportName = remember(results) { PerfReport.fileName() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("性能测试（真机帧率）") },
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
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // ── 设备信息 ──
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text("机型：${device.model}", style = MaterialTheme.typography.bodyMedium)
                    Text(
                        "系统：Android ${device.androidVersion}（API ${device.apiLevel}）",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Text(
                        "刷新率：${"%.1f".format(Locale.US, device.refreshRateHz)} Hz" +
                            "｜Reduce Motion：${if (device.reduceMotion) "开" else "关"}",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Text(
                        "判定：≥55fps ⇔ p95 ≤ " +
                            "${"%.2f".format(Locale.US, PerfStats.FRAME_BUDGET_55FPS_MS)}ms",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            // ── 测试中：动画视口 ──
            if (phase == PerfPhase.RUNNING && currentStageIdx >= 0) {
                val stage = PERF_STAGES[currentStageIdx]
                Text(
                    "正在测试：${stage.name}（每段 ${STAGE_SEC}s，请勿触摸）",
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.primary,
                )
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(340.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(MaterialTheme.colorScheme.surfaceContainerLow),
                    contentAlignment = Alignment.Center,
                ) {
                    StageAnimation(stage.id)
                }
            }

            // ── 各段结果 ──
            PERF_STAGES.forEachIndexed { idx, stage ->
                val r = results.find { it.stageId == stage.id }
                Card(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(stage.name, style = MaterialTheme.typography.titleSmall)
                            Text(
                                when {
                                    phase == PerfPhase.RUNNING && idx == currentStageIdx ->
                                        "采集中…"
                                    r == null -> "未测试"
                                    r.verdict == PerfStats.Verdict.NO_DATA -> "无数据（采集失败）"
                                    else -> "帧数 ${r.frameCount}｜p50 " +
                                        "${"%.1f".format(Locale.US, r.p50Ms)}ms｜p95 " +
                                        "${"%.1f".format(Locale.US, r.p95Ms)}ms｜" +
                                        "掉帧率 ${"%.1f%%".format(Locale.US, r.dropRate * 100)}"
                                },
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        VerdictChip(r?.verdict)
                    }
                }
            }

            // ── 操作 ──
            Button(
                onClick = {
                    results = emptyList()
                    rawBuckets = emptyMap()
                    runId += 1
                    phase = PerfPhase.RUNNING
                },
                enabled = phase != PerfPhase.RUNNING,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (results.isEmpty()) "开始测试" else "重新测试")
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedButton(
                    onClick = { PerfReport.share(context, markdown, reportName) },
                    enabled = phase == PerfPhase.DONE && results.isNotEmpty(),
                    modifier = Modifier.weight(1f),
                ) { Text("分享报告") }
                OutlinedButton(
                    onClick = {
                        val msg = when (PerfReport.saveToDownloads(context, markdown, reportName)) {
                            is PerfReport.SaveResult.Saved -> "已保存到下载目录"
                            PerfReport.SaveResult.ApiTooLow -> "系统低于 Android 10，请用分享导出"
                            PerfReport.SaveResult.Failed -> "保存失败，请用分享导出"
                        }
                        Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                    },
                    enabled = phase == PerfPhase.DONE && results.isNotEmpty(),
                    modifier = Modifier.weight(1f),
                ) { Text("保存到下载目录") }
            }

            Text(
                "debug 构建专用。采集经 FrameMetrics 公开 API（无反射）；" +
                    "分桶为整数 ms 近似，原始分桶随报告导出可审计。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/** 测试阶段机。 */
private enum class PerfPhase { IDLE, RUNNING, DONE }

/** 被测 PoC（顺序即测试顺序；transition 为静态探测页，按设计跳过）。 */
private data class PerfStage(val id: String, val name: String)

private val PERF_STAGES = listOf(
    PerfStage("droplet", "PoC-1 液滴菜单"),
    PerfStage("glass", "PoC-2 玻璃三档"),
    PerfStage("morph", "PoC-3 连续形变"),
)

/** 每段采集时长（秒/毫秒）。 */
private const val STAGE_SEC = 6L
private const val STAGE_MS = STAGE_SEC * 1000L

/** 判定徽标。 */
@Composable
private fun VerdictChip(verdict: PerfStats.Verdict?) {
    val (label, container, content) = when (verdict) {
        PerfStats.Verdict.PASS -> Triple(
            "PASS",
            MaterialTheme.colorScheme.primaryContainer,
            MaterialTheme.colorScheme.onPrimaryContainer,
        )
        PerfStats.Verdict.FAIL -> Triple(
            "FAIL",
            MaterialTheme.colorScheme.errorContainer,
            MaterialTheme.colorScheme.onErrorContainer,
        )
        else -> Triple(
            if (verdict == null) "—" else "NO_DATA",
            MaterialTheme.colorScheme.surfaceContainerHigh,
            MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
    AssistChip(
        onClick = {},
        label = { Text(label) },
        colors = AssistChipDefaults.assistChipColors(
            containerColor = container,
            labelColor = content,
        ),
    )
}

/**
 * 被测动画视口：各 PoC 确定性渲染器的程序化循环驱动（无需触摸）。
 *
 * - droplet：[DropletMenuStatic] 进度 0→1→0（液滴六层相位开合）；
 * - glass：三档 [GlassTierShowcase] alpha 交叉淡入淡出轮切；
 * - morph：[MorphCardStatic] 进度 0→1→0（圆角包络+过冲）。
 */
@Composable
private fun StageAnimation(stageId: String) {
    when (stageId) {
        "droplet" -> DropletLoopStage()
        "glass" -> GlassLoopStage()
        "morph" -> MorphLoopStage()
    }
}

/** 液滴开合循环（1200ms/半程，与 PoC-1 展开动画同量级）。 */
@Composable
private fun DropletLoopStage() {
    val progress = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        while (true) {
            progress.animateTo(1f, tween(durationMillis = 1200))
            progress.animateTo(0f, tween(durationMillis = 1200))
        }
    }
    DropletMenuStatic(progress = progress.value)
}

/** 玻璃三档轮切：alpha 交叉淡入淡出（连续动画帧）。 */
@Composable
private fun GlassLoopStage() {
    val cycle = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        while (true) {
            cycle.animateTo(2f, tween(durationMillis = 1800, easing = LinearEasing))
            cycle.animateTo(0f, tween(durationMillis = 1800, easing = LinearEasing))
        }
    }
    val tiers = remember { GlassTier.values() }
    Box(modifier = Modifier.fillMaxSize()) {
        tiers.forEachIndexed { i, tier ->
            val alpha = (1f - abs(cycle.value - i)).coerceIn(0f, 1f)
            if (alpha > 0.01f) {
                Box(modifier = Modifier.graphicsLayer { this.alpha = alpha }) {
                    GlassTierShowcase(tier = tier)
                }
            }
        }
    }
}

/** 形变开合循环（1000ms/半程，圆角包络+末段过冲）。 */
@Composable
private fun MorphLoopStage() {
    val progress = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        while (true) {
            progress.animateTo(1f, tween(durationMillis = 1000))
            progress.animateTo(0f, tween(durationMillis = 1000))
        }
    }
    MorphCardStatic(progress = progress.value, settled = false)
}
