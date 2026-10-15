package com.xiaozhanggui.app.ui.poc.droplet

import com.xiaozhanggui.app.ui.motion.DurationTier
import com.xiaozhanggui.app.ui.motion.MotionContext
import com.xiaozhanggui.app.ui.motion.MotionPolicy
import com.xiaozhanggui.app.ui.motion.MotionSpec
import com.xiaozhanggui.app.ui.motion.Overshoot
import com.xiaozhanggui.app.ui.motion.TransitionKind

/**
 * PoC-1 专属具名降级原因（Design System §2.3：原因可写日志、可单测断言）。
 *
 * `MotionDowngradeReasons` 之外的 PoC 特有原因集中在此。
 */
object DropletDowngradeReasons {
    /**
     * Phase A 锚点确认失败：无可见锚点（null 或零尺寸）→ 降级为标准淡入。
     * 对应反例清单"无锚点控件却强行做液滴展开"（出现即不合格）。
     */
    const val NO_ANCHOR = "no-anchor"
}

/**
 * 液滴菜单解析结果（值语义，可单测）。
 *
 * @param runDropletPhases true=跑六层液滴相位；false=标准淡入
 *   （[downgradeReason] 必非空，说明降级原因）
 */
data class DropletResolution(
    val transitionKind: TransitionKind,
    val durationTier: DurationTier,
    val overshoot: Overshoot,
    val downgradeReason: String?,
    val runDropletPhases: Boolean,
)

/**
 * 解析一次液滴菜单展开（纯函数，可 JVM 单测）。
 *
 * 决策顺序：
 * 1. Phase A 锚点确认：[anchor] 为 null 或不可见 → FADE/STANDARD，
 *    具名原因 `no-anchor`（标准淡入）；
 * 2. 否则复用 [MotionPolicy.resolve] 的降级链：
 *    - reduce-motion → FADE/FAST（短淡入）；
 *    - perf-tier-essential → FADE（禁 SHARED_ANCHOR）；
 *    - frame-rate（运行时连续 1s <55fps）→ FADE；
 *    - motion-disabled（总开关/独立开关关闭）→ 瞬切（无液滴）；
 * 3. 无降级 → SHARED_ANCHOR + 六层相位。
 *
 * @param anchor 可见锚点（null=无锚点）；调用方在 UI 层经 onGloballyPositioned 测量
 * @param ctx 运行时上下文（reduceMotion / perfTier / capabilities / 帧率档位上限）
 * @param spec 动效声明（默认 [DropletSpecs.MENU_EXPAND]）
 */
fun resolveDropletMenu(
    anchor: AnchorRect?,
    ctx: MotionContext,
    spec: MotionSpec = DropletSpecs.MENU_EXPAND,
): DropletResolution {
    // ── Phase A：锚点确认 ──
    if (anchor == null || !anchor.isVisible) {
        return DropletResolution(
            transitionKind = TransitionKind.FADE,
            durationTier = DurationTier.STANDARD,
            overshoot = Overshoot.NONE,
            downgradeReason = DropletDowngradeReasons.NO_ANCHOR,
            runDropletPhases = false,
        )
    }
    // ── 降级链（复用 Phase 1 MotionPolicy，不分叉）──
    val resolved = MotionPolicy.resolve(spec, ctx)
    // 注意：motion-disabled 时 MotionPolicy 返回 kind=SHARED_ANCHOR
    //（透传声明）但 downgradeReason 非空 → 必须同时检查 reason，
    // 否则总开关关闭仍会跑液滴。
    val runDroplet = resolved.downgradeReason == null &&
        resolved.transitionKind == TransitionKind.SHARED_ANCHOR
    return DropletResolution(
        transitionKind = resolved.transitionKind,
        durationTier = resolved.durationTier,
        overshoot = if (runDroplet) resolved.overshoot else Overshoot.NONE,
        downgradeReason = resolved.downgradeReason,
        runDropletPhases = runDroplet,
    )
}
