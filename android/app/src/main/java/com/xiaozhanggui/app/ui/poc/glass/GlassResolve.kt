package com.xiaozhanggui.app.ui.poc.glass

import com.xiaozhanggui.app.ui.motion.CapabilityResult
import com.xiaozhanggui.app.ui.motion.FrameRateMonitor
import com.xiaozhanggui.app.ui.motion.MotionDowngradeReasons
import com.xiaozhanggui.app.ui.motion.PerfTier
import com.xiaozhanggui.app.ui.motion.TransitionKind

/**
 * 玻璃档位具名降级原因。
 *
 * 复用 Phase 1 [MotionDowngradeReasons] 的已有常量（不分叉）：
 * - `reduce-motion`（Reduce Motion 开启 → 直接 T3）
 * - `perf-tier-essential`（性能档 ESSENTIAL → T3）
 * - `frame-rate-below-55fps`（运行时持续低帧率 → 降一档）
 * - `capability-unsupported:<reason>`（能力探测失败 → T1 降一档）
 */
object GlassDowngradeReasons {
    /** 性能档 REDUCED → 材质退一档（T1→T2；MotionContext 的既有语义） */
    const val PERF_TIER_REDUCED = "perf-tier-reduced"
}

/**
 * 一次玻璃档位解析的最终决议（值语义，可单测）。
 *
 * @param tier 解析后的档位
 * @param downgradeReason 具名降级原因；null = 未降级（按请求档位执行）。
 *   非空 ⟺ 本次解析发生了档位下调（可直接写日志 / 做测试断言）。
 */
data class GlassResolution(
    val tier: GlassTier,
    val downgradeReason: String?,
)

/**
 * 玻璃档位降级链（纯函数，可 JVM 单测；Design System §2.1 Fallback 链）。
 *
 * 优先级单向应用（只降不升），命中多条时 [GlassResolution.downgradeReason]
 * 记录优先级最高的那一条（0 → 4 依次检查）：
 * 0. [reduceMotion] → 直接 [GlassTier.T3_ESSENTIAL]，原因 `reduce-motion`
 *    （调用方用 `isReduceMotionEnabled(animatorDurationScale)` 求值）
 * 1. [perfTier] 为 [PerfTier.ESSENTIAL] → T3，原因 `perf-tier-essential`
 * 2. [perfTier] 为 [PerfTier.REDUCED] → 材质退一档（T1→T2），
 *    原因 `perf-tier-reduced`
 * 3. [capability] 为 [CapabilityResult.Unsupported] → T1 降一档（→T2），
 *    原因透传 `capability-unsupported:<reason>`（T2/T3 不需要 RenderEffect，
 *    不受该门控影响）
 * 4. [frameRateDowngraded]（[FrameRateMonitor] 持续 1s < 55fps 已降档）→
 *    降一档：T1→T2（PoC-2 合入标准③："T1 在目标机型上 <55fps 则该机型默认 T2"）、
 *    T2→T3（§2.1 T2 行），原因 `frame-rate-below-55fps`
 *
 * @param requested 请求档位（默认 T1）
 * @param reduceMotion 系统「移除动画」是否开启
 * @param perfTier 设备性能档（Phase 3 接线判定；Motion 层只消费）
 * @param capability [probeGlassTierCapability] 的探测结果
 * @param frameRateDowngraded [GlassFrameSampler.isDowngraded]
 */
fun resolveGlassTier(
    requested: GlassTier = GlassTier.T1_FIDELITY,
    reduceMotion: Boolean,
    perfTier: PerfTier,
    capability: CapabilityResult,
    frameRateDowngraded: Boolean,
): GlassResolution {
    var tier = requested
    var reason: String? = null

    fun downgrade(to: GlassTier, r: String) {
        if (to.ordinal > tier.ordinal) {
            tier = to
            if (reason == null) reason = r
        }
    }

    // ── 0. Reduce Motion：直接 T3（无模糊），具名 reduce-motion ──
    if (reduceMotion) {
        downgrade(GlassTier.T3_ESSENTIAL, MotionDowngradeReasons.REDUCE_MOTION)
    }
    // ── 1. 性能档 ESSENTIAL：禁 T1/T2 材质 → T3 ──
    if (perfTier == PerfTier.ESSENTIAL) {
        downgrade(GlassTier.T3_ESSENTIAL, MotionDowngradeReasons.PERF_TIER_ESSENTIAL)
    }
    // ── 2. 性能档 REDUCED：材质退一档（T1→T2）──
    if (perfTier == PerfTier.REDUCED && tier == GlassTier.T1_FIDELITY) {
        downgrade(GlassTier.T2_BALANCED, GlassDowngradeReasons.PERF_TIER_REDUCED)
    }
    // ── 3. 能力探测失败：T1 降一档（→T2），原因透传 ──
    if (capability is CapabilityResult.Unsupported && tier == GlassTier.T1_FIDELITY) {
        downgrade(GlassTier.T2_BALANCED, MotionDowngradeReasons.capability(capability.reason))
    }
    // ── 4. 运行时帧率持续不足：降一档（单向）──
    if (frameRateDowngraded) {
        val target = when (tier) {
            GlassTier.T1_FIDELITY -> GlassTier.T2_BALANCED
            GlassTier.T2_BALANCED -> GlassTier.T3_ESSENTIAL
            GlassTier.T3_ESSENTIAL -> GlassTier.T3_ESSENTIAL
        }
        downgrade(target, MotionDowngradeReasons.FRAME_RATE)
    }

    return GlassResolution(tier = tier, downgradeReason = reason)
}

/**
 * 玻璃降级事件：**只记档位变化，不记业务正文**。
 *
 * 字段仅含档位变化（from → to）、具名原因与时间戳；构造上就不可能
 * 携带业务正文（类型里没有正文字段）。
 */
data class GlassDowngradeEvent(
    val from: GlassTier,
    val to: GlassTier,
    val reason: String,
    val atMs: Long,
)

/**
 * 带具名日志的档位解析器（Design System §2.3 / PoC-2 合入标准④）。
 *
 * 对 [resolveGlassTier] 的有状态封装：档位发生变化时记一条
 * [GlassDowngradeEvent]（经 [onDowngrade] 回调，Android 侧接 `Log.d`）；
 * 档位不变不记。时钟可注入，JVM 可单测。
 */
class GlassTierResolver(
    private val clockMs: () -> Long = { System.nanoTime() / 1_000_000L },
    private val onDowngrade: (GlassDowngradeEvent) -> Unit = {},
) {
    private var lastTier: GlassTier? = null
    private val events = mutableListOf<GlassDowngradeEvent>()

    fun resolve(
        requested: GlassTier = GlassTier.T1_FIDELITY,
        reduceMotion: Boolean,
        perfTier: PerfTier,
        capability: CapabilityResult,
        frameRateDowngraded: Boolean,
    ): GlassResolution {
        val resolution = resolveGlassTier(
            requested = requested,
            reduceMotion = reduceMotion,
            perfTier = perfTier,
            capability = capability,
            frameRateDowngraded = frameRateDowngraded,
        )
        val prev = lastTier
        if (prev != null && prev != resolution.tier && resolution.downgradeReason != null) {
            val event = GlassDowngradeEvent(
                from = prev,
                to = resolution.tier,
                reason = resolution.downgradeReason,
                atMs = clockMs(),
            )
            events.add(event)
            onDowngrade(event)
        }
        lastTier = resolution.tier
        return resolution
    }

    /** 降级事件快照（只读副本；只含档位变化） */
    fun downgradeEvents(): List<GlassDowngradeEvent> = events.toList()
}

/**
 * T1 帧率采样器（PoC-2「帧率数据：T1 采样记录」）。
 *
 * 复用 Phase 1 [FrameRateMonitor]（55fps / 持续 1s 阈值与单向语义不分叉）；
 * 额外记录每次 [onFrame] 的时间戳作为 T1 采样记录，供 PoC 报告。
 * Android 侧由 Choreographer 回调喂帧；回到前台调 [reset] 重新探测。
 */
class GlassFrameSampler(
    private val clockMs: () -> Long = { System.nanoTime() / 1_000_000L },
    onMonitorDowngrade: (FrameRateMonitor.DowngradeEvent) -> Unit = {},
) {
    private val monitor = FrameRateMonitor(
        clockMs = clockMs,
        onDowngrade = onMonitorDowngrade,
    )
    private val frameTimestamps = mutableListOf<Long>()

    /** 上报一帧（Choreographer 每帧回调一次）；同时记入 T1 采样记录 */
    fun onFrame() {
        frameTimestamps.add(clockMs())
        monitor.onFrame()
    }

    /** 是否已触发持续低帧率降档（→ [resolveGlassTier] 的 frameRateDowngraded） */
    val isDowngraded: Boolean
        get() = monitor.currentMaxTransitionKind() == TransitionKind.FADE

    /** T1 采样记录：onFrame 时间戳（只读副本） */
    fun sampledFrames(): List<Long> = frameTimestamps.toList()

    /** Monitor 的降级事件（只读副本；只含档位变化） */
    fun downgradeEvents(): List<FrameRateMonitor.DowngradeEvent> = monitor.downgradeEvents()

    /** 回到前台：重新探测（恢复档位上限、清空采样） */
    fun reset() {
        frameTimestamps.clear()
        monitor.reset()
    }
}
