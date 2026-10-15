package com.xiaozhanggui.app.ui.motion

import com.xiaozhanggui.app.ui.theme.MotionSurface
import com.xiaozhanggui.app.ui.theme.ResolvedMotion as LegacyResolvedMotion
import com.xiaozhanggui.app.ui.theme.resolveMotion

/**
 * 具名降级原因（Design System §2.3：原因必须可写日志、可单测断言）。
 *
 * 集中在此一处，避免各处手写字符串分叉。
 */
object MotionDowngradeReasons {
    /** 全局总开关关闭或 MotionSpec 独立开关关闭 → V3.7.1 瞬切行为 */
    const val MOTION_DISABLED = "motion-disabled"

    /** 系统「移除动画」开启 → FAST 短淡入，无位移/弹簧/过冲/模糊 */
    const val REDUCE_MOTION = "reduce-motion"

    /** 性能档 ESSENTIAL → 禁 SHARED_ANCHOR（→FADE）、禁 T1/T2 材质（→T3） */
    const val PERF_TIER_ESSENTIAL = "perf-tier-essential"

    /** 密集列表（可见卡片 > 10）→ 内容错峰退化为整面单调 */
    const val DENSE_LIST = "dense-list"

    /** 运行时帧率连续 1s < 55fps → 自动降一档（单向，只降不升） */
    const val FRAME_RATE = "frame-rate-below-55fps"

    /** 能力探测失败 → 走 [MotionSpec.fallbackKind]，原因透传，如 `capability-unsupported:no-backdrop-blur-on-api-29` */
    fun capability(reason: String): String = "capability-unsupported:$reason"
}

/**
 * [MotionPolicy.resolve] 的返回：一次动效的最终决议（值语义，可单测）。
 *
 * 与旧 API 的兼容关系：[baseMotion] 是旧系统
 * ([com.xiaozhanggui.app.ui.theme.resolveMotion] /
 * [com.xiaozhanggui.app.ui.theme.v371.V371Motion.resolve]) 的动效 token 选择，
 * 仍在旧 `when (baseMotion)` 分支的调用方里直接可用——**旧调用方零改动**。
 * 新调用方优先读 [transitionKind] / [durationTier] / [overshoot]；
 * [downgradeReason] 非空时可直接写日志或做测试断言。
 *
 * @param baseMotion 兼容旧 API 的动效 token（QUICK/STANDARD/SOFT_SPRING/…/NONE；
 *   NONE = 调用方立即应用终值，不做动画）
 * @param transitionKind 解析后（降级后）的转场类型
 * @param durationTier 解析后的时长档（沿用 V371 档位；Reduce Motion 下为 FAST）
 * @param overshoot 解析后的过冲（任何降级路径都会压到 [Overshoot.NONE]）
 * @param interruptible 透传自 [MotionSpec.interruptible]
 * @param downgradeReason 具名降级原因（[MotionDowngradeReasons]）；null = 未降级，按声明原样执行
 */
data class ResolvedMotion(
    val baseMotion: LegacyResolvedMotion,
    val transitionKind: TransitionKind,
    val durationTier: DurationTier,
    val overshoot: Overshoot,
    val interruptible: Boolean,
    val downgradeReason: String?,
)

/**
 * 运行时动效策略（Design System §2.3 MotionPolicy）。
 *
 * 新系统是 `ui.theme.V371Motion / resolveMotion` 的**上层封装**：
 * 旧 API 一个不删，[resolve] 内部复用 [resolveMotion] 计算 [ResolvedMotion.baseMotion]，
 * 旧调用方零改动；降级只在 [ResolvedMotion] 的新字段上表达。
 *
 * 降级按优先级单向应用（只降不升），命中多条时 [ResolvedMotion.downgradeReason]
 * 记录优先级最高的那一条（0 → 5 依次检查）：
 * 0. [masterEnabled] 关闭或 [MotionSpec.enabled] 为 false → V3.7.1 行为
 *    （瞬切、无动效），原因 `motion-disabled`
 * 1. [MotionContext.reduceMotion] → FAST 短淡入，无位移/弹簧/过冲/模糊，
 *    原因 `reduce-motion`
 * 2. [MotionContext.perfTier] 为 [PerfTier.ESSENTIAL] → SHARED_ANCHOR→FADE，
 *    原因 `perf-tier-essential`
 * 3. [MotionContext.denseList] → 内容错峰退化为整面单调，原因 `dense-list`
 * 4. [MotionContext.capabilities] 转场探测失败 → 走 [MotionSpec.fallbackKind]，
 *    原因透传 `capability-unsupported:<reason>`
 * 5. [FrameRateMonitor] 运行时档位上限（连续 1s < 55fps 自动降档，单向），
 *    原因 `frame-rate-below-55fps`
 *
 * NATIVE 特殊说明：它是平台接管的系统级交互（跟手返回），App 侧降级规则
 * （1–5）不改变其 kind；Reduce Motion 下仅把过冲清零。页面转场禁止使用 NATIVE。
 */
object MotionPolicy {

    /**
     * 全局总开关。关闭 → 全 App 回到 V3.7.1 行为（瞬切 + 无玻璃）。
     *
     * 生产接线（远程配置/设置页）由 Phase 3 完成；测试可临时翻转，
     * 用完必须恢复（`@Volatile`，跨线程可见）。
     */
    @Volatile
    var masterEnabled: Boolean = true

    /**
     * 按降级链解析一次动效（纯函数，可 JVM 单测）。
     *
     * @param spec 动效声明（含预先声明的 [MotionSpec.fallbackKind]）
     * @param ctx 运行时上下文（reduceMotion / 性能档 / 密集列表 / 能力快照 / 帧率档位上限）
     * @return 最终决议；[ResolvedMotion.downgradeReason] 为 null 表示未降级
     */
    fun resolve(spec: MotionSpec, ctx: MotionContext): ResolvedMotion {
        // ── 0. 总开关 / 独立开关：V3.7.1 行为（瞬切，无动效） ──
        if (!masterEnabled || !spec.enabled) {
            return ResolvedMotion(
                baseMotion = LegacyResolvedMotion.NONE,
                transitionKind = spec.transitionKind,
                durationTier = DurationTier.INSTANT,
                overshoot = Overshoot.NONE,
                interruptible = spec.interruptible,
                downgradeReason = MotionDowngradeReasons.MOTION_DISABLED,
            )
        }

        var kind = spec.transitionKind
        var tier = spec.durationTier
        var overshoot = spec.overshoot
        var reason: String? = null

        if (ctx.reduceMotion) {
            // ── 1. Reduce Motion：FAST 短淡入，无位移/弹簧/过冲/模糊 ──
            // NATIVE 归平台接管，不改 kind（跟手返回由系统处理），仅清零过冲；
            // 时长档 FAST 是给 App 侧伴随动效的建议值。
            if (kind != TransitionKind.NATIVE) {
                kind = TransitionKind.FADE
                tier = DurationTier.FAST
            }
            overshoot = Overshoot.NONE
            reason = MotionDowngradeReasons.REDUCE_MOTION
        } else if (kind != TransitionKind.NATIVE) {
            // ── 2. 性能档 ESSENTIAL：禁 SHARED_ANCHOR → FADE ──
            if (ctx.perfTier == PerfTier.ESSENTIAL && kind == TransitionKind.SHARED_ANCHOR) {
                kind = TransitionKind.FADE
                overshoot = Overshoot.NONE
                reason = MotionDowngradeReasons.PERF_TIER_ESSENTIAL
            }
            // ── 3. 密集列表：内容错峰退化为整面单调 ──
            if (ctx.denseList) {
                kind = TransitionKind.FADE
                overshoot = Overshoot.NONE
                if (reason == null) reason = MotionDowngradeReasons.DENSE_LIST
            }
            // ── 4. 能力探测失败：走声明的 fallbackKind，原因透传 ──
            val transitionCap = ctx.capabilities.transition
            if (transitionCap is CapabilityResult.Unsupported) {
                kind = spec.fallbackKind
                overshoot = Overshoot.NONE
                if (reason == null) reason = MotionDowngradeReasons.capability(transitionCap.reason)
            }
        }

        // ── 5. 运行时帧率档位上限（单向只降不升；NATIVE 不受 App 侧上限约束） ──
        if (kind != TransitionKind.NATIVE && kind.costRank() > ctx.runtimeMaxTransitionKind.costRank()) {
            kind = ctx.runtimeMaxTransitionKind
            overshoot = Overshoot.NONE
            if (reason == null) reason = MotionDowngradeReasons.FRAME_RATE
        }

        // baseMotion：复用旧 resolveMotion，保证旧 when(baseMotion) 分支零改动可用。
        // NATIVE 映射到 FADE surface（App 侧伴随动效按淡入处理；手势跟手部分归平台）。
        val surface = when (kind) {
            TransitionKind.SHARED_ANCHOR -> MotionSurface.SPRING
            TransitionKind.FADE, TransitionKind.NATIVE -> MotionSurface.FADE
        }
        return ResolvedMotion(
            baseMotion = resolveMotion(surface, ctx.reduceMotion),
            transitionKind = kind,
            durationTier = tier,
            overshoot = overshoot,
            interruptible = spec.interruptible,
            downgradeReason = reason,
        )
    }

    /** 转场成本排序：NATIVE（平台接管，App 侧零成本）< FADE < SHARED_ANCHOR。 */
    private fun TransitionKind.costRank(): Int = when (this) {
        TransitionKind.NATIVE -> 0
        TransitionKind.FADE -> 1
        TransitionKind.SHARED_ANCHOR -> 2
    }
}
