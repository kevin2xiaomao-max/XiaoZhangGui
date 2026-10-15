package com.xiaozhanggui.app.ui.poc.prep

import com.xiaozhanggui.app.ui.motion.DurationTier
import com.xiaozhanggui.app.ui.motion.MotionContext
import com.xiaozhanggui.app.ui.motion.MotionPolicy
import com.xiaozhanggui.app.ui.motion.MotionSpec
import com.xiaozhanggui.app.ui.motion.Overshoot
import com.xiaozhanggui.app.ui.motion.ResolvedMotion
import com.xiaozhanggui.app.ui.motion.TransitionKind
import com.xiaozhanggui.app.ui.poc.droplet.AnchorRect
import com.xiaozhanggui.app.ui.poc.droplet.DropletPhases
import com.xiaozhanggui.app.ui.theme.MotionSurface
import com.xiaozhanggui.app.ui.theme.resolveMotion

/**
 * 首页 AI Sheet 液滴展开的 MotionSpec 声明草案（Design System §3.1）。
 *
 * - 升级点：`HomeScreen` 的 `AICommandEntry` 点击后，AI Sheet 从入口控件位置
 *   做液滴式展开（SHARED_ANCHOR，§2.2 六层动作）；收起时反向回到入口。
 *   当前生产行为是 Root 级 ModalBottomSheet 瞬现，无视觉锚点。
 * - 锚点：`AICommandEntry` 控件（经 `onGloballyPositioned`/`boundsInRoot`
 *   取得的 [AnchorRect]；Phase A 锚点确认）。
 * - 相位数学复用 [DropletPhases]（PoC-1 已验证的六层动作相位引擎，
 *   纯函数；数值独立标定，未复制 SleepDown 的时长/过冲数值）。
 * - 材质：AI Sheet 浮层声明 `Glass/T1`（背景为首页静态内容，预构建模糊快照；
 *   背景动态时降 T2；见 [AI_SHEET_GLASS]）。
 *
 * **不接线生产页面**：本对象只声明，不被 `HomeScreen` 引用；
 * Phase 3 接线时才把 `EXPAND.enabled` 绑定到 [PrepSwitches.HOME_AI_SHEET]。
 */
object HomeAiSheetPrep {

    /** 具名降级原因（prep 层，补充 [MotionDowngradeReasons]）。 */
    object DowngradeReasons {
        /**
         * 无可见锚点（入口控件不可见/未布局/几何为空）→ 降级为标准淡入。
         * 这是 Design System §2.2 Phase A 的硬规则：「无锚点 → 降级为标准淡入」，
         * 禁止凭空做液滴展开。
         */
        const val NO_ANCHOR = "no-anchor"
    }

    val EXPAND = MotionSpec(
        id = "v38.prep.home.ai-sheet-expand",
        transitionKind = TransitionKind.SHARED_ANCHOR,
        durationTier = DurationTier.STANDARD, // 280ms：§2.2 Phase C 纵向展开档
        overshoot = Overshoot.CONTENT_ONLY, // Sheet 是浮层内容层；「内容可过冲、页面必单调」
        interruptible = true, // 展开中途收起反向续播（速度连续）
        fallbackKind = TransitionKind.FADE,
        enabled = true, // Phase 3 接线绑定 PrepSwitches.HOME_AI_SHEET
        description = "首页 AICommandEntry→AI Sheet 液滴展开（SHARED_ANCHOR 六层动作）；" +
            "降级 no-anchor/reduce-motion/perf-tier-essential/frame-rate → FADE",
    )

    /** AI Sheet 浮层材质声明（Design System §2.1 材质声明格式）。 */
    val AI_SHEET_GLASS = PrepGlassMaterial(
        tier = PrepGlassMaterial.Tier.T1_FIDELITY,
        backdropDomain = "home-feed", // 采样首页静态内容域；自采样（采样自身）在设计评审阶段拦截
        role = "floating-sheet",
        fallbackChain = "T2 -> T3", // 背景动态→T2；API<31/低内存→T2；帧率持续<55fps→T3
        description = "AI Sheet 浮层玻璃：背景静止时预构建一次 10dp 模糊快照" +
            "（显隐只改 alpha，不按帧重建）；几何与 T2/T3 完全一致",
    )

    /**
     * Phase A 锚点确认 + 全降级链解析（纯函数）。
     *
     * - [anchor] == null 或几何为空 → 具名 [DowngradeReasons.NO_ANCHOR]，
     *   走 [MotionSpec.fallbackKind]（FADE，FAST 短淡入）；
     * - 其余情况走 [MotionPolicy.resolve]（reduce-motion / perf-tier-essential /
     *   dense-list / capability / frame-rate 五级降级，优先级见 MotionPolicy）。
     */
    fun resolveExpand(
        spec: MotionSpec = EXPAND,
        ctx: MotionContext,
        anchor: AnchorRect?,
    ): ResolvedMotion {
        if (anchor == null || anchor.width <= 0f || anchor.height <= 0f) {
            return ResolvedMotion(
                baseMotion = resolveMotion(MotionSurface.FADE, ctx.reduceMotion),
                transitionKind = spec.fallbackKind,
                durationTier = DurationTier.FAST,
                overshoot = Overshoot.NONE,
                interruptible = spec.interruptible,
                downgradeReason = DowngradeReasons.NO_ANCHOR,
            )
        }
        return MotionPolicy.resolve(spec, ctx)
    }

    // ── 相位数学（§2.2 六层动作；复用 PoC-1 已验证的 DropletPhases）──
    // 收缩与位移同起（Phase B）：moveProgress(0.125) > 0，反例「收缩播完才位移」被测试拦截。
    // 内容在几何 1/4→3/4 区间淡入（Phase E）：contentAlpha(0.25) 精确为 0。
    // 收起时 master 进度反向 1→0，各相位自动反向执行（§2.2 Phase F）。

    /** Phase B-1 锚点收缩 1→0.96（p=0/1 精确为 1，稳定态释放临时形变）。 */
    fun anchorScale(p: Float): Float = DropletPhases.anchorScale(p)

    /** Phase B-2 浮层位移进度：与收缩同起。 */
    fun moveProgress(p: Float): Float = DropletPhases.moveProgress(p)

    /** Phase C 纵向先行分数（高度 0.05–0.70，横向滞后 1/4 相位）。 */
    fun heightFraction(p: Float): Float = DropletPhases.heightFraction(p)

    /** Phase C 横向展开分数。 */
    fun widthFraction(p: Float): Float = DropletPhases.widthFraction(p)

    /** Phase D 圆角插值 t（p=1 精确为 1 → 稳定态回到标准圆角 token）。 */
    fun cornerT(p: Float): Float = DropletPhases.cornerT(p)

    /** Phase E 内容 alpha（p≤0.25 精确为 0；反例「内容先出现」零容忍）。 */
    fun contentAlpha(p: Float): Float = DropletPhases.contentAlpha(p)

    /** Phase F 末段一次过冲（单峰 2.5%<3%，p=1 精确回 1）。 */
    fun panelOvershoot(p: Float): Float = DropletPhases.panelOvershoot(p)

    /**
     * Reduce Motion 语义（§3.1 验收 #3）：退化为 FAST 短淡入。
     * [MotionPolicy.resolve] 在 reduceMotion 时自动把 SHARED_ANCHOR→FADE、
     * 时长档→FAST、过冲清零，具名 `reduce-motion`。
     */
    fun resolveExpandReduceMotion(ctx: MotionContext): ResolvedMotion =
        resolveExpand(ctx = ctx.copy(reduceMotion = true), anchor = AnchorRect(0f, 0f, 100f, 48f, 12f))
}
